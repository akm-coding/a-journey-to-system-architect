# Phase 4: CI/CD -- Hands-On Exercises

These exercises build on the GitHub Actions workflow (`ci-cd.yml`) and study guide from this phase. Complete them in order -- each exercise introduces a new concept while reinforcing previous ones.

**Prerequisites for all exercises:**
- A GitHub repository with the e-commerce app pushed
- The `.github/workflows/ci-cd.yml` workflow file committed (from the Phase 4 guide)
- App has working `pnpm lint`, `pnpm format`, and `pnpm test` scripts
- AWS account with ECR repositories from Phase 3
- Two EC2 instances (staging and production) with Docker installed

---

## Exercise 1: Set Up GitHub Environments and Secrets

**Objective:** Configure GitHub Environments so the pipeline knows where to deploy for each branch.

**Why this matters:** GitHub Environments let you store secrets (like SSH keys and AWS credentials) scoped to a specific deployment target. The workflow selects the environment dynamically based on which branch triggered it. This is cleaner than prefixing secrets (`STAGING_EC2_HOST`, `PROD_EC2_HOST`) because the workflow YAML uses the same secret name (`EC2_HOST`) everywhere.

### Steps

1. **Navigate to Environment Settings**
   - Go to your repository on GitHub
   - Click **Settings** > **Environments** > **New environment**

2. **Create the Staging Environment**
   - Name: `staging`
   - Click **Configure environment**
   - Under **Deployment branches**, select **Selected branches** and add `develop`
   - Add the following **secrets** (click "Add secret" for each):

   | Secret Name | Value |
   |-------------|-------|
   | `EC2_HOST` | Public IP or DNS of your staging EC2 instance |
   | `EC2_USERNAME` | `ec2-user` (Amazon Linux 2023 default) |
   | `SSH_PRIVATE_KEY` | Contents of your staging SSH private key file |
   | `AWS_ACCESS_KEY_ID` | Your IAM user access key ID |
   | `AWS_SECRET_ACCESS_KEY` | Your IAM user secret access key |

   - Add the following **variables** (click "Add variable" for each):

   | Variable Name | Value |
   |---------------|-------|
   | `AWS_REGION` | `ap-southeast-1` (or your region) |
   | `APP_URL` | `http://<staging-ec2-ip>` |

3. **Create the Production Environment**
   - Go back to **Environments** > **New environment**
   - Name: `production`
   - Click **Configure environment**
   - Under **Deployment branches**, select **Selected branches** and add `main`
   - Add the same secret names as staging, but with **production values** (different EC2 host, different SSH key if using separate key pairs)
   - Add the same variable names with production values

4. **Copy Your SSH Key Correctly**
   ```bash
   # On your local machine -- copy the FULL key including headers
   cat ~/.ssh/your-staging-key.pem | pbcopy   # macOS
   cat ~/.ssh/your-staging-key.pem | xclip     # Linux
   ```
   The secret must include `-----BEGIN OPENSSH PRIVATE KEY-----` through `-----END OPENSSH PRIVATE KEY-----` with a trailing newline.

### Verification

- Navigate to **Settings** > **Environments** and confirm both `staging` and `production` appear
- Each environment shows the correct number of secrets (5) and variables (2)
- Branch restrictions are set: staging allows `develop`, production allows `main`

### What You Learned

- GitHub Environments scope secrets to deployment targets, keeping the workflow YAML clean
- The same secret name (`EC2_HOST`) resolves to different values depending on which environment the job uses
- Branch restrictions prevent accidental deployments (e.g., you cannot deploy to production from the `develop` branch)

---

## Exercise 2: Trigger Your First Pipeline Run

**Objective:** Push a change to `develop` and watch the full pipeline execute, deploying to staging.

**Why this matters:** Seeing the pipeline run end-to-end transforms it from an abstract YAML file into a real automated process. You will learn to read job logs, understand job dependencies, and verify a deployment reached the target server.

### Steps

1. **Create the `develop` branch**
   ```bash
   git checkout -b develop
   git push -u origin develop
   ```

2. **Make a small change**
   ```bash
   # Edit a comment or add a console.log to the health endpoint
   # For example, in app/src/server/routes/health.ts:
   # Change the response to include a version field
   ```

3. **Commit and push**
   ```bash
   git add -A
   git commit -m "test: trigger first pipeline run"
   git push
   ```

4. **Watch the pipeline in GitHub**
   - Go to your repo > **Actions** tab
   - Click on the running workflow
   - You should see three jobs: **lint-and-test**, **build-images**, **push-and-deploy**

5. **Read the logs for each job**
   - **lint-and-test:** Expands each step. Look for:
     - pnpm cache hit/miss (first run will be a miss)
     - `pnpm lint` output (should show no errors)
     - `pnpm test` output (should show tests passing)
   - **build-images:** Look for:
     - Docker build output (layer caching from Phase 3 knowledge applies here too)
     - Both frontend and API images building successfully
   - **push-and-deploy:** Look for:
     - AWS credential configuration
     - ECR login
     - Image push with SHA tag and `latest` tag
     - SSH deploy output
     - Health check passing

6. **Verify the staging deployment**
   ```bash
   # Hit the staging server
   curl http://<staging-ec2-ip>/health
   # Expected: {"status":"ok","timestamp":"..."}

   # Check the app is serving
   curl -I http://<staging-ec2-ip>
   # Expected: HTTP/1.1 200 OK
   ```

### Expected Output

The Actions tab shows all three jobs with green checkmarks. The push-and-deploy job shows `environment: staging` in its header. The staging EC2 is serving the updated app.

### What You Learned

- The pipeline runs automatically on push to `develop` -- no manual trigger needed
- Jobs run in sequence: lint-and-test must pass before build-images starts, which must pass before push-and-deploy starts (the `needs` keyword controls this)
- The `push-and-deploy` job correctly selected the `staging` environment because you pushed to `develop`
- You can read job logs to diagnose any step that fails

---

## Exercise 3: Break a Test and Watch the Pipeline Fail

**Objective:** Intentionally break a test to see how the pipeline catches failures before they reach production.

**Why this matters:** The entire point of CI is to catch problems early. This exercise demonstrates that a failing test stops the pipeline -- the broken code never gets built into a Docker image and never reaches any server. This is the safety net.

### Steps

1. **Break a test intentionally**
   ```bash
   # Find your test file (e.g., app/src/server/__tests__/health.test.ts)
   # Change an assertion to something wrong:
   #   expect(response.status).toBe(200)  -->  expect(response.status).toBe(500)
   ```

2. **Commit and push to develop**
   ```bash
   git add -A
   git commit -m "test: intentionally break test for learning"
   git push
   ```

3. **Watch the pipeline in GitHub Actions**
   - Go to **Actions** tab
   - Click on the running workflow
   - Observe: **lint-and-test** job FAILS (red X)

4. **Examine the failure**
   - Click into the **lint-and-test** job
   - Expand the "Run tests" step
   - Read the test failure output -- it tells you exactly which assertion failed and why

5. **Check what was SKIPPED**
   - Back on the workflow run page, observe:
     - **build-images**: SKIPPED (gray, not red)
     - **push-and-deploy**: SKIPPED (gray, not red)
   - This is critical: the pipeline did NOT deploy broken code. The `needs: lint-and-test` dependency prevented downstream jobs from running.

6. **Fix the test and push again**
   ```bash
   # Revert your change -- restore the correct assertion
   git add -A
   git commit -m "fix: restore correct test assertion"
   git push
   ```

7. **Watch the pipeline succeed**
   - The new push triggers a fresh pipeline run
   - All three jobs should pass (green checkmarks)
   - Staging gets the fixed code deployed

### Expected Output

You should have two workflow runs visible in the Actions tab:
- One with a red X (the broken test) -- build-images and push-and-deploy are SKIPPED
- One with a green checkmark (the fix) -- all jobs passed

### What You Learned

- A failing test blocks the entire pipeline -- broken code never reaches any server
- Downstream jobs show as "skipped" (not "failed") because `needs` creates a dependency chain
- The pipeline provides a clear error message showing exactly what broke
- The feedback loop is fast: break something, see it fail, fix it, see it pass
- This is why CI matters: it catches mistakes before they become production incidents

---

## Exercise 4: Add a New Secret

**Objective:** Add a new environment variable to GitHub Environments and verify it reaches the EC2 instance.

**Why this matters:** Real projects frequently need new configuration values. This exercise teaches the flow of adding a variable in GitHub, referencing it in the workflow, and verifying it propagates to the server.

### Steps

1. **Add a variable to both environments**
   - Go to **Settings** > **Environments** > **staging** > **Add variable**
     - Name: `NODE_ENV`
     - Value: `staging`
   - Go to **Settings** > **Environments** > **production** > **Add variable**
     - Name: `NODE_ENV`
     - Value: `production`

2. **Reference the variable in the workflow**
   Open `.github/workflows/ci-cd.yml` and add the variable to the SSH deploy step. In the `Deploy via SSH` step's script section, add a line to write it to the app's `.env` file:

   ```yaml
   # Inside the SSH deploy script, before docker compose up:
   echo "NODE_ENV=${{ vars.NODE_ENV }}" >> ~/app/.env
   ```

   Alternatively, reference it in your `docker-compose.yml` environment section if your app reads it from there.

3. **Commit and push to develop**
   ```bash
   git add .github/workflows/ci-cd.yml
   git commit -m "feat: add NODE_ENV variable to deploy"
   git push
   ```

4. **Verify on the staging server**
   ```bash
   # After the pipeline completes, SSH into staging
   ssh -i ~/.ssh/staging-key.pem ec2-user@<staging-ip>

   # Check the environment variable is set
   docker compose exec api env | grep NODE_ENV
   # Expected: NODE_ENV=staging
   ```

### Expected Output

The pipeline runs successfully. The staging server has `NODE_ENV=staging` available inside the API container.

### What You Learned

- Environment variables (`vars.X`) are not secret -- they are visible in logs (unlike `secrets.X` which are masked)
- Adding a new config value follows a predictable flow: add to GitHub Environment, reference in workflow, deploy, verify
- The same variable name (`NODE_ENV`) can have different values per environment, just like secrets

---

## Exercise 5: Modify the Deploy Step

**Objective:** Add a post-deploy verification step that prints the running container versions.

**Why this matters:** Deploy steps evolve over time. This exercise teaches you to modify the workflow and verify your changes work in the real pipeline. Printing container versions after deploy is a practical technique for confirming the right code is running.

### Steps

1. **Edit the SSH deploy script in `ci-cd.yml`**
   Add these lines at the end of the `Deploy via SSH` step's script:

   ```yaml
   script: |
     # ... existing deploy commands ...

     # Post-deploy verification: show running containers and their images
     echo "=== Deployed Containers ==="
     docker compose ps --format "table {{.Name}}\t{{.Image}}\t{{.Status}}"
     echo ""
     echo "=== Image Details ==="
     docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | grep ecommerce
   ```

2. **Commit and push to develop**
   ```bash
   git add .github/workflows/ci-cd.yml
   git commit -m "feat: add container version output to deploy step"
   git push
   ```

3. **Check the deploy output in GitHub Actions**
   - Go to **Actions** > click the running workflow > **push-and-deploy** job
   - Expand the **Deploy via SSH** step
   - Scroll to the bottom of the output
   - You should see a table of running containers with their image names and tags

### Expected Output

The deploy step logs now include something like:

```
=== Deployed Containers ===
NAME                IMAGE                                           STATUS
app-frontend-1     123456789.dkr.ecr.region.amazonaws.com/...      Up 5 seconds
app-api-1          123456789.dkr.ecr.region.amazonaws.com/...      Up 5 seconds
app-db-1           postgres:16-alpine                               Up 30 seconds
app-redis-1        redis:7-alpine                                   Up 30 seconds

=== Image Details ===
REPOSITORY                      TAG       CREATED AT
ecommerce-frontend              latest    2026-05-07 ...
ecommerce-api                   latest    2026-05-07 ...
```

### What You Learned

- Modifying the workflow is just editing YAML and pushing -- the pipeline picks up changes immediately
- Post-deploy verification in the pipeline log gives you confidence without SSHing into the server manually
- The `docker compose ps` and `docker images` commands are useful operational tools for checking what is actually running

---

## Exercise 6: Promote to Production

**Objective:** Merge `develop` into `main` and watch the pipeline deploy to production.

**Why this matters:** This is the real deployment workflow: code flows from feature branches to `develop` (staging) to `main` (production). The same pipeline handles both -- only the environment changes. This exercise proves that your staging validation translates to a safe production deployment.

### Steps

1. **Create a pull request from develop to main**
   ```bash
   # Using GitHub CLI
   gh pr create --base main --head develop \
     --title "Promote staging to production" \
     --body "All exercises completed and verified on staging."
   ```
   Or create it through the GitHub web UI: Pull Requests > New > base: main, compare: develop.

2. **Observe the PR pipeline**
   - The workflow triggers on `pull_request` to `main`
   - Only **lint-and-test** and **build-images** run
   - **push-and-deploy** is SKIPPED because this is a PR, not a push (`if: github.event_name == 'push'`)
   - This verifies the code without deploying it

3. **Merge the pull request**
   ```bash
   gh pr merge --merge
   ```
   Or click **Merge pull request** in the GitHub UI.

4. **Watch the production deployment**
   - The merge creates a push event on `main`
   - A new workflow run starts with all three jobs
   - The **push-and-deploy** job shows `environment: production`
   - It uses the production environment's secrets (different EC2 host)

5. **Verify the production deployment**
   ```bash
   # Hit the production server
   curl http://<production-ec2-ip>/health
   # Expected: {"status":"ok","timestamp":"..."}

   # Compare with staging
   curl http://<staging-ec2-ip>/health
   # Both should return 200 OK but from different servers
   ```

6. **Review deployment history**
   ```bash
   # List recent workflow runs
   gh run list --workflow=ci-cd.yml --limit=5

   # You should see:
   # - A successful run on main (production deploy)
   # - The PR check run (no deploy)
   # - Previous develop runs (staging deploys)
   ```

### Expected Output

The Actions tab shows a successful production deployment. Both staging and production servers are serving the app. The workflow run for `main` shows `environment: production` on the push-and-deploy job.

### What You Learned

- The same pipeline deploys to different environments based on the branch
- PRs only run lint/test/build (no deploy) -- the `if: github.event_name == 'push'` condition prevents it
- Merging a PR creates a push event, which triggers the full pipeline including deployment
- The promotion workflow (develop -> PR -> main) gives you a staging validation step before production
- `gh run list` is useful for reviewing deployment history from the command line

---

## Summary

After completing all six exercises, you have:

1. **Configured** GitHub Environments with scoped secrets and branch restrictions
2. **Triggered** a real pipeline and read the logs for each job
3. **Verified** the safety net by breaking a test and watching the pipeline catch it
4. **Extended** the pipeline by adding a new environment variable
5. **Modified** the deploy step to add operational visibility
6. **Promoted** code from staging to production through a PR workflow

These are the core CI/CD operations you will perform regularly. The pipeline automates what you did manually in Phases 2 and 3 -- now every push is tested, built, and deployed without you SSHing into any server.
