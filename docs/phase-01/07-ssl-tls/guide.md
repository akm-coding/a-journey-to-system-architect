# SSL/TLS Guide

## Why HTTPS Matters

HTTPS is not optional. Modern browsers display a "Not Secure" warning for HTTP sites. Google penalizes HTTP sites in search rankings. Users instinctively distrust sites without the padlock icon. If your application handles any user data at all -- even just a login form -- sending it over unencrypted HTTP is irresponsible.

TLS (Transport Layer Security) encrypts the traffic between the user's browser and your server. Without it, anyone on the same network (coffee shop WiFi, corporate network, ISP) can read everything: passwords, form data, API responses. TLS makes this traffic unreadable to eavesdroppers.

Understanding the certificate chain matters beyond just "installing SSL." When you see "certificate expired" or "certificate mismatch" errors in production, you need to know why. Is it the certificate itself? The intermediate chain? A DNS mismatch? These are common production incidents that take minutes to fix if you understand TLS, and hours if you do not.

## What You Need to Know

### How TLS Works (Simplified)

When your browser connects to `https://yourdomain.com`, a TLS handshake happens before any application data is exchanged:

```
Browser (Client)                          Server (Nginx)
       │                                        │
  1.   │─── Client Hello ────────────────────>│
       │    (supported TLS versions,            │
       │     cipher suites)                     │
       │                                        │
  2.   │<── Server Hello + Certificate ───────│
       │    (chosen cipher suite,               │
       │     server's TLS certificate)          │
       │                                        │
  3.   │─── Key Exchange ────────────────────>│
       │    (browser verifies certificate,      │
       │     both sides derive shared key)      │
       │                                        │
  4.   │<══ Encrypted Connection ═════════════│
       │    (all data encrypted with            │
       │     the shared key)                    │
       │                                        │
```

After the handshake, all HTTP traffic (requests, responses, headers, body) is encrypted. The URL path, query parameters, cookies, and form data are all protected.

### Certificate Chain

Your browser does not just trust any certificate. There is a chain of trust:

```
Root CA (e.g., ISRG Root X1)
  Built into browsers and operating systems.
  These are the "trust anchors."
       │
       ▼
Intermediate CA (e.g., Let's Encrypt R3)
  Signed by the Root CA.
  Issues certificates to end users.
       │
       ▼
Your Certificate (e.g., yourdomain.com)
  Signed by the Intermediate CA.
  This is what your server presents.
```

When Nginx sends your certificate, it also sends the intermediate certificate. The browser chains upward: your cert is signed by the intermediate, which is signed by the root. The root is pre-trusted. Chain complete -- connection is secure.

**Why this matters:** If your server does not send the intermediate certificate, some browsers will fail to verify the chain and show a security error. Certbot handles this automatically by using `fullchain.pem` (your cert + intermediate).

### Let's Encrypt

[Let's Encrypt](https://letsencrypt.org/) is a free, automated, open Certificate Authority. Key facts:

- **Free:** No cost for certificates
- **Automated:** Certbot handles requesting, installing, and renewing certificates
- **Trusted:** Recognized by all modern browsers
- **90-day certificates:** Shorter than traditional certs (1-2 years), but auto-renewal makes this painless
- **Rate limits:** 50 certificates per registered domain per week (more than enough for learning)

Certbot is the official client for Let's Encrypt. It:
1. Proves you control the domain (by responding to an HTTP challenge on port 80)
2. Gets the certificate from Let's Encrypt
3. Configures Nginx to use the certificate
4. Sets up automatic renewal via cron/systemd timer

### ACM (AWS Certificate Manager)

> **CRITICAL: ACM certificates CANNOT be installed directly on EC2 instances.**

This is the number one confusion point for AWS beginners. ACM provides free SSL/TLS certificates, but they can ONLY be used with services that integrate with ACM:

- **Elastic Load Balancer** (ALB, NLB) -- Phase 6
- **CloudFront** (CDN) -- Phase 7
- **API Gateway**
- **Elastic Beanstalk** (uses ALB under the hood)

ACM does **not** give you a `.pem` file to download and install on your server. The private key never leaves AWS. This is a security feature, but it means for a standalone EC2 instance, ACM is not an option.

**For standalone EC2: use Let's Encrypt with Certbot.**

ACM will be used hands-on in Phase 6 when you add an Application Load Balancer (ALB) in front of your EC2 instance. At that point, ACM certificates are the correct choice -- free, auto-renewing, and zero configuration on the server side.

### Nginx SSL Configuration

When Certbot configures Nginx for HTTPS, it adds directives like:

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # ... your site configuration ...
}

server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$host$request_uri;  # Redirect HTTP to HTTPS
}
```

Key concepts:
- **listen 443 ssl:** Nginx listens on the HTTPS port and terminates TLS
- **ssl_certificate:** The full certificate chain (your cert + intermediate)
- **ssl_certificate_key:** Your private key (never share this)
- **Port 80 redirect:** All HTTP requests are redirected to HTTPS (301 permanent redirect)

Nginx "terminates" TLS -- it decrypts the incoming traffic and can then forward plain HTTP to your application running on `localhost:3000`. Your application code does not need to know about TLS at all.

## Further Reading

- [AWS ACM Documentation](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html)
- [ACM Integrated Services](https://docs.aws.amazon.com/acm/latest/userguide/acm-services.html) (which services can use ACM certs)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) (for hardening Nginx SSL)
