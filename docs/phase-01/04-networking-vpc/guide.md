# Networking & VPC Guide

## Why Networking Matters

Your application is useless if nothing can reach it. When you deploy a web server on AWS, it does not just magically appear on "the internet." AWS gives you the building blocks to construct your own network -- you decide what is publicly accessible, what is hidden, and how traffic flows between components.

This is fundamentally different from running code on your laptop where `localhost:3000` just works. In AWS, you explicitly build the network that connects your server to the outside world. If you skip this understanding, you will spend hours debugging "why can't I reach my server?" when the answer is always: routing, security groups, or missing gateways.

The reason AWS separates networks into public and private sections is security. Your web server needs to face the internet, but your database absolutely should not. By placing them in different subnets with different routing rules, you create defense in depth -- even if someone compromises your web server, the database is on a separate network segment that is not directly reachable from the internet.

## What You Need to Know

### VPC (Virtual Private Cloud)

A VPC is your own isolated network inside AWS. Think of it as your private data center's network, but virtual. Every resource you launch (EC2, RDS, Lambda, etc.) lives inside a VPC.

When you create a VPC, you assign it a **CIDR block** -- a range of IP addresses that your network can use.

| CIDR Block    | Subnet Mask     | Total IPs | Typical Use              |
|---------------|-----------------|-----------|--------------------------|
| 10.0.0.0/16   | 255.255.0.0     | 65,536    | VPC (standard)           |
| 10.0.0.0/20   | 255.255.240.0   | 4,096     | Large subnet             |
| 10.0.0.0/24   | 255.255.255.0   | 256       | Standard subnet          |
| 10.0.0.0/28   | 255.255.255.240 | 16        | Small subnet             |

**Standard pattern:** VPC = `10.0.0.0/16` (gives you 65,536 addresses to carve into subnets).

> **Note:** AWS reserves 5 IP addresses in every subnet (first 4 and last 1), so a /24 subnet actually gives you 251 usable IPs.

### Subnets

Subnets carve your VPC into smaller network segments. The two fundamental types:

- **Public subnet:** Has a route to the internet via an Internet Gateway. Resources here can have public IP addresses and be reached from the internet.
- **Private subnet:** No direct route to the internet. Resources here are hidden. They can only be reached from within the VPC (or via a NAT Gateway for outbound-only access).

**Standard pattern:**
- Public subnet: `10.0.1.0/24` in `us-east-1a`
- Private subnet: `10.0.2.0/24` in `us-east-1a`

Each subnet lives in exactly one **Availability Zone** (AZ). For high availability in production, you create subnets across multiple AZs -- but for learning, one AZ is fine.

### Internet Gateway (IGW)

An Internet Gateway attaches to your VPC and enables communication between your VPC and the internet. Key facts:

- Only one IGW per VPC
- It is horizontally scaled, redundant, and highly available (AWS manages it)
- By itself, it does nothing -- you also need a route table entry pointing to it

### NAT Gateway

A NAT Gateway allows resources in a **private subnet** to reach the internet (for things like downloading software updates) without being reachable FROM the internet.

- Deployed in a **public subnet** (it needs internet access itself)
- Private subnet route table points `0.0.0.0/0` to the NAT Gateway
- **Cost:** $0.045/hr (~$32/month) plus data processing charges. Tear it down when not using it.

### Route Tables

Route tables are the rules that determine where network traffic goes. Every subnet is associated with a route table.

**Public subnet route table:**

| Destination   | Target          | Purpose                  |
|---------------|-----------------|--------------------------|
| 10.0.0.0/16   | local           | Traffic within the VPC   |
| 0.0.0.0/0     | igw-xxxxxxxx    | All other traffic to IGW |

**Private subnet route table (no internet):**

| Destination   | Target          | Purpose                  |
|---------------|-----------------|--------------------------|
| 10.0.0.0/16   | local           | Traffic within the VPC   |

**Private subnet route table (with NAT):**

| Destination   | Target          | Purpose                      |
|---------------|-----------------|------------------------------|
| 10.0.0.0/16   | local           | Traffic within the VPC       |
| 0.0.0.0/0     | nat-xxxxxxxx    | Outbound internet via NAT    |

### VPC Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC: 10.0.0.0/16                         │
│                                                                 │
│  ┌───────────────────────────┐  ┌───────────────────────────┐  │
│  │   Public Subnet            │  │   Private Subnet           │  │
│  │   10.0.1.0/24              │  │   10.0.2.0/24              │  │
│  │   (us-east-1a)             │  │   (us-east-1a)             │  │
│  │                            │  │                            │  │
│  │   ┌──────────┐             │  │   ┌──────────┐             │  │
│  │   │   EC2    │             │  │   │   RDS    │             │  │
│  │   │ (web)    │             │  │   │ (database)│            │  │
│  │   └──────────┘             │  │   └──────────┘             │  │
│  │                            │  │                            │  │
│  │   ┌──────────┐             │  │                            │  │
│  │   │   NAT   │             │  │                            │  │
│  │   │ Gateway  │             │  │                            │  │
│  │   └──────────┘             │  │                            │  │
│  │                            │  │                            │  │
│  │   Route Table:             │  │   Route Table:             │  │
│  │   10.0.0.0/16 -> local     │  │   10.0.0.0/16 -> local    │  │
│  │   0.0.0.0/0   -> igw       │  │   0.0.0.0/0   -> nat-gw   │  │
│  └───────────────────────────┘  └───────────────────────────┘  │
│                                                                 │
│  ┌─────────────────┐                                            │
│  │ Internet Gateway │                                           │
│  └────────┬────────┘                                            │
└───────────┼─────────────────────────────────────────────────────┘
            │
      ┌─────┴─────┐
      │ Internet  │
      └───────────┘
```

### Request Flow Diagram

```
Internet
   │
   ▼
┌──────────────────┐
│ Internet Gateway  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Route Table       │  0.0.0.0/0 -> igw (matches)
│ (public subnet)   │  10.0.0.0/16 -> local
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Security Group    │  Inbound: port 80 allowed? YES
│ (web-sg)          │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ EC2 Instance      │  Nginx listening on port 80
│ (10.0.1.x)       │  Processes request, sends response
└──────────────────┘
```

> **Draw this diagram yourself on paper or in Excalidraw (excalidraw.com) before moving to the exercise. Drawing reinforces understanding.** Include the VPC boundary, both subnets with their CIDRs, route tables with routes, the IGW, and at least one resource in each subnet.

## Further Reading

- [AWS VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [AWS Subnets Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html)
- [AWS Route Tables Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [AWS Internet Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
- [AWS NAT Gateway Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
