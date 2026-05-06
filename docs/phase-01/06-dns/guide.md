# DNS Guide

## Why DNS Matters

DNS (Domain Name System) is how humans reach your application. Nobody memorizes IP addresses -- they type `yourapp.com` and expect it to work. DNS translates that human-readable name into the IP address of your server.

When "the site is down," it is often not actually down -- the DNS is misconfigured, pointing to the wrong IP, or a record change has not propagated yet. Understanding how DNS resolution works and how to debug it with tools like `dig` and `nslookup` will save you hours of frustration. These are the first tools experienced engineers reach for when diagnosing connectivity issues.

DNS also matters for SSL/TLS certificates. You cannot get a certificate for an IP address (well, you can, but you should not). You need a domain name, and that domain must resolve to your server before a Certificate Authority will issue a certificate. DNS is the prerequisite for HTTPS.

## What You Need to Know

### How DNS Resolution Works

When you type `example.com` in your browser, here is what happens:

```
Your Browser
     │
     ▼
┌─────────────────┐
│ Local DNS Cache  │  Already know the IP? Return it immediately.
└────────┬────────┘
         │ (cache miss)
         ▼
┌─────────────────┐
│ Recursive        │  Your ISP's DNS server (or 8.8.8.8, 1.1.1.1)
│ Resolver         │  Does the heavy lifting of querying the chain.
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Root Nameserver  │  "I don't know example.com, but .com is handled
│ (.)             │   by these TLD nameservers..."
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ TLD Nameserver   │  "I don't know example.com, but its authoritative
│ (.com)           │   nameservers are ns1.cloudflare.com..."
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Authoritative        │  "example.com = 93.184.216.34"
│ Nameserver           │  (This is where YOUR DNS records live)
│ (ns1.cloudflare.com) │
└──────────────────────┘
```

The entire chain resolves in milliseconds. Results are cached at multiple levels based on TTL.

### Record Types

| Type  | Purpose | Example | When to Use |
|-------|---------|---------|-------------|
| **A** | Maps domain to IPv4 address | `example.com -> 93.184.216.34` | Most common -- point domain to your server |
| **AAAA** | Maps domain to IPv6 address | `example.com -> 2606:2800:...` | IPv6 support (less common for learning) |
| **CNAME** | Maps domain to another domain (alias) | `www.example.com -> example.com` | Subdomains that should follow the main domain |
| **MX** | Mail routing | `example.com -> mail.example.com` | Email delivery (not needed for web apps) |
| **TXT** | Arbitrary text | `example.com -> "v=spf1 ..."` | Domain verification, SPF, DKIM |
| **NS** | Nameserver delegation | `example.com -> ns1.cloudflare.com` | Set by registrar, points to your DNS provider |

For this phase, you primarily need **A** records (point domain to EC2 IP) and **CNAME** records (point `www` to the root domain).

### TTL (Time to Live)

TTL tells DNS resolvers how long to cache a record before checking for updates. Measured in seconds.

| TTL Value | Duration | When to Use |
|-----------|----------|-------------|
| 60        | 1 minute | Active debugging / testing changes |
| 300       | 5 minutes | During DNS migration or changes |
| 3600      | 1 hour | Normal production use |
| 86400     | 24 hours | Stable records that rarely change |

**Low TTL during changes:** When you are about to change an IP address, lower the TTL first (to 60 or 300). Wait for the old TTL to expire. Then make the change. This way, the old IP is only cached for a short time.

**Higher TTL for stability:** Once everything is working, increase TTL. This reduces DNS query load and makes resolution slightly faster for repeat visitors.

### DNS Propagation

When you change a DNS record, the change is not instant worldwide. Different resolvers have the old record cached with different remaining TTLs. "Propagation" is the time it takes for all caches to expire and pick up the new value.

- **Typical propagation:** Minutes to a few hours
- **Worst case:** Up to 48 hours (rare, only if the old TTL was very high)
- **How to check:** Query different resolvers directly to see if they have the new value

```bash
dig @8.8.8.8 yourdomain.com    # Google's resolver
dig @1.1.1.1 yourdomain.com    # Cloudflare's resolver
dig @9.9.9.9 yourdomain.com    # Quad9's resolver
```

If all three return the new IP, propagation is effectively complete.

### Cloudflare vs Route 53

For this phase, we use **Cloudflare (free tier)** for DNS management. Here is the comparison:

| Feature | Cloudflare (Free) | Route 53 |
|---------|-------------------|----------|
| Cost | Free | $0.50/month per hosted zone + $0.40/million queries |
| DNS Speed | ~11ms avg | ~30ms avg |
| UI | Excellent, beginner-friendly | AWS Console (functional but dense) |
| DDoS Protection | Included (free) | Not included (need AWS Shield) |
| CDN/Proxy | Included (optional) | Not included (need CloudFront) |
| Alias Records | Flattened CNAME (similar) | Native alias records (for AWS services) |
| Health Checks | Paid plan | $0.50/month per check |
| Weighted Routing | Not available | Available |

**Why Cloudflare for learning:** Zero cost, fast DNS, easy UI. You learn the same DNS concepts (A records, CNAME, TTL, propagation) regardless of which provider hosts your records.

**Why Route 53 for production AWS:** Native integration with AWS services. Alias records can point directly to ALBs, CloudFront, S3 without exposing IP addresses. Health checks with failover routing. You will use Route 53 in later phases when Terraform manages your infrastructure.

## Further Reading

- [AWS Route 53 Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html)
- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [How DNS Works (Cloudflare Learning)](https://www.cloudflare.com/learning/dns/what-is-dns/)
- [dig Command Manual](https://linux.die.net/man/1/dig)
