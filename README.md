# personal-site-infra

Infrastructure as Code for a personal static site hosted on a Debian web server on AWS, built with Terraform.
Provisioned remotely  — no local state, no hardcoded credentials.

---

## Architecture

```
                        ┌─────────────────────────────────────┐
                        │           AWS (sa-east-1)           │
                        │                                     │
                        │   ┌─────────────────────────────┐   │
                        │   │      VPC 10.0.0.0/16        │   │
                        │   │                             │   │
                        │   │  ┌───────────────────────┐  │   │
                        │   │  │  Public Subnet        │  │   │
                        │   │  │  10.0.1.0/24          │  │   │
                        │   │  │                       │  │   │
                        │   │  │  ┌─────────────────┐  │  │   │
                        │   │  │  │  EC2 t4g.micro  │  │  │   │
                        │   │  │  │  Debian 13 ARM  │  │  │   │
                        │   │  │  │                 │  │  │   │
                        │   │  │  │  :443 (HTTPS)   │  │  │   │
                        │   │  │  │  :22  (SSH)*    │  │  │   │
                        │   │  │  └────────┬────────┘  │  │   │
                        │   │  │           │ web_sg    │  │   │
                        │   │  └───────────┼───────────┘  │   │
                        │   │              │              │   │
                        │   │  ┌──────────▼────────────┐  │   │
                        │   │  │  Internet Gateway     │  │   │
                        │   │  └──────────┬────────────┘  │   │
                        │   └────────────-┼───────────────┘   │
                        └────────────────-┼───────────────────┘
                                          │
                                     Internet
                                          │
                                    Your machine
                                   (ED25519 key)

* SSH is open temporarily during bootstrap.
  Phase 2: Tailscale replaces public SSH access.
```

---

## Stack

| Layer | Tool |
|---|---|
| IaC | Terraform >= 1.2.0 |
| Provider | AWS (`hashicorp/aws ~> 5.0`) |
| Remote state | HCP Terraform |
| OS | Debian 13 ARM64 (t4g.micro) |
| Access | ED25519 SSH key pair |

---

## File Structure

```
.
├── terraform/
│   ├── provider.tf
│   ├── variables.tf
│   ├── network.tf
│   ├── ec2.tf
│   ├── iam.tf
│   └── outputs.tf
└── README.md
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.2.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with valid credentials
- An ED25519 SSH key at `~/.ssh/id_ed25519.pub`
- A [HCP Terraform](https://app.terraform.io/) account (free tier)

---

## Usage

```bash
# Clone the repository
git clone https://github.com/luisbrancher/personal-site-infra
cd personal-site-infra/terraform

# Authenticate with HCP Terraform
terraform login

# Initialize providers and remote backend
terraform init

# Review the execution plan
terraform plan

# Apply
terraform apply

# When done, destroy all resources
terraform destroy
```

After `apply`, the instance public IP is displayed as output:

```bash
Outputs:
ip_publico = "x.x.x.x"
```

---

## Design Decisions

**Custom VPC instead of the default**  
The AWS default VPC is shared across all resources in an account. This project provisions a dedicated VPC with explicit subnet, IGW, and route table — full control over network segmentation from the start.

**Least-privilege IAM policy**  
Instead of `AmazonEC2FullAccess`, a custom policy grants only the actions Terraform actually needs. A `Deny` condition blocks any instance type other than `t4g.micro`, regardless of other policies attached to the user — defense in depth at the IAM level.

**No long-lived access keys in code**  
Access keys are created manually and stored as sensitive variables in HCP Terraform. Keys generated inside Terraform end up in the `.tfstate` file in plaintext — a well-known security risk.

**Hardening at boot via `user_data`**  
The instance boots with password authentication disabled, root login blocked, and public key authentication enforced. No manual post-deploy configuration required.

**SSH open temporarily — by design**  
Port 22 is open to `0.0.0.0/0` during the bootstrap phase. This is a documented, intentional trade-off: the author is traveling across Europe with no fixed IP. Phase 2 replaces public SSH with Tailscale access over a private network.

**`data "aws_ami"` instead of hardcoded AMI ID**  
The AMI is resolved dynamically at plan time using filters for the latest official Debian 13 ARM64 image. Hardcoded AMI IDs become stale and break silently.

---

## Roadmap

- [ ] Phase 2 — Ansible provisioning: install Tailscale, nginx, SSL certificate for `.dev` domain
- [ ] Close port 22, move all access to Tailscale private network
- [ ] IAM hardening: migrate to IAM Identity Center, eliminate long-lived access keys
- [ ] Explore OIDC for keyless authentication in CI/CD pipelines

---

## Notes

This project is part of a portfolio documenting a career transition from video production into cloud infrastructure and DevOps. It is intentionally built in the open to demonstrate real decision-making, including trade-offs and incremental improvements — not just the finished result.

The target workload is a static personal site on a .dev domain — 
intentionally simple, with infrastructure complexity focused on 
security and reproducibility rather than scale.

---

*Managed by Terraform · sa-east-1 · Debian 13 ARM64*
