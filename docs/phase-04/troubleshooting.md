# Phase 4: CI/CD -- Troubleshooting Guide

Common CI/CD pitfalls with GitHub Actions, Docker, and EC2 deployments. Each entry follows the same format: what you see, why it happens, how to fix it, and how to prevent it in the future.

---

## 1. Secrets Not Available in PRs from Forks

**Symptom:** Workflow steps that use `${{ secrets.X }}` get empty string values. The AWS credential step fails with "missing credentials" or the SSH step connects to an empty host.

**Cause:** GitHub does not expose repository or environment secrets to workflow runs triggered by pull requests from forked repositories. This is a security measure -- a fork could modify the workflow to exfiltrate your secrets.

**Fix:** For this learning project (single contributor), this is not a problem. If you encounter it:
- Check if the PR came from a fork: the Actions tab shows the source
- For fork PRs, secrets are intentionally empty -- this is expected behavior

**Prevention:** For real projects with external contributors, use the `pull_request_target` event (which runs the workflow from the base branch, not the fork) or only run secret-dependent steps on push events. Never modify your workflow to expose secrets to forks.

---

## 2. pnpm Lockfile Cache Miss in Monorepo

**Symptom:** The `actions/setup-node` step reports "cache not found" on every single run, even though dependencies have not changed. Build times are slower than expected because pnpm re-downloads everything.

**Cause:** The `cache-dependency-path` parameter points to the wrong lockfile location. In a monorepo with pnpm workspaces, the lockfile is at the project root (`pnpm-lock.yaml`), not inside the `app/` directory. If you set `cache-dependency-path: app/pnpm-lock.yaml` but the file is at the root, the cache key cannot be computed.

**Fix:** Update the `setup-node` step to point to the correct lockfile:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'pnpm'
    cache-dependency-path: pnpm-lock.yaml  # Root, not app/pnpm-lock.yaml
```

**Prevention:** Run `ls -la pnpm-lock.yaml app/pnpm-lock.yaml` to verify where the lockfile actually lives before configuring the cache path. With pnpm workspaces, there is always a single lockfile at the workspace root.

---

## 3. Docker Build Context in CI

**Symptom:** Docker build fails with `COPY failed: file not found in build context` or `failed to compute cache key: ... not found`.

**Cause:** The Dockerfile uses `COPY package.json .` or `COPY src/ .` but the build context does not include those files. In CI, the working directory is the repo root. If you run `docker build .` from the root but the Dockerfile expects files from `app/`, the COPY instructions fail because they look for files relative to the build context (`.` = repo root), not relative to the Dockerfile location.

**Fix:** Set the build context to the correct directory:
```bash
# Frontend (Dockerfile is at app/Dockerfile)
docker build -t ecommerce-frontend ./app

# API (Dockerfile.api is at app/Dockerfile.api)
docker build -t ecommerce-api -f ./app/Dockerfile.api ./app
```
The last argument (`./app`) is the build context. The `-f` flag specifies the Dockerfile location when it differs from the default (`<context>/Dockerfile`).

**Prevention:** Always think about where the Dockerfile expects its files to be. The build context is the directory you pass to `docker build`, and all `COPY`/`ADD` paths are relative to it. Test your Docker build command locally from the repo root (the same working directory CI uses).

---

## 4. SSH Key Formatting in Secrets

**Symptom:** The `appleboy/ssh-action` step fails with errors like `load key: invalid format`, `invalid private key`, or `ssh: handshake failed`.

**Cause:** When you paste a private key into GitHub Secrets through the web UI, several things can go wrong:
- Trailing newline was stripped (the key format requires one)
- Extra whitespace was added at the beginning or end
- The key was copied without the header/footer lines
- Line endings were converted (Windows `\r\n` vs Unix `\n`)

**Fix:** Re-copy the key carefully:
```bash
# Copy the FULL key including headers and trailing newline
cat ~/.ssh/your-key.pem | pbcopy    # macOS
cat ~/.ssh/your-key.pem | xclip -selection clipboard  # Linux
```
Then paste into the GitHub Secret, replacing the old value. The key must include:
```
-----BEGIN OPENSSH PRIVATE KEY-----
... base64 content ...
-----END OPENSSH PRIVATE KEY-----
```
with a newline after the closing line.

**Prevention:** Always use `cat | pbcopy` (or equivalent) rather than opening the key file in a text editor and copying from there. Editors may strip trailing newlines or modify whitespace. Test locally first: `ssh -i ~/.ssh/your-key.pem ec2-user@<host>`.

---

## 5. EC2 Security Group Blocks CI Runner (Health Check Fails)

**Symptom:** The health check step times out after all retry attempts, even though the SSH deploy step succeeded and the app is actually running. Visiting the site from your browser works fine.

**Cause:** The health check runs from the GitHub Actions runner (a GitHub-hosted virtual machine with a dynamic IP). If your EC2 security group restricts HTTP access to specific IPs (e.g., your home IP only), the runner cannot reach port 80/443.

**Fix:** Two options:
1. **Open HTTP to all (recommended for learning):** Update the security group inbound rules to allow port 80 from `0.0.0.0/0`
2. **Run health check via SSH:** Change the health check to run inside the EC2 using the SSH action:
   ```yaml
   - name: Health check (via SSH)
     uses: appleboy/ssh-action@v1
     with:
       host: ${{ secrets.EC2_HOST }}
       username: ${{ secrets.EC2_USERNAME }}
       key: ${{ secrets.SSH_PRIVATE_KEY }}
       script: |
         curl -sf http://localhost/health || exit 1
   ```

**Prevention:** When setting up security groups for CI/CD, remember that the CI runner is not on your local network. Any step that makes HTTP requests to your server (health checks, smoke tests) needs the server to be reachable from the public internet or must run through SSH.

---

## 6. docker compose File Not on EC2

**Symptom:** The SSH deploy step fails with `no configuration file provided: not found` or `docker compose` errors about a missing `docker-compose.yml` / `compose.yml`.

**Cause:** The `docker-compose.yml` file exists in your git repository but was never transferred to the EC2 instance, or it is in a different directory than where the deploy script runs `docker compose up`.

**Fix:** Add a `git pull` step at the beginning of your SSH deploy script:
```yaml
script: |
  cd ~/app
  git pull origin ${{ github.ref_name }}
  # ... then continue with docker compose pull, migrate, up
```
This ensures the compose file (and any other config changes) are up to date on the server before running `docker compose`.

**Prevention:** Always include a `git pull` (or file transfer step) before running `docker compose` on the server. The server's copy of the repo can drift from the source if you only pull Docker images without updating config files. An alternative is to SCP just the compose file, but `git pull` is simpler when the repo is already cloned on the server (which it is from Phase 2).

---

## 7. Drizzle Migration Fails in CI Deploy

**Symptom:** The migration step in the SSH deploy script fails with `ECONNREFUSED`, `connection refused`, or `role "xxx" does not exist`.

**Cause:** The migration runs inside a container that cannot reach the database. Common reasons:
- The database container is not running yet (it was just recreated)
- `DATABASE_URL` is not set in the container's environment
- The migration is run as a bare command (`node migrate.js`) outside of Docker, where the database is only reachable through the Docker network

**Fix:** Run migrations through `docker compose run` so the container inherits the correct environment and network:
```bash
# Ensure the database is up first
docker compose up -d db
sleep 5  # Wait for PostgreSQL to accept connections

# Run migrations in a temporary container connected to the same network
docker compose run --rm api pnpm db:push

# Then bring up all services
docker compose up -d --force-recreate --remove-orphans
```

**Prevention:** Always run migrations through `docker compose run` (not bare `node`). Ensure the database container is healthy before running migrations. If you use health checks in your compose file (`service_healthy` condition), bring up the database first and wait for it before running migrations.

---

## 8. GitHub Environments Require Pro for Private Repos

**Symptom:** When configuring environments in **Settings** > **Environments**, protection rules (required reviewers, wait timers, branch restrictions) are grayed out or missing.

**Cause:** GitHub Environments with protection rules require a paid plan (GitHub Team or GitHub Pro) for private repositories. Public repositories get all environment features for free.

**Fix:** Two options:
1. **Make the repo public:** If this is a learning project, making it public gives you full access to all environment features at no cost
2. **Use environments without protection rules:** Environment secrets and variables work on all plans, including free. You just cannot enforce branch restrictions or required reviewers through the GitHub UI. The workflow's `if` conditions and branch triggers still control which branch deploys where.

**Prevention:** Before relying on environment protection rules, check your GitHub plan. For this learning project, the critical feature is environment-scoped secrets (which work on all plans). Branch-based deployment control is handled by the workflow's trigger configuration (`on: push: branches: [develop, main]`), not by environment protection rules.

---

## Quick Reference: Error to Pitfall Mapping

| Error Message | Likely Pitfall |
|---------------|---------------|
| Empty secret values / missing credentials | #1 (Fork PRs) or secrets not added to environment |
| "cache not found" on every run | #2 (Lockfile path) |
| `COPY failed: file not found in build context` | #3 (Build context) |
| `load key: invalid format` | #4 (SSH key formatting) |
| Health check timeout but site works in browser | #5 (Security group) |
| `no configuration file provided: not found` | #6 (Compose file missing) |
| `ECONNREFUSED` during migration | #7 (Migration connectivity) |
| Environment protection rules unavailable | #8 (GitHub plan) |
