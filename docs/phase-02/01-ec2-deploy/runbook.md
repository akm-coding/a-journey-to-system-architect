# EC2 Deployment Runbook

Deploy the e-commerce app to an EC2 instance with Nginx reverse proxy, PM2 process management, and HTTPS via Let's Encrypt. This runbook follows an incremental, layered approach: you verify each component works before adding the next.

**Time estimate:** 2-4 hours for first-time deployment

**Prerequisites:**
- Phase 1 complete (VPC, security groups, DNS concepts)
- AWS account with IAM user
- Domain pointed to Cloudflare (from Phase 1 DNS exercise)
- The e-commerce app built locally (Plan 02-01)
- SSH key pair created in AWS (or you will create one below)

---

## Section 1: Launch EC2 and Initial Setup

### 1.1 Create the VPC

You need a VPC with both public and private subnets across two Availability Zones. The two-AZ requirement matters because RDS (which you will set up in a later plan) requires a DB subnet group spanning at least two AZs.

> **[WHY]** Even though your EC2 instance only runs in one AZ, you are setting up two AZs now so you do not have to rebuild the VPC later when adding RDS. This is a real-world pattern: plan your network for all the services you will eventually need.

1. Go to **VPC Console** > **Create VPC**
2. Select **VPC and more** (this creates subnets, route tables, and an internet gateway automatically)
3. Configure:
   - **Name tag auto-generation:** `ecommerce`
   - **IPv4 CIDR:** `10.0.0.0/16`
   - **Number of Availability Zones:** `2`
   - **Number of public subnets:** `2`
   - **Number of private subnets:** `2`
   - **NAT gateways:** `None` (saves cost -- your RDS does not need outbound internet)
   - **VPC endpoints:** `None`
4. Click **Create VPC**

> **[GOTCHA]** If you use only one AZ, you will hit this error later when creating an RDS DB subnet group: "DB Subnet Group doesn't meet availability zone coverage requirement." Save yourself the headache and use two AZs from the start.

### 1.2 Create the EC2 Security Group

1. Go to **EC2 Console** > **Security Groups** > **Create security group**
2. Configure:
   - **Name:** `ecommerce-ec2-sg`
   - **Description:** `Security group for ecommerce EC2 instance`
   - **VPC:** Select the `ecommerce-vpc` you just created
3. Add **Inbound rules:**

| Type | Port | Source | Why |
|------|------|--------|-----|
| SSH | 22 | My IP | Remote access (restricts to your current IP) |
| HTTP | 80 | 0.0.0.0/0 | Web traffic (Nginx will listen here) |
| HTTPS | 443 | 0.0.0.0/0 | Encrypted web traffic (after Certbot setup) |

4. Leave **Outbound rules** as default (all traffic allowed)
5. Click **Create security group**

> **[WHY]** SSH is restricted to "My IP" following the least-privilege principle from Phase 1. HTTP and HTTPS are open to the world because this is a web server. If your home IP changes, you will need to update the SSH rule.

### 1.3 Launch the EC2 Instance

1. Go to **EC2 Console** > **Launch instances**
2. Configure:
   - **Name:** `ecommerce-server`
   - **AMI:** Amazon Linux 2023 (should be the default)
   - **Instance type:** `t2.micro` (free tier eligible)
   - **Key pair:** Create new or select existing (download the `.pem` file and keep it safe)
   - **Network settings:** Click **Edit**
     - **VPC:** `ecommerce-vpc`
     - **Subnet:** Select one of the **public** subnets
     - **Auto-assign public IP:** `Enable`
     - **Select existing security group:** `ecommerce-ec2-sg`
3. **Storage:** 8 GiB gp3 (default is fine)
4. Click **Launch instance**

### 1.4 Attach an Elastic IP

An Elastic IP gives your instance a static public IP that survives stop/start cycles.

1. Go to **EC2 Console** > **Elastic IPs** > **Allocate Elastic IP address**
2. Click **Allocate**
3. Select the new Elastic IP > **Actions** > **Associate Elastic IP address**
4. Select your `ecommerce-server` instance
5. Click **Associate**

Note down the Elastic IP address. You will use it throughout this runbook. We will call it `YOUR_ELASTIC_IP`.

> **[WHY]** Without an Elastic IP, your instance gets a new public IP every time it stops and starts. This breaks DNS records, SSH configs, and any bookmarks pointing to your server.

### 1.5 SSH into the Instance

```bash
# Set permissions on your key file (required -- SSH refuses keys with open permissions)
chmod 400 ~/path/to/your-key.pem

# Connect
ssh -i ~/path/to/your-key.pem ec2-user@YOUR_ELASTIC_IP
```

If you see `Permission denied (publickey)`, check:
- You are using the correct `.pem` file
- The file permissions are `400`
- You are connecting as `ec2-user` (not `root`)

### 1.6 Install Node.js 20

```bash
# Update system packages
sudo dnf update -y

# Install Node.js 20
sudo dnf install -y nodejs20

# Verify installation
node -v    # Should print v20.x.x
npm -v     # Should print 10.x.x
```

> **[GOTCHA]** On some AL2023 configurations, the `nodejs20` package installs the binary as `node-20` instead of `node`. If `node -v` gives "command not found" but `node-20 -v` works, run:
> ```bash
> sudo alternatives --install /usr/bin/node node /usr/bin/node-20 1
> ```
> Then verify `node -v` works after reconnecting.

### 1.7 Install pnpm

```bash
# Install pnpm globally
sudo npm install -g pnpm

# Verify
pnpm --version
```

### 1.8 Install Git (if not present)

```bash
# Git is usually pre-installed on AL2023, but verify
git --version

# If not installed:
sudo dnf install -y git
```

**[CHECKPOINT]** Verify your EC2 setup is complete:
```bash
node -v       # v20.x.x
pnpm --version  # 9.x.x or 10.x.x
git --version   # git version 2.x.x
```

All three commands should return version numbers. If any fails, go back and fix it before proceeding. You want a solid foundation before adding application layers.

---

## Section 2: Deploy and Run the Node API Directly

### 2.1 Clone the Repository

```bash
# Clone your repo (replace with your actual repo URL)
cd ~
git clone https://github.com/YOUR_USERNAME/a-journey-to-system-architect.git
cd a-journey-to-system-architect/app
```

> **[WHY]** We use `git clone` rather than `scp` because it is simpler and mirrors real-world deployment workflows. When you make changes later, you just `git pull` instead of re-copying files.

### 2.2 Install Dependencies

```bash
pnpm install
```

This installs both server and client dependencies from `package.json`.

### 2.3 Build the Server

```bash
pnpm run build:server
```

This compiles TypeScript to JavaScript in `dist/server/`. The compiled entry point is `dist/server/index.js`.

### 2.4 Run the API Directly

For now, skip the database (the health endpoint works without it). Set a placeholder for DATABASE_URL:

```bash
# Run the server directly (foreground process)
PORT=3000 node dist/server/index.js
```

You should see: `API running on port 3000`

### 2.5 Test from Another SSH Session

Open a second terminal and SSH into the instance:

```bash
ssh -i ~/path/to/your-key.pem ec2-user@YOUR_ELASTIC_IP

# Test the health endpoint
curl http://localhost:3000/api/health
```

Expected response:
```json
{"status":"ok","timestamp":"2026-05-06T12:00:00.000Z"}
```

**[CHECKPOINT]** Verify the API responds:
```bash
curl -s http://localhost:3000/api/health | python3 -m json.tool
```

You should see formatted JSON with `status: "ok"`. If you get "Connection refused", check that the server is still running in the first terminal.

> **[WHY]** Running the API directly proves the code works on EC2 before adding any extra layers. This is the debugging principle of isolating variables: if something breaks later with PM2 or Nginx, you know the code itself is fine.

Now stop the server in the first terminal with `Ctrl+C`. You can see the problem immediately: the process dies when you close the terminal. That is why you need PM2.

---

## Section 3: Install and Configure PM2

### 3.1 What PM2 Does and Why You Need It

Running `node server.js` directly has three problems:

1. **No auto-restart:** If the app crashes, it stays dead until you manually restart it
2. **No persistence:** If the server reboots, the app does not come back up
3. **Blocks the terminal:** You cannot do anything else in that SSH session

PM2 solves all three. It is a process manager that runs your Node.js app in the background, restarts it on crash, and can restore processes after a reboot.

### 3.2 Install PM2

```bash
sudo npm install -g pm2

# Verify
pm2 --version
```

### 3.3 Start the App with PM2

The repository includes an `ecosystem.config.js` file that tells PM2 how to run the app:

```javascript
// ecosystem.config.js (already in your repo)
module.exports = {
  apps: [{
    name: "ecommerce-api",
    script: "./dist/server/index.js",
    instances: 1,           // t2.micro has 1 vCPU
    exec_mode: "fork",      // cluster mode needs 2+ instances
    env: {
      NODE_ENV: "production",
      PORT: 3000
    },
    max_restarts: 10,
    restart_delay: 1000
  }]
};
```

Start the app:

```bash
cd ~/a-journey-to-system-architect/app
pm2 start ecosystem.config.js
```

### 3.4 Essential PM2 Commands

```bash
# Check process status
pm2 status

# View logs (real-time)
pm2 logs ecommerce-api

# View last 100 lines of logs
pm2 logs ecommerce-api --lines 100

# Restart the app
pm2 restart ecommerce-api

# Stop the app
pm2 stop ecommerce-api

# Remove from PM2 entirely
pm2 delete ecommerce-api
```

> **[WHY]** `pm2 status` is your go-to command for checking if the app is alive. Get in the habit of running it first whenever something seems wrong. The "status" column tells you immediately: "online" (good), "errored" (check logs), or "stopped" (needs restart).

### 3.5 Set Up Startup Persistence

This is the most commonly forgotten step. Without it, a server reboot kills your app permanently.

```bash
# Generate the startup script
pm2 startup
```

PM2 will print a command that looks like this:

```
[PM2] To setup the Startup Script, copy/paste the following command:
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user
```

**Copy and run that exact command** (the one PM2 prints, not the example above). It creates a systemd service that restores PM2 processes on boot.

Then save the current process list:

```bash
pm2 save
```

> **[GOTCHA]** You must run BOTH `pm2 startup` (creates the systemd service) AND `pm2 save` (tells PM2 which processes to restore). If you skip `pm2 save`, the systemd service starts PM2 on boot but PM2 has nothing to restore. Your app will not come back after a reboot.

> **[WHY]** `pm2 startup` creates a systemd unit file at `/etc/systemd/system/pm2-ec2-user.service`. This means the OS itself will start PM2 during boot, and PM2 will then restore whatever processes were saved with `pm2 save`. It is two layers of persistence: OS starts PM2, PM2 starts your app.

### 3.6 Verify PM2 Is Working

```bash
# Check status -- should show "online"
pm2 status

# Test the API
curl http://localhost:3000/api/health
```

**[CHECKPOINT]** Verify PM2 process management:
```bash
pm2 status
# "ecommerce-api" should show status "online"

curl -s http://localhost:3000/api/health
# Should return {"status":"ok","timestamp":"..."}
```

Both commands must succeed. The app is now running as a managed background process. If the process crashes, PM2 will restart it automatically. If the server reboots, PM2 will restore it.

---

## Section 4: Install and Configure Nginx as Reverse Proxy

### 4.1 What a Reverse Proxy Does

Right now your Node.js app runs on port 3000. Users cannot access it because:

1. **Port 3000 is not open** in the security group (and should not be -- it is an internal port)
2. **No SSL termination** -- Node.js would need to handle HTTPS certificates directly
3. **No static file serving** -- Express can serve static files, but Nginx does it ~2x faster

Nginx sits in front of Node.js and handles all of this:

```
Internet -> Nginx (:80/:443) -> PM2/Node (:3000)
                              -> Static files (dist/)
```

- Requests to `/api/*` get proxied to Node.js on port 3000
- Requests to `/*` get served as static files from `dist/` (your React build)
- Nginx handles SSL termination (decrypts HTTPS before forwarding to Node.js)

### 4.2 Install Nginx

```bash
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

The `enable` command makes Nginx start automatically on boot. The `start` command starts it now.

Verify Nginx is running:

```bash
sudo systemctl status nginx
```

You should see `active (running)` in the output.

### 4.3 Create the Nginx Configuration

Create the site configuration file:

```bash
sudo vi /etc/nginx/conf.d/ecommerce.conf
```

> **Tip:** If you are not comfortable with `vi`, use `nano` instead: `sudo nano /etc/nginx/conf.d/ecommerce.conf`

Paste this configuration:

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    # Serve React static files
    root /home/ec2-user/a-journey-to-system-architect/app/dist/client;
    index index.html;

    # Gzip compression -- reduces transfer size for text-based files
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    # React Router support:
    # 1. Try the exact file path ($uri)
    # 2. Try it as a directory ($uri/)
    # 3. Fall back to index.html (React Router handles the route client-side)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to Express via PM2
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Replace `yourdomain.com`** with your actual domain name. If you do not have a domain yet, you can use the Elastic IP directly (remove the `server_name` line entirely for now).

#### What Each Directive Does

| Directive | Purpose |
|-----------|---------|
| `listen 80` | Accept HTTP connections on port 80 |
| `server_name` | Only respond to requests for this domain (virtual hosting) |
| `root` | Base directory for serving static files |
| `index index.html` | Default file to serve when requesting a directory |
| `gzip on` | Compress responses to reduce bandwidth (faster page loads) |
| `try_files $uri $uri/ /index.html` | Check for exact file, then directory, then fall back to React's index.html for client-side routing |
| `proxy_pass` | Forward matching requests to the Node.js backend |
| `proxy_set_header Host` | Preserve the original Host header so the backend knows which domain was requested |
| `proxy_set_header X-Real-IP` | Pass the client's real IP to the backend (otherwise backend only sees 127.0.0.1) |
| `proxy_set_header X-Forwarded-For` | Standard header for tracking the chain of proxies |
| `proxy_set_header X-Forwarded-Proto` | Tells the backend whether the original request was HTTP or HTTPS |
| `proxy_http_version 1.1` | Required for WebSocket support and keepalive connections |
| `proxy_set_header Upgrade` / `Connection` | Enables WebSocket passthrough (needed if you add real-time features later) |

### 4.4 Disable the Default Nginx Config

The default Nginx configuration may conflict with yours. Rename it to disable it:

```bash
# Check if default config exists
ls /etc/nginx/conf.d/default.conf 2>/dev/null

# If it exists, rename it
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled 2>/dev/null

# Also check for the default server block in the main config
sudo grep -n "server {" /etc/nginx/nginx.conf
```

If `/etc/nginx/nginx.conf` contains a `server {}` block, you may need to comment it out or ensure your config takes priority by setting `server_name` correctly.

### 4.5 Test and Reload Nginx

**Always test the configuration before reloading:**

```bash
# Test config syntax
sudo nginx -t
```

You should see:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

> **[GOTCHA]** Never run `sudo systemctl reload nginx` without running `sudo nginx -t` first. A syntax error in your config will cause Nginx to fail to reload, and depending on the error, it might also fail to start again. Always test first.

If the test passes, reload:

```bash
sudo systemctl reload nginx
```

### 4.6 Fix Permissions for Nginx to Read App Files

Nginx runs as the `nginx` user, which needs read access to your app's static files:

```bash
# Nginx needs execute permission on all parent directories to traverse to the files
chmod 711 /home/ec2-user

# Verify Nginx can access the dist directory
sudo -u nginx stat /home/ec2-user/a-journey-to-system-architect/app/dist/client/index.html 2>/dev/null && echo "OK" || echo "Permission denied"
```

If you see "Permission denied", check each directory in the path:

```bash
namei -l /home/ec2-user/a-journey-to-system-architect/app/dist/client/index.html
```

> **[WHY]** On Linux, to read a file at a path like `/home/ec2-user/app/dist/index.html`, you need execute permission on every directory in that path. The `chmod 711` gives the `nginx` user execute permission on `/home/ec2-user` without giving it read permission (it cannot list your home directory, but it can traverse through it).

### 4.7 Test from Your Local Machine

**[CHECKPOINT]** Verify Nginx is proxying API requests:

```bash
# From your LOCAL machine (not EC2), replace with your Elastic IP
curl http://YOUR_ELASTIC_IP/api/health
```

Expected response:
```json
{"status":"ok","timestamp":"2026-05-06T12:00:00.000Z"}
```

If this works, Nginx is correctly proxying `/api/*` requests to your Node.js backend.

**Troubleshooting:**
- **Connection refused:** Check security group allows HTTP (port 80) from 0.0.0.0/0
- **502 Bad Gateway:** Nginx is running but cannot reach Node.js. Check `pm2 status` shows "online" and the app is listening on port 3000
- **403 Forbidden:** Nginx cannot read files. Check the permissions step above
- **404 Not Found:** Wrong `root` path or Node.js not handling the route

---

## Section 5: Build and Serve the React Frontend

### 5.1 Build the React App

```bash
cd ~/a-journey-to-system-architect/app

# Build the client (React via Vite)
pnpm run build:client
```

This compiles the React app and outputs static files to `dist/client/`:

```bash
ls dist/client/
# You should see: index.html  assets/
```

The `assets/` directory contains compiled JavaScript and CSS with content-hash filenames (like `index-a1b2c3.js`).

### 5.2 Verify Nginx Serves the Frontend

Nginx is already configured to serve files from `dist/client/` (you set this up in Section 4). No restart needed.

**[CHECKPOINT]** Open your browser and visit:

```
http://YOUR_ELASTIC_IP
```

You should see the e-commerce product list page. Click around -- navigation between pages should work (React Router).

> **[GOTCHA]** If you see a blank page, open the browser developer console (F12). Common issues:
> - **Failed to load resource: net::ERR_CONNECTION_REFUSED** for `/api/*` requests: The API proxy is not working. Check Nginx config and PM2 status.
> - **Failed to load resource: 404** for JavaScript files: The `root` directive in Nginx points to the wrong directory. Verify the path with `ls /home/ec2-user/a-journey-to-system-architect/app/dist/client/index.html`.
> - **React app loads but API calls fail:** Check that your React code uses relative URLs (`/api/products`, not `http://localhost:3000/api/products`). Relative URLs are handled by Nginx's proxy.

---

## Section 6: Set Up HTTPS with Let's Encrypt

### 6.1 Prerequisites

Before running Certbot, your DNS **must** already point to the Elastic IP. Let's Encrypt validates domain ownership by making an HTTP request to your domain. If DNS does not resolve to your EC2 instance, validation fails.

If you set up DNS in Phase 1, update the A record to point to your new Elastic IP:

1. Log into Cloudflare
2. Go to your domain's DNS settings
3. Update (or create) an A record:
   - **Name:** `@` (or your subdomain)
   - **Content:** `YOUR_ELASTIC_IP`
   - **Proxy status:** DNS only (gray cloud) -- Certbot needs direct access, not Cloudflare proxy

> **[WHY]** Certbot's HTTP-01 challenge works by placing a file on your server and asking Let's Encrypt to fetch it via HTTP. If Cloudflare's proxy is enabled (orange cloud), the request goes to Cloudflare's servers instead of yours, and validation fails. You can re-enable the Cloudflare proxy after getting the certificate if you want Cloudflare's CDN benefits.

### 6.2 Verify DNS Resolution

```bash
# Run this on EC2 or your local machine
dig yourdomain.com +short
```

This should return your Elastic IP address. If it returns nothing or a different IP, fix your DNS settings and wait for propagation (usually under 5 minutes with Cloudflare).

```bash
# Alternative check using nslookup
nslookup yourdomain.com
```

> **[GOTCHA]** If DNS is not pointing to your EC2 instance, Certbot will fail with an error like "Challenge failed for domain" or "Connection refused". Always verify with `dig` first.

### 6.3 Install Certbot

Amazon Linux 2023 does not have Certbot in its package repositories. Install it via pip in a Python virtual environment:

```bash
# Create a virtual environment for Certbot
sudo python3 -m venv /opt/certbot/

# Upgrade pip inside the venv
sudo /opt/certbot/bin/pip install --upgrade pip

# Install Certbot and the Nginx plugin
sudo /opt/certbot/bin/pip install certbot certbot-nginx

# Create a symlink so you can run certbot from anywhere
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Verify
certbot --version
```

> **[WHY]** Using a Python venv isolates Certbot's dependencies from the system Python. This prevents version conflicts and makes it easy to update Certbot independently. The symlink lets you run `certbot` directly instead of `/opt/certbot/bin/certbot`.

### 6.4 Obtain the SSL Certificate

```bash
sudo certbot --nginx -d yourdomain.com
```

Certbot will:
1. Ask for your email address (for renewal reminders)
2. Ask you to agree to the Terms of Service
3. Perform an HTTP-01 challenge (places a file, asks Let's Encrypt to verify)
4. Automatically modify your Nginx config to add SSL settings
5. Set up a redirect from HTTP to HTTPS

After it completes, look at your Nginx config:

```bash
cat /etc/nginx/conf.d/ecommerce.conf
```

Certbot will have added lines like:

```nginx
listen 443 ssl;
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
include /etc/letsencrypt/options-ssl-nginx.conf;
ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
```

And a redirect block:

```nginx
server {
    if ($host = yourdomain.com) {
        return 301 https://$host$request_uri;
    }
    listen 80;
    server_name yourdomain.com;
    return 404;
}
```

> **[WHY]** The redirect block ensures all HTTP traffic is automatically upgraded to HTTPS. The `fullchain.pem` contains both your certificate and the intermediate certificate. `options-ssl-nginx.conf` contains recommended SSL settings (protocols, ciphers) maintained by the Certbot team.

### 6.5 Set Up Auto-Renewal

Let's Encrypt certificates expire every 90 days. Set up a cron job to renew automatically:

```bash
# Test that renewal would work (does not actually renew)
sudo certbot renew --dry-run
```

If the dry run succeeds, add a cron job:

```bash
# Renew twice daily with a random delay (recommended by Let's Encrypt)
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
```

> **[WHY]** The random delay prevents all Certbot users from hitting Let's Encrypt servers at the same time. The `-q` flag suppresses output unless there is an error. Running twice daily is fine because `certbot renew` only actually renews certificates that are within 30 days of expiration.

### 6.6 Verify HTTPS

**[CHECKPOINT]** Visit your site in a browser:

```
https://yourdomain.com
```

You should see:
- A green lock icon (or equivalent) in the browser address bar
- The e-commerce product list page loads correctly
- No mixed content warnings in the developer console

Also verify the API over HTTPS:

```bash
curl https://yourdomain.com/api/health
```

Expected:
```json
{"status":"ok","timestamp":"2026-05-06T12:00:00.000Z"}
```

And verify HTTP redirects to HTTPS:

```bash
curl -I http://yourdomain.com
```

You should see a `301 Moved Permanently` with `Location: https://yourdomain.com/`.

---

## Section 7: Rebuild Shortcut

After you tear down your environment (to save cost) or after making code changes, use this quick rebuild process.

### 7.1 After Code Changes (Instance Still Running)

```bash
cd ~/a-journey-to-system-architect/app && \
  git pull && \
  pnpm install && \
  pnpm run build:server && \
  pnpm run build:client && \
  pm2 restart ecommerce-api
```

That is it. Five commands chained together. Nginx does not need a restart because it serves static files from disk (the new build replaces the old files).

### 7.2 After Full Teardown (Starting from Scratch)

If you destroyed the EC2 instance and want to rebuild:

1. **Create VPC** (Section 1.1) -- skip if VPC still exists
2. **Launch EC2** (Sections 1.2-1.5)
3. **Update DNS** to point to the new Elastic IP
4. **Run setup script on EC2:**

```bash
# Install dependencies
sudo dnf update -y
sudo dnf install -y nodejs20 nginx git
sudo npm install -g pnpm pm2

# Clone and build
cd ~ && git clone https://github.com/YOUR_USERNAME/a-journey-to-system-architect.git
cd a-journey-to-system-architect/app
pnpm install
pnpm run build:server
pnpm run build:client

# Start with PM2
pm2 start ecosystem.config.js
pm2 startup   # Run the printed sudo command
pm2 save

# Configure Nginx (copy the config from Section 4.3)
sudo vi /etc/nginx/conf.d/ecommerce.conf
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl start nginx

# Fix permissions
chmod 711 /home/ec2-user

# Set up HTTPS (only after DNS is pointed to new Elastic IP)
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot
sudo certbot --nginx -d yourdomain.com
```

### 7.3 When to Rebuild from Scratch vs Incremental

| Situation | Approach |
|-----------|----------|
| Changed app code | Incremental (7.1) |
| Changed Nginx config | Edit config, `nginx -t`, then `systemctl reload nginx` |
| Changed PM2 config | `pm2 delete ecommerce-api`, then `pm2 start ecosystem.config.js` |
| EC2 instance terminated | Full rebuild (7.2) |
| Changed domain name | Update DNS, re-run Certbot |
| Upgrading Node.js version | SSH in, `sudo dnf install -y nodejs22`, restart PM2 |

---

## Teardown Checklist

When you are done for the day (or the phase), tear down resources to avoid charges. Delete in this order to avoid dependency errors:

1. **Stop PM2 and Nginx on EC2:**
   ```bash
   pm2 stop all
   sudo systemctl stop nginx
   ```

2. **Terminate EC2 instance:**
   - EC2 Console > Instances > Select instance > Instance State > Terminate

3. **Release Elastic IP:**
   - EC2 Console > Elastic IPs > Select > Actions > Release

4. **Delete Security Groups** (wait for EC2 termination to complete):
   - VPC Console > Security Groups > Delete `ecommerce-ec2-sg`

5. **Delete VPC** (only if you will not need it for RDS setup):
   - VPC Console > Your VPCs > Select `ecommerce-vpc` > Actions > Delete VPC
   - This also deletes associated subnets, route tables, and internet gateway

> **[WHY]** Order matters. You cannot delete a security group while an EC2 instance is using it. You cannot delete a VPC while it has active resources. An unattached Elastic IP costs $0.005/hour (~$3.65/month), so always release it when not in use.

---

## Summary

You have deployed a full-stack application to EC2 with production-grade tooling:

| Layer | Tool | What It Does |
|-------|------|-------------|
| Process management | PM2 | Runs Node.js in background, auto-restarts on crash, persists across reboots |
| Reverse proxy | Nginx | Listens on ports 80/443, serves static files, proxies API requests, terminates SSL |
| SSL/HTTPS | Certbot + Let's Encrypt | Free trusted certificates, auto-renewal, HTTP-to-HTTPS redirect |
| Application | Express + React | API on port 3000 (internal), React SPA served as static files |

The incremental approach you followed (bare Node -> PM2 -> Nginx -> React -> HTTPS) is how you should think about debugging in production: isolate each layer, verify it works independently, then add the next. When something breaks, peel back layers until you find the one that fails.

---

*Phase: 02-first-deploy | Topic: EC2 Deploy*
