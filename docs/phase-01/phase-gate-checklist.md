# Phase 1: Phase Gate Checklist

## Instructions

Every item below must be checked off before you proceed to Phase 2. This is a strict gate -- no exceptions. If you cannot do something on this list, go back and practice until you can.

For each item, you should be able to demonstrate the skill, not just say "I read about it." Proof means doing it live or showing a screenshot/terminal output.

---

## FOUND-01: Linux Fundamentals

- [ ] Can SSH into an EC2 instance using a .pem key file
- [ ] Can navigate the filesystem (ls, cd, pwd, find)
- [ ] Can view file contents (cat, less, head, tail)
- [ ] Can edit files from the terminal (nano or vim)
- [ ] Can create, copy, move, and delete files and directories (touch, cp, mv, rm, mkdir)
- [ ] Can use pipes and redirection (|, >, >>)
- [ ] Can search within files (grep)

## FOUND-02: Processes & Permissions

- [ ] Can list running processes (ps aux, top/htop)
- [ ] Can manage services with systemctl (start, stop, restart, status, enable)
- [ ] Can set file permissions (chmod) and explain octal notation (e.g., 755)
- [ ] Can change file ownership (chown)
- [ ] Can manage environment variables (export, echo $VAR, .bashrc/.profile)
- [ ] Can find and kill processes (kill, pkill)

## FOUND-03: Networking & VPC

- [ ] Can explain what a VPC is and why it exists
- [ ] Can diagram a VPC with public and private subnets (draw it, not just read one)
- [ ] Can create a VPC with subnets, route tables, and an internet gateway
- [ ] Can explain the difference between public and private subnets
- [ ] Can explain what a NAT Gateway does and when you need one
- [ ] Can configure security group inbound and outbound rules
- [ ] Can explain why security groups are stateful
- [ ] Can trace a request from the internet through IGW -> route table -> subnet -> security group -> EC2

## FOUND-04: DNS

- [ ] Can explain how DNS resolution works (recursive resolver, root, TLD, authoritative)
- [ ] Can create an A record pointing a domain to an EC2 public IP
- [ ] Can create a CNAME record pointing a subdomain to another domain
- [ ] Can verify DNS resolution with dig and/or nslookup
- [ ] Can explain TTL and its practical implications

## FOUND-05: SSL/TLS

- [ ] Can explain what TLS does (encryption, authentication, integrity)
- [ ] Can install Certbot on an EC2 instance
- [ ] Can obtain a Let's Encrypt certificate for a domain
- [ ] Can verify HTTPS works (curl -I https://yourdomain.com)
- [ ] Can explain the difference between ACM and Let's Encrypt (when to use each)
- [ ] Can explain what happens during a TLS handshake (high level)

## FOUND-06: AWS Account & Budget

- [ ] Have an IAM user (not root) with MFA enabled
- [ ] AWS CLI is configured and working (`aws sts get-caller-identity` shows IAM user ARN)
- [ ] Budget alert is set at $10/month
- [ ] Can explain why you should not use root account for daily work
- [ ] Can explain the principle of least privilege

---

## Final Gate

- [ ] **ALL items above are checked**
- [ ] Progress log has entries for all 7 topics
- [ ] At least one rebuild attempt logged for each topic
- [ ] Ready to proceed to Phase 2: First Deploy
