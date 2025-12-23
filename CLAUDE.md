# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloudEnv is an Infrastructure as Code (IaC) project for deploying secure cloud infrastructure on SSDNodes VPS. The architecture consists of:

- **OPNsense Firewall**: Captures the VPS public IP via macvtap, provides NAT, firewall rules, and Tailscale VPN
- **Proxmox VE**: Virtualization platform on private network (10.0.0.0/24), accessible only via Tailscale
- **Tailscale**: Site-to-site VPN connecting VPS private network to home tailnet

```
Internet ──► Public IPv4 ──► OPNsense (WAN) ──► Private Network (10.0.0.0/24)
                                    │                      │
                                    │                      └──► Proxmox (10.0.0.10)
                                    │
                                    └──► Tailscale ──► Home Network
```

## Constitution Principles

This project follows a formal constitution (`.specify/memory/constitution.md`) with five core principles:

1. **Security-First Design**: Network isolation, encrypted transit, least privilege, credential management via Ansible Vault
2. **Reliability Through Simplicity**: Minimal components, documented state, graceful failure, idempotent operations
3. **Infrastructure as Code**: All config declarative, version controlled, reproducible - no manual snowflakes
4. **Test Coverage Discipline**: Validation before apply, contract tests, integration tests for critical paths
5. **Extensibility by Design**: Modular structure, standard interfaces, parameterized configuration

## Common Commands

### Full Deployment

```bash
# Initial setup
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp ansible/inventory/group_vars/vault.yml.example ansible/inventory/group_vars/vault.yml
ansible-vault encrypt ansible/inventory/group_vars/vault.yml

# Full deployment (interactive, with confirmations)
./scripts/deploy.sh deploy

# Individual phases
./scripts/deploy.sh bootstrap       # Initial VPS setup with libvirt
./scripts/deploy.sh terraform init  # Initialize Terraform
./scripts/deploy.sh terraform plan  # Show planned changes
./scripts/deploy.sh terraform apply # Apply infrastructure
./scripts/deploy.sh opnsense        # Configure OPNsense firewall
./scripts/deploy.sh tailscale       # Deploy Tailscale VPN
./scripts/deploy.sh proxmox         # Deploy Proxmox VE
```

### Testing

```bash
# Run all tests
./scripts/test.sh

# Specific test suites
./scripts/test.sh security        # Firewall rule validation
./scripts/test.sh connectivity    # Tailscale route tests
./scripts/test.sh proxmox         # Proxmox accessibility

# Quick smoke tests
./scripts/test.sh --quick

# From Tailscale network (enables remote tests)
./scripts/test.sh --from-tailnet
```

### Validation and Status

```bash
./scripts/deploy.sh validate   # Validate Terraform + Ansible configs
./scripts/deploy.sh status     # Show deployment status
./scripts/deploy.sh destroy    # Tear down infrastructure
./scripts/backup.sh            # Create config backups
```

### Ansible Playbooks

```bash
cd ansible
ansible-playbook playbooks/bootstrap.yml -i inventory/hosts.yml
ansible-playbook playbooks/opnsense.yml -i inventory/hosts.yml
ansible-playbook playbooks/tailscale.yml -i inventory/hosts.yml
ansible-playbook playbooks/proxmox.yml -i inventory/hosts.yml
ansible-playbook playbooks/site.yml -i inventory/hosts.yml      # Full deployment
ansible-playbook playbooks/harden.yml -i inventory/hosts.yml --tags disable-direct-ssh
ansible-playbook playbooks/rotate-credentials.yml -i inventory/hosts.yml
```

### Terraform Operations

```bash
cd terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform destroy
```

## Architecture

### Directory Structure

```
terraform/
├── main.tf              # Root module: orchestrates vmnet, opnsense, proxmox modules
├── variables.tf         # Input variables (IPs, resources, credentials)
├── outputs.tf           # Infrastructure outputs
├── versions.tf          # Provider versions (libvirt >= 0.7.0)
└── modules/
    ├── libvirt-network/ # Private network (10.0.0.0/24) via virbr1 bridge
    ├── opnsense-vm/     # Firewall VM with macvtap WAN + virbr1 LAN
    └── proxmox-vm/      # Virtualization VM with root + data disks

ansible/
├── inventory/
│   ├── hosts.yml        # Groups: hypervisors, firewalls, proxmox
│   └── group_vars/
│       ├── all.yml      # Common variables
│       └── vault.yml    # Encrypted secrets (Tailscale key, passwords)
├── playbooks/
│   ├── site.yml         # Master orchestration (bootstrap→opnsense→tailscale→proxmox)
│   ├── bootstrap.yml    # VPS: common + libvirt roles
│   ├── opnsense.yml     # Firewall configuration
│   ├── tailscale.yml    # VPN setup
│   ├── proxmox.yml      # Virtualization platform
│   ├── harden.yml       # Security hardening (disable direct SSH)
│   └── rotate-credentials.yml
├── roles/
│   ├── common/          # SSH hardening, users, base packages
│   ├── libvirt/         # KVM/QEMU installation, storage pools, networks
│   ├── opnsense/        # Firewall rules, interfaces, Tailscale integration
│   ├── proxmox/         # PVE installation, storage, networking
│   └── tailscale/       # Auth, subnet routing, exit node config
└── tests/
    ├── connectivity.yml # Tailscale and network tests
    └── security.yml     # Firewall rule validation

scripts/
├── deploy.sh            # Main orchestration script
├── destroy.sh           # Teardown with confirmation
├── test.sh              # Test runner
└── backup.sh            # Config export
```

### Deployment Phases

1. **Bootstrap** (Phase 2): Install KVM/libvirt on VPS, create storage pool and private network
2. **OPNsense** (Phase 3): Deploy firewall VM capturing public IP, configure rules
3. **Tailscale** (Phase 4): Install Tailscale on OPNsense, advertise 10.0.0.0/24 subnet
4. **Proxmox** (Phase 5): Deploy virtualization VM on private network
5. **Polish** (Phase 6): Hardening, credential rotation, documentation

### Network Topology

- **WAN**: Public IPv4 → OPNsense macvtap interface (exclusive ownership)
- **LAN**: 10.0.0.0/24 via virbr1 bridge
  - OPNsense LAN: 10.0.0.1 (gateway)
  - Proxmox: 10.0.0.10
- **VPN**: Tailscale subnet router advertises 10.0.0.0/24 to home tailnet

## Spec-Kit Integration

This project uses spec-kit for specification-driven development. Specs are in `specs/1-core-infrastructure/`:

- `spec.md` - User stories and requirements
- `plan.md` - Implementation plan with constitution compliance check
- `tasks.md` - Phased task breakdown
- `quickstart.md` - Step-by-step deployment guide
- `contracts/` - Network topology and firewall rule contracts

Use `/speckit.*` slash commands for spec management:
- `/speckit.specify` - Create/update feature specification
- `/speckit.plan` - Generate implementation plan
- `/speckit.tasks` - Generate task breakdown
- `/speckit.implement` - Execute tasks

## Security Notes

- **Ansible Vault**: All secrets in `ansible/inventory/group_vars/vault.yml` must be encrypted
- **No Direct Access**: Proxmox is only accessible via Tailscale (no public ports)
- **Default Deny**: OPNsense firewall blocks all inbound WAN traffic except explicit allows
- **Credential Rotation**: Tailscale auth key (90 days), vault password (180 days), SSH keys (365 days)
- **Post-VPN Hardening**: Run `ansible-playbook playbooks/harden.yml --tags disable-direct-ssh` after Tailscale is verified working

## Testing Strategy

Tests are Ansible playbooks in `ansible/tests/`:

- **security.yml**: Validates firewall rules, port scan, default-deny enforcement
- **connectivity.yml**: Tailscale status, subnet route verification, cross-network ping

Run with `--from-tailnet` flag when testing from home network to enable remote connectivity tests.

## Resource Allocation

| Component | vCPU | RAM | Storage |
|-----------|------|-----|---------|
| OPNsense | 2 | 4GB | 32GB |
| Proxmox | 8 | 48GB | 100GB root + 700GB data |
| **Total** | 10 | 52GB | 832GB |

VPS budget: 12 vCPU, 64GB RAM, 1200GB NVMe
