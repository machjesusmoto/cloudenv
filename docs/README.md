# CloudEnv Core Infrastructure

Secure cloud infrastructure deployment for SSDNodes VPS with OPNsense firewall and Proxmox VE virtualization platform.

## Overview

This repository contains Infrastructure as Code (IaC) for deploying:

- **OPNsense Firewall**: Captures public IP, provides NAT, firewall, and Tailscale VPN
- **Proxmox VE**: Virtualization platform on private network, accessible via Tailscale

## Architecture

```
Internet ──► Public IPv4 ──► OPNsense (WAN) ──► Private Network (10.0.0.0/24)
                                    │                      │
                                    │                      └──► Proxmox (10.0.0.10)
                                    │
                                    └──► Tailscale ──► Home Network
```

## Quick Start

See [specs/1-core-infrastructure/quickstart.md](specs/1-core-infrastructure/quickstart.md) for detailed deployment instructions.

### Prerequisites

- SSDNodes VPS with Ubuntu 22.04 LTS
- SSH access to VPS
- Tailscale account with existing tailnet
- Local machine with Terraform and Ansible installed

### Deployment

```bash
# 1. Configure variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Configure secrets
cp ansible/inventory/group_vars/vault.yml.example ansible/inventory/group_vars/vault.yml
ansible-vault encrypt ansible/inventory/group_vars/vault.yml
# Edit vault.yml with your secrets

# 3. Deploy
./scripts/deploy.sh
```

## Project Structure

```
terraform/          # Infrastructure provisioning
├── modules/        # Reusable Terraform modules
│   ├── libvirt-network/
│   ├── opnsense-vm/
│   └── proxmox-vm/
├── main.tf
├── variables.tf
└── outputs.tf

ansible/            # Configuration management
├── inventory/      # Host definitions
├── playbooks/      # Orchestration playbooks
├── roles/          # Reusable roles
│   ├── common/
│   ├── libvirt/
│   ├── opnsense/
│   ├── proxmox/
│   └── tailscale/
└── tests/          # Validation tests

scripts/            # Automation scripts
├── deploy.sh
├── destroy.sh
└── test.sh

docs/               # Documentation
specs/              # Feature specifications
```

## Security

This infrastructure follows security-first design principles:

- **Network Isolation**: OPNsense exclusively controls public IP
- **Default Deny**: All inbound WAN traffic blocked except explicit allows
- **Encrypted Transit**: Tailscale provides mesh VPN connectivity
- **No Port Forwarding**: All access via Tailscale (no public exposure)
- **IaC Only**: No manual configuration changes permitted

## Testing

```bash
# Run all tests
./scripts/test.sh

# Run specific test suites
ansible-playbook ansible/tests/connectivity.yml
ansible-playbook ansible/tests/security.yml
```

## Documentation

- [Specification](specs/1-core-infrastructure/spec.md)
- [Implementation Plan](specs/1-core-infrastructure/plan.md)
- [Network Topology](specs/1-core-infrastructure/contracts/network-topology.md)
- [Firewall Rules](specs/1-core-infrastructure/contracts/firewall-rules.md)
- [Quick Start Guide](specs/1-core-infrastructure/quickstart.md)

## License

Private repository - All rights reserved.
