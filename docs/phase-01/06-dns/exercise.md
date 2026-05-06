# DNS Exercise

## Prerequisites

- A **domain name** (any registrar works -- Cloudflare Registrar or Namecheap are good choices for cheap `.com` or `.dev` domains, typically ~$10/year)
- A running **EC2 instance with Nginx** from the previous exercises (or launch a fresh one in the default VPC with HTTP/SSH security group rules)
- Note your EC2 instance's **public IP address**

## Step 1: Set Up Cloudflare

1. Sign up at [cloudflare.com](https://www.cloudflare.com/) (free tier)
2. Click "Add a site" and enter your domain name
3. Select the **Free plan**
4. Cloudflare will scan your existing DNS records (if any)
5. Cloudflare will give you two nameservers (e.g., `adam.ns.cloudflare.com`, `betty.ns.cloudflare.com`)
6. Go to your **domain registrar** (where you bought the domain) and update the nameservers to the Cloudflare ones

> **Important:** Updating nameservers tells the internet "Cloudflare is now in charge of DNS for this domain." This can take up to 24-48 hours to propagate, but is usually much faster (under 1 hour).

## Step 2: Verify Nameserver Propagation

Wait a few minutes after updating nameservers, then check:

```bash
dig NS yourdomain.com
```

You should see Cloudflare's nameservers in the answer section:

```
;; ANSWER SECTION:
yourdomain.com.    86400   IN   NS   adam.ns.cloudflare.com.
yourdomain.com.    86400   IN   NS   betty.ns.cloudflare.com.
```

If you still see your old registrar's nameservers, wait longer and try again. You can also check from Google's resolver:

```bash
dig NS yourdomain.com @8.8.8.8
```

## Step 3: Create an A Record

In the Cloudflare dashboard:

1. Go to **DNS** > **Records**
2. Click **Add record**
   - Type: **A**
   - Name: `@` (this means the root domain, e.g., `yourdomain.com`)
   - IPv4 address: your EC2 public IP (e.g., `54.123.45.67`)
   - TTL: **300** (5 minutes -- good for testing)
   - Proxy status: **DNS only** (grey cloud icon -- click the orange cloud to toggle it off)

> **Important:** Set proxy status to "DNS only" (grey cloud). Cloudflare's orange cloud proxy adds a CDN layer that hides your real IP and adds complexity. For learning DNS fundamentals, you want direct connections.

## Step 4: Verify DNS Resolution

Wait about 30 seconds (Cloudflare is fast), then:

```bash
# Full DNS query
dig yourdomain.com

# Short format -- just the IP
dig +short yourdomain.com
# Should output: 54.123.45.67 (your EC2 IP)

# Alternative tool
nslookup yourdomain.com
```

Now test that your web server is reachable by domain name:

```bash
curl http://yourdomain.com
# Should return the Nginx welcome page
```

If `dig` returns the right IP but `curl` fails, the issue is your security group or Nginx -- not DNS.

## Step 5: Create a CNAME Record

In the Cloudflare dashboard:

1. Click **Add record**
   - Type: **CNAME**
   - Name: `www`
   - Target: `yourdomain.com`
   - TTL: 300
   - Proxy status: DNS only

This makes `www.yourdomain.com` an alias for `yourdomain.com`.

## Step 6: Verify the CNAME

```bash
# See the CNAME chain
dig www.yourdomain.com

# You should see:
# www.yourdomain.com.  300  IN  CNAME  yourdomain.com.
# yourdomain.com.      300  IN  A      54.123.45.67

# Test with curl
curl http://www.yourdomain.com
# Should return the Nginx welcome page
```

The CNAME resolves `www.yourdomain.com` -> `yourdomain.com` -> `54.123.45.67`. Two hops, but it happens transparently.

## Step 7: Experiment with TTL and Caching

This experiment demonstrates how DNS caching works:

1. **Change the A record** to a wrong IP: `1.2.3.4`
2. **Immediately query:**
   ```bash
   dig +short yourdomain.com
   # Might still return the old (correct) IP -- it is cached
   ```
3. **Wait for the TTL to expire** (300 seconds = 5 minutes)
4. **Query again:**
   ```bash
   dig +short yourdomain.com
   # Should now return 1.2.3.4 (the wrong IP)
   ```
5. **Change it back** to the correct EC2 IP
6. **Wait for TTL again, then verify:**
   ```bash
   dig +short yourdomain.com
   # Should return the correct IP again
   ```

> **Note:** Your local resolver may cache differently. Use `dig @8.8.8.8 +short yourdomain.com` to bypass your local cache and query Google's resolver directly.

## Step 8: Check Propagation from Multiple Locations

Query different public DNS resolvers to see if they all have the same answer:

```bash
# Google DNS
dig @8.8.8.8 +short yourdomain.com

# Cloudflare DNS
dig @1.1.1.1 +short yourdomain.com

# Quad9
dig @9.9.9.9 +short yourdomain.com

# OpenDNS
dig @208.67.222.222 +short yourdomain.com
```

If all four return your EC2 IP, propagation is complete.

## Checkpoint: DNS Must Be Working Before SSL

Before proceeding to the SSL/TLS exercise, verify:
- `yourdomain.com` resolves to your EC2 public IP
- `curl http://yourdomain.com` returns the Nginx welcome page
- Your domain must resolve to your EC2 instance for Let's Encrypt to issue a certificate

## Verification Checklist

- [ ] `dig +short yourdomain.com` returns your EC2 public IP
- [ ] `dig +short www.yourdomain.com` resolves (via CNAME) to the same IP
- [ ] `curl -I http://yourdomain.com` returns HTTP 200 with Nginx headers
- [ ] `curl -I http://www.yourdomain.com` also returns HTTP 200
- [ ] You can explain the difference between an A record and a CNAME record
- [ ] You understand what TTL controls and why you would change it

## Clean Up

**Do NOT clean up yet** -- keep your DNS records and EC2 instance running. They are required for the SSL/TLS exercise.

After completing the SSL/TLS exercise, you can optionally delete DNS records if you want to stop using the domain.

## Rebuild Challenge

Delete all DNS records in Cloudflare. Recreate the A record and CNAME record. Verify resolution with `dig` from at least two different resolvers.

**Target time:** Under 3 minutes to recreate and verify.

Log your time and any issues in `docs/phase-01/rebuild-log.md`.
