# SSL/TLS Exercise

## Prerequisites

- EC2 instance with Nginx running and accessible via HTTP
- Domain name pointing to your EC2 public IP (from the DNS exercise)
- SSH access to the EC2 instance
- Security group allows both HTTP (port 80) AND HTTPS (port 443)

## Step 1: Verify Prerequisites

Before starting, confirm everything is in place:

```bash
# From your local machine:
curl -I http://yourdomain.com
```

You should see:
```
HTTP/1.1 200 OK
Server: nginx/...
```

If this does not work, fix your DNS or Nginx setup first. Let's Encrypt will fail if it cannot reach your server on port 80 via the domain name.

## Step 2: Ensure Port 443 Is Open

Check your security group includes HTTPS:

```bash
aws ec2 describe-security-groups --group-ids sg-xxx \
  --query 'SecurityGroups[].IpPermissions[?FromPort==`443`]'
```

If port 443 is not open, add it:

```bash
aws ec2 authorize-security-group-ingress --group-id sg-xxx \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
```

## Step 3: Install Certbot

SSH into your EC2 instance:

```bash
ssh -i ~/.ssh/my-ec2-key.pem ec2-user@yourdomain.com
```

**Amazon Linux 2023:**
```bash
sudo dnf install -y certbot python3-certbot-nginx
```

**Ubuntu (alternative):**
```bash
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

Verify the installation:
```bash
certbot --version
```

## Step 4: Get the Certificate

Run Certbot with the Nginx plugin:

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Certbot will:
1. Ask for your email address (for renewal notices and urgent security alerts)
2. Ask you to agree to the Terms of Service
3. Ask if you want to share your email with the EFF (optional)
4. Automatically verify you control the domain (HTTP-01 challenge -- it places a file on your server and Let's Encrypt checks it exists)
5. Download the certificate
6. Automatically modify your Nginx configuration to serve HTTPS
7. Set up automatic HTTP-to-HTTPS redirect

If successful, you will see:

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/yourdomain.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

> **If Certbot fails:** Common causes:
> - DNS not pointing to this server (check `dig +short yourdomain.com` matches your server IP)
> - Port 80 not open in security group
> - Nginx not running (`sudo systemctl status nginx`)
> - Cloudflare proxy enabled (must be "DNS only" / grey cloud)

## Step 5: Verify HTTPS Works

**From your local machine:**

```bash
# Check HTTPS
curl -I https://yourdomain.com
```

You should see:
```
HTTP/2 200
server: nginx/...
```

**Check HTTP redirect:**
```bash
curl -I http://yourdomain.com
```

You should see:
```
HTTP/1.1 301 Moved Permanently
Location: https://yourdomain.com/
```

**In your browser:**
- Visit `https://yourdomain.com` -- you should see the padlock icon
- Visit `http://yourdomain.com` -- it should redirect to HTTPS automatically
- Click the padlock to inspect the certificate details

## Step 6: Inspect the Certificate

From the EC2 instance, examine the certificate details:

```bash
# Connect and display certificate information
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null 2>/dev/null | \
  openssl x509 -noout -dates -subject -issuer
```

You should see something like:
```
notBefore=May  6 00:00:00 2026 GMT
notAfter=Aug  4 00:00:00 2026 GMT
subject=CN = yourdomain.com
issuer=C = US, O = Let's Encrypt, CN = R3
```

Key observations:
- **subject:** Your domain name
- **issuer:** Let's Encrypt (the CA that signed your cert)
- **notAfter:** ~90 days from issuance (Let's Encrypt certificates are short-lived)

You can also check from your local machine:
```bash
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null 2>/dev/null | \
  openssl x509 -noout -text | head -20
```

## Step 7: Test Auto-Renewal

Certbot sets up automatic renewal. Test that it works:

```bash
sudo certbot renew --dry-run
```

You should see:
```
Congratulations, all simulated renewals succeeded:
  /etc/letsencrypt/live/yourdomain.com/fullchain.pem (success)
```

**How auto-renewal works:**
- Certbot installs a systemd timer (or cron job) that runs twice daily
- It checks if any certificate is within 30 days of expiry
- If so, it renews automatically
- No manual intervention needed

Check the timer:
```bash
# On systemd-based systems (AL2023, Ubuntu 20+)
sudo systemctl list-timers | grep certbot
```

## Step 8: Examine What Certbot Changed

Look at the Nginx configuration to understand what Certbot added:

```bash
# Amazon Linux 2023 (default Nginx config)
sudo cat /etc/nginx/nginx.conf

# Or if using conf.d (check which file has your server blocks)
sudo ls /etc/nginx/conf.d/
sudo cat /etc/nginx/conf.d/default.conf
```

Look for these Certbot-added lines:

```nginx
# These lines were added by Certbot:
listen 443 ssl;
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
include /etc/letsencrypt/options-ssl-nginx.conf;
ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
```

And the HTTP-to-HTTPS redirect block:

```nginx
server {
    if ($host = www.yourdomain.com) {
        return 301 https://$host$request_uri;
    }
    if ($host = yourdomain.com) {
        return 301 https://$host$request_uri;
    }
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 404;
}
```

**Understanding the files:**
- `fullchain.pem` -- Your certificate + intermediate certificate (sent to browsers)
- `privkey.pem` -- Your private key (never share this)
- `options-ssl-nginx.conf` -- Certbot's recommended SSL settings (cipher suites, protocols)
- `ssl-dhparams.pem` -- Diffie-Hellman parameters for key exchange

These files live in `/etc/letsencrypt/live/yourdomain.com/` and are symlinks to the latest version.

## Verification Checklist

- [ ] `curl -I https://yourdomain.com` returns HTTP/2 200 with valid certificate
- [ ] `curl -I http://yourdomain.com` redirects to HTTPS (301)
- [ ] `https://www.yourdomain.com` also works with valid certificate
- [ ] Browser shows padlock icon on `https://yourdomain.com`
- [ ] `openssl s_client` shows Let's Encrypt as the issuer
- [ ] `sudo certbot renew --dry-run` succeeds
- [ ] You can identify the Certbot-added lines in the Nginx config
- [ ] You can explain why ACM cannot be used on standalone EC2

## Clean Up

This exercise is the culmination of Phase 1 networking topics. Keep it running as proof of completion for the phase gate checklist.

When you are fully done with Phase 1:
1. Terminate the EC2 instance
2. Release any Elastic IP (if allocated)
3. DNS records can stay (they will just point to a dead IP)
4. Certbot renewal will simply fail harmlessly on a terminated instance

## Rebuild Challenge

This is the full-stack rebuild -- the ultimate Phase 1 test:

1. Terminate the EC2 instance
2. Launch a new EC2 instance (Amazon Linux 2023, t2.micro, in public subnet with proper SG)
3. Install Nginx
4. Update DNS A record to point to the new public IP
5. Wait for DNS propagation (check with `dig`)
6. Install Certbot and get a new Let's Encrypt certificate
7. Verify HTTPS works

**Target time:** Under 20 minutes for the complete setup (EC2 + Nginx + DNS update + SSL certificate).

This exercises everything: EC2, security groups, Nginx, DNS, and SSL/TLS.

Log your time and any issues in `docs/phase-01/rebuild-log.md`.
