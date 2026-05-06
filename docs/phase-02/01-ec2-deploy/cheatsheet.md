# EC2 Deployment Cheatsheet

Quick reference for all commands used in the deployment runbook.

## EC2 Setup

```bash
# SSH into instance
ssh -i ~/path/to/your-key.pem ec2-user@YOUR_ELASTIC_IP

# Install Node.js 20
sudo dnf update -y
sudo dnf install -y nodejs20

# Fix node binary if needed (AL2023 alternatives issue)
sudo alternatives --install /usr/bin/node node /usr/bin/node-20 1

# Install pnpm and git
sudo npm install -g pnpm
sudo dnf install -y git
```

## Node.js / pnpm

```bash
# Clone and setup
cd ~ && git clone https://github.com/YOUR_USERNAME/a-journey-to-system-architect.git
cd a-journey-to-system-architect/app
pnpm install

# Build
pnpm run build:server     # Compile TypeScript -> dist/server/
pnpm run build:client     # Build React -> dist/client/

# Run directly (testing only)
PORT=3000 node dist/server/index.js
```

## PM2 Commands

```bash
# Install
sudo npm install -g pm2

# Start from ecosystem file
pm2 start ecosystem.config.js

# Process management
pm2 status                    # List all processes
pm2 logs ecommerce-api        # View real-time logs
pm2 logs ecommerce-api --lines 100  # Last 100 lines
pm2 restart ecommerce-api     # Restart
pm2 stop ecommerce-api        # Stop
pm2 delete ecommerce-api      # Remove from PM2

# Startup persistence (BOTH required)
pm2 startup                   # Run the printed sudo command!
pm2 save                      # Save current process list
```

## Nginx Commands

```bash
# Install and enable
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Config management
sudo vi /etc/nginx/conf.d/ecommerce.conf    # Edit config
sudo nginx -t                                # TEST before reload (always!)
sudo systemctl reload nginx                  # Apply changes
sudo systemctl restart nginx                 # Full restart
sudo systemctl status nginx                  # Check status

# Disable default config
sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled

# Check error logs
sudo tail -f /var/log/nginx/error.log

# Fix file permissions for Nginx
chmod 711 /home/ec2-user
```

## Certbot / HTTPS

```bash
# Install Certbot
sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Get certificate (DNS must point to EC2 first!)
sudo certbot --nginx -d yourdomain.com

# Verify auto-renewal
sudo certbot renew --dry-run

# Set up auto-renewal cron
echo "0 0,12 * * * root /opt/certbot/bin/python -c 'import random; import time; time.sleep(random.random() * 3600)' && sudo certbot renew -q" | sudo tee -a /etc/crontab > /dev/null

# Check DNS before Certbot
dig yourdomain.com +short    # Should return your Elastic IP
```

## Rebuild Shortcut

```bash
# After code changes (instance still running)
cd ~/a-journey-to-system-architect/app && \
  git pull && \
  pnpm install && \
  pnpm run build:server && \
  pnpm run build:client && \
  pm2 restart ecommerce-api
```

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| API not responding | PM2 process crashed | `pm2 status` then `pm2 logs ecommerce-api` |
| 502 Bad Gateway | Node.js not running on port 3000 | `pm2 restart ecommerce-api` |
| Nginx won't start | Config syntax error | `sudo nginx -t` to find the error |
| 403 Forbidden | Nginx can't read files | `chmod 711 /home/ec2-user` and check `namei -l` |
| HTTPS fails | DNS not pointing to EC2 | `dig yourdomain.com +short` |
| Blank page | Wrong build path or API URLs | Check browser console (F12) for errors |
| App gone after reboot | Forgot `pm2 save` | `pm2 start ecosystem.config.js && pm2 save` |
| `node: command not found` | AL2023 alternatives issue | `sudo alternatives --install /usr/bin/node node /usr/bin/node-20 1` |

---

*Phase: 02-first-deploy | Topic: EC2 Deploy*
