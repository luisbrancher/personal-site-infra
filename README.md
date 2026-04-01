# personal-site-infra

Infrastructure as Code for a personal static site hosted on a Debian web server on AWS, built with Terraform and Ansible.
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
                    │   │  │  │  :80  (HTTP)*   │  │  │   │
                    │   │  │  │  :22  (SSH)**   │  │  │   │
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
                                Cloudflare
                              (proxy + HTTPS)
                                      │
                                 Internet
                                      │
                                Your machine
                               (ED25519 key)

*  HTTP :80 is open for Cloudflare origin communication.
   HTTPS is terminated at Cloudflare — the visitor always sees HTTPS.
** SSH is open temporarily during bootstrap.
  Phase 2: Tailscale replaces public SSH access.
```

---

## Stack

| Layer | Tool |
|---|---|
| IaC | Terraform >= 1.2.0 |
| Providers | AWS (`hashicorp/aws ~> 5.0`), Cloudflare (`cloudflare/cloudflare ~> 4.0`) |
| Configuration | Ansible |
| Secrets | HCP Terraform (AWS + Cloudflare), Ansible Vault (Tailscale) |
| Remote state | HCP Terraform |
| OS | Debian 13 ARM64 (t4g.micro) |
| Access | ED25519 SSH key pair → Tailscale (Phase 2) |
| DNS | Cloudflare (proxied) |

---

## File Structure

```
.
├── terraform/
│   ├── provider.tf       # AWS + Cloudflare providers
│   ├── variables.tf
│   ├── network.tf
│   ├── ec2.tf
│   ├── iam.tf
│   ├── cloudflare.tf     # DNS records for luisbrancher.dev
│   └── outputs.tf
├── ansible/
│   ├── inventory.ini     # EC2 host (IP → Tailscale hostname after Phase 2)
│   ├── site.yml          # main playbook
│   ├── group_vars/all/
│   │   ├── all.yml       # domain, paths, variable references
│   │   └── vault.yml     # encrypted secrets (Ansible Vault)
│   └── templates/
│       └── nginx.conf.j2 # nginx virtual host template
└── README.md
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.2.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- [AWS CLI](https://aws.amazon.com/cli/) configured with valid credentials
- An ED25519 SSH key at `~/.ssh/id_ed25519.pub`
- A [HCP Terraform](https://app.terraform.io/) account (free tier)
- A Cloudflare account with `CLOUDFLARE_API_TOKEN` set as an environment variable in the HCP workspace

---

## Usage

### Phase 1 — Provision infrastructure
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

# Apply — provisions EC2 and creates Cloudflare DNS records
terraform apply
```

After `apply`, the instance public IP is displayed as output:
```bash
Outputs:
ip_publico = "x.x.x.x"
```

### Phase 2 — Configure server
```bash
cd ../ansible

# Update inventory.ini with the IP from terraform output
# ansible_host=

# Run the playbook
ansible-playbook site.yml -i inventory.ini --ask-vault-pass
```

The playbook installs nginx, clones the site from GitHub, and connects the instance to Tailscale.

### Phase 3 — Harden access

After confirming SSH works via Tailscale:
```bash
# Confirm Tailscale access before proceeding
ssh admin@

# Update inventory.ini to use Tailscale hostname
# ansible_host=

# Remove port 22 ingress rule from security group in network.tf, then:
terraform apply
```

---

## Design Decisions

**Custom VPC instead of the default**
The AWS default VPC is shared across all resources in an account. This project provisions a dedicated VPC with explicit subnet, IGW, and route table — full control over network segmentation from the start.

**Least-privilege IAM policy**
Instead of `AmazonEC2FullAccess`, a custom policy grants only the actions Terraform actually needs. A `Deny` condition blocks any instance type other than `t4g.micro`, regardless of other policies attached to the user — defense in depth at the IAM level.

**No long-lived access keys in code**
Access keys are created manually and stored as sensitive environment variables in HCP Terraform. Keys generated inside Terraform end up in the `.tfstate` file in plaintext — a well-known security risk.

**Hardening at boot via `user_data`**
The instance boots with password authentication disabled, root login blocked, and public key authentication enforced. No manual post-deploy configuration required.

**SSH open temporarily — by design**
Port 22 is open to `0.0.0.0/0` during the bootstrap phase. This is a documented, intentional trade-off. Phase 2 replaces public SSH with Tailscale access over a private network.

**`data "aws_ami"` instead of hardcoded AMI ID**
The AMI is resolved dynamically at plan time using filters for the latest official Debian 13 ARM64 image. Hardcoded AMI IDs become stale and break silently.

**DNS managed by Terraform, not Ansible**
Cloudflare DNS records are provisioned by Terraform alongside the EC2 instance. This avoids workarounds to fetch the public IP at Ansible runtime — Terraform already knows the IP as a native resource reference (`aws_instance.server_debian.public_ip`).

**HTTP on origin, HTTPS at edge**
Cloudflare terminates HTTPS for the visitor. The EC2 nginx listens on port 80 — the Cloudflare → origin leg is HTTP over a proxied connection. The `.dev` TLD HTTPS requirement is satisfied at the Cloudflare layer without managing certificates on the server.

**Secrets split by tool responsibility**
AWS and Cloudflare credentials live in HCP Terraform (used at provision time). The Tailscale auth key lives in Ansible Vault (used at configuration time). Each secret is stored closest to where it is consumed.

---

## Roadmap

- [x] Phase 1 — Terraform: VPC, EC2, IAM, security group, HCP remote state
- [x] Cloudflare DNS provisioned via Terraform
- [x] Phase 2 — Ansible: nginx, git deploy, Tailscale
- [ ] Close port 22, move all access to Tailscale private network
- [ ] GitHub Actions: automatic deploy on push to main
- [ ] IAM hardening: migrate to IAM Identity Center, eliminate long-lived access keys
- [ ] Explore OIDC for keyless authentication in CI/CD pipelines

---

## Notes

This project is intentionally built in the open - documenting real decisions, trade-offs,and incremental improvements as the infrastructure evolves.
The target workload is a static personal site on a .dev domain, with complexity focused on security and reproducibility rather than scale.

---

*Managed by Terraform + Ansible · sa-east-1 · Debian 13 ARM64*