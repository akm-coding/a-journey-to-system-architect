# SSL/TLS Cheatsheet

## Certbot Commands

```bash
# Get certificate with Nginx plugin (recommended)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Get certificate without modifying Nginx (standalone mode)
sudo certbot certonly --standalone -d yourdomain.com

# Get certificate using webroot (Nginx already running)
sudo certbot certonly --webroot -w /var/www/html -d yourdomain.com

# Test renewal (does not actually renew)
sudo certbot renew --dry-run

# Force renewal (even if not expiring soon)
sudo certbot renew --force-renewal

# List all certificates managed by Certbot
sudo certbot certificates

# Revoke a certificate
sudo certbot revoke --cert-path /etc/letsencrypt/live/yourdomain.com/cert.pem

# Delete a certificate from Certbot management
sudo certbot delete --cert-name yourdomain.com
```

## OpenSSL Commands

```bash
# Check certificate from a remote server
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null

# Show certificate dates and subject
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null 2>/dev/null | \
  openssl x509 -noout -dates -subject -issuer

# Show full certificate details
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null 2>/dev/null | \
  openssl x509 -noout -text

# Check certificate expiration only
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null 2>/dev/null | \
  openssl x509 -noout -enddate

# Read a local certificate file
openssl x509 -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem -noout -text

# Verify certificate chain
openssl verify -CAfile /etc/letsencrypt/live/yourdomain.com/chain.pem \
  /etc/letsencrypt/live/yourdomain.com/cert.pem
```

## Nginx SSL Configuration

```nginx
# Basic HTTPS server block
server {
    listen 443 ssl;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Recommended SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$host$request_uri;
}
```

## Certificate File Locations

| File | Path | Contents |
|------|------|----------|
| Full chain | `/etc/letsencrypt/live/yourdomain.com/fullchain.pem` | Your cert + intermediate cert (use this in Nginx) |
| Private key | `/etc/letsencrypt/live/yourdomain.com/privkey.pem` | Private key (never share) |
| Certificate only | `/etc/letsencrypt/live/yourdomain.com/cert.pem` | Just your certificate |
| Chain only | `/etc/letsencrypt/live/yourdomain.com/chain.pem` | Just the intermediate certificate |

> These are symlinks to the latest version. Certbot manages rotation automatically.

## Certbot Installation

```bash
# Amazon Linux 2023
sudo dnf install -y certbot python3-certbot-nginx

# Ubuntu 22.04+
sudo apt update && sudo apt install -y certbot python3-certbot-nginx

# Check version
certbot --version
```

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| Certbot fails: "Could not connect" | Port 80 not open in security group | Add inbound rule for port 80 from 0.0.0.0/0 |
| Certbot fails: "DNS problem" | Domain not pointing to this server | Check `dig +short yourdomain.com` matches server IP |
| Certbot fails: "too many requests" | Rate limit hit (50/week) | Wait a week, or use a different subdomain |
| "Certificate expired" in browser | Auto-renewal failed | Run `sudo certbot renew` manually, check timer is active |
| "Certificate mismatch" | Domain name does not match certificate | Re-run `certbot --nginx -d correctdomain.com` |
| "Connection refused" on port 443 | Nginx not listening on 443 | Check Nginx config has `listen 443 ssl;` and restart |
| "Mixed content" warnings | HTTP resources on HTTPS page | Update all URLs in your app to use HTTPS or relative paths |
| Browser shows "Not Secure" | HTTP redirect not set up | Add redirect block in Nginx (listen 80 -> return 301 https) |

## ACM Reminder

**ACM = ALB / CloudFront / API Gateway ONLY.**

**EC2 standalone = Let's Encrypt (Certbot).**

ACM does not export private keys. You cannot install an ACM certificate on an EC2 instance. This is by design (security). ACM will be used in Phase 6 with the Application Load Balancer.

## Quick Verification

```bash
# One-liner: check HTTPS works and show cert info
curl -vI https://yourdomain.com 2>&1 | grep -E "subject:|issuer:|expire|HTTP/"
```
