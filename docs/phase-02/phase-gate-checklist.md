# Phase 2: First Deploy -- Phase Gate Checklist

Complete ALL items before advancing to Phase 3 (Containerization). Each item verifies a specific skill from this phase.

## DEPL-01: EC2 Manual Deployment

- [ ] App accessible via public URL (HTTP and HTTPS)
- [ ] `curl https://yourdomain.com/api/health` returns 200 OK with JSON `{ "status": "ok", "timestamp": "..." }`
- [ ] Nginx serves React frontend (page loads in browser, navigation between pages works)
- [ ] `pm2 status` shows "ecommerce-api" with status "online"
- [ ] PM2 survives reboot: `pm2 startup` and `pm2 save` configured, process restored after `sudo reboot`
- [ ] Can explain: What does Nginx do as a reverse proxy? Why not just expose Node.js on port 80?
- [ ] Can explain: Why use PM2 instead of running `node server.js` directly?

## DEPL-02: RDS Database Connection

- [ ] `curl https://yourdomain.com/api/products` returns product list from RDS (not empty array)
- [ ] RDS instance is in a private subnet (no public accessibility)
- [ ] RDS security group allows inbound PostgreSQL (5432) only from EC2 security group (SG referencing)
- [ ] Can connect to RDS from EC2 via `psql` but NOT from your local machine
- [ ] Can explain: How does security group referencing secure the database? Why not use an IP address?

## Resource Cleanup

- [ ] Can teardown all resources without leftover charges (follow teardown checklist in runbook)
- [ ] Can rebuild the environment from scratch using the rebuild shortcut

## Advancement Criteria

All checkboxes above must be checked before starting Phase 3. If any item is unclear, revisit the relevant section in the runbook.

---

*Phase: 02-first-deploy*
