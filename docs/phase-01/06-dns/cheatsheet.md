# DNS Cheatsheet

## dig Commands

```bash
# Full DNS query
dig yourdomain.com

# Short format (IP only)
dig +short yourdomain.com

# Query a specific resolver
dig @8.8.8.8 yourdomain.com          # Google DNS
dig @1.1.1.1 yourdomain.com          # Cloudflare DNS

# Query specific record types
dig yourdomain.com A                  # IPv4 address
dig yourdomain.com CNAME              # Alias
dig yourdomain.com MX                 # Mail servers
dig yourdomain.com TXT                # Text records
dig yourdomain.com NS                 # Nameservers
dig yourdomain.com ANY                # All records (may not work with all resolvers)

# Show only the answer section
dig +noall +answer yourdomain.com

# Trace the full resolution path
dig +trace yourdomain.com
```

## nslookup Commands

```bash
# Basic lookup
nslookup yourdomain.com

# Query specific record type
nslookup -type=CNAME www.yourdomain.com
nslookup -type=MX yourdomain.com
nslookup -type=NS yourdomain.com

# Query specific server
nslookup yourdomain.com 8.8.8.8
```

## Record Type Quick Reference

| Type | Format | Example |
|------|--------|---------|
| A | `domain -> IPv4` | `example.com -> 93.184.216.34` |
| AAAA | `domain -> IPv6` | `example.com -> 2606:2800:220:1:...` |
| CNAME | `domain -> domain` | `www.example.com -> example.com` |
| MX | `domain -> mail server (priority)` | `example.com -> 10 mail.example.com` |
| TXT | `domain -> text` | `example.com -> "v=spf1 include:..."` |
| NS | `domain -> nameserver` | `example.com -> ns1.cloudflare.com` |
| SOA | `domain -> authority info` | Start of Authority (zone metadata) |

## TTL Common Values

| Seconds | Human | Use Case |
|---------|-------|----------|
| 60 | 1 min | Active debugging, testing changes |
| 300 | 5 min | During DNS migration |
| 3600 | 1 hr | Normal production |
| 86400 | 24 hr | Stable, rarely changed records |

## Cloudflare Proxy Status

| Status | Icon | Behavior |
|--------|------|----------|
| DNS only | Grey cloud | Direct connection to your server (use for learning) |
| Proxied | Orange cloud | Traffic routes through Cloudflare CDN (use for production) |

## Troubleshooting

| Problem | Check | Fix |
|---------|-------|-----|
| Domain not resolving at all | `dig NS yourdomain.com` -- are nameservers correct? | Update nameservers at registrar, wait for propagation |
| Wrong IP returned | `dig +short yourdomain.com` -- is the A record correct? | Update A record in Cloudflare, wait for TTL to expire |
| Old IP still showing | TTL has not expired | Wait for TTL, or query a resolver that does not have it cached: `dig @8.8.8.8` |
| `curl` fails but `dig` works | DNS is fine, issue is elsewhere | Check security group (port 80 open?), Nginx running? |
| CNAME not resolving | `dig www.yourdomain.com` -- is the CNAME record present? | Add CNAME record in Cloudflare |
| "SERVFAIL" response | Nameserver configuration issue | Verify nameservers are set correctly at registrar |
| Works on some resolvers, not others | Propagation in progress | Wait. Check multiple resolvers: 8.8.8.8, 1.1.1.1, 9.9.9.9 |

## Quick Propagation Check

```bash
echo "Google:"; dig @8.8.8.8 +short yourdomain.com
echo "Cloudflare:"; dig @1.1.1.1 +short yourdomain.com
echo "Quad9:"; dig @9.9.9.9 +short yourdomain.com
echo "OpenDNS:"; dig @208.67.222.222 +short yourdomain.com
```
