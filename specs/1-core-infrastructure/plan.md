# Implementation Plan: Core Infrastructure Setup

**Branch**: `1-core-infrastructure` | **Date**: 2025-12-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/1-core-infrastructure/spec.md`

## Summary

Deploy secure cloud infrastructure to SSDNodes VPS consisting of OPNsense firewall (capturing public IP) and Proxmox VE (private network only), connected to existing home Tailscale tailnet for seamless remote management. Uses KVM/QEMU with libvirt as the hypervisor layer, automated via Terraform for infrastructure provisioning and Ansible for configuration management.

## Technical Context

**Language/Version**: Go 1.21+ (Terraform), Python 3.11+ (Ansible)
**Primary Dependencies**: Terraform, Ansible, libvirt, cloud-init
**Storage**: Local NVMe (1200GB) managed by libvirt storage pools
**Testing**: Ansible molecule, terraform validate, connectivity tests (bash/Python)
**Target Platform**: Linux server (Ubuntu 22.04 LTS or Debian 12 on SSDNodes VPS)
**Project Type**: Infrastructure (IaC monorepo)
**Performance Goals**: <100ms RTT via Tailscale, 4-hour deployment time
**Constraints**: Single public IPv4, 12 vCPU / 64GB RAM / 1200GB NVMe budget
**Scale/Scope**: 2 VMs (OPNsense, Proxmox), 1 tailnet integration, 1 private subnet

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Security-First Design ✅

| Requirement | Compliance |
|-------------|------------|
| Network Isolation | ✅ OPNsense exclusively controls public IP; Proxmox on private subnet only |
| Encrypted Transit | ✅ Tailscale provides encrypted mesh connectivity |
| Least Privilege | ✅ Ansible uses dedicated deploy user; services run non-root where possible |
| Credential Management | ✅ Secrets via Ansible Vault; Tailscale auth keys rotated |
| Audit Trail | ✅ OPNsense logging enabled; deployment logs captured |

### II. Reliability Through Simplicity ✅

| Requirement | Compliance |
|-------------|------------|
| Minimal Components | ✅ Only 2 VMs: OPNsense (required for security) + Proxmox (required for goal) |
| Documented State | ✅ All config in Terraform/Ansible, version controlled |
| Graceful Failure | ✅ VMs independent; OPNsense failure doesn't cascade to Proxmox data |
| Recovery Path | ✅ Terraform destroy/apply recreates; Ansible idempotent |
| Idempotent Operations | ✅ Terraform + Ansible are idempotent by design |

### III. Infrastructure as Code ✅

| Requirement | Compliance |
|-------------|------------|
| Declarative Configuration | ✅ Terraform for VMs, Ansible for OS/service config |
| Version Control | ✅ All artifacts in Git |
| Reproducibility | ✅ Same inputs → same infrastructure |
| No Snowflakes | ✅ Manual changes prohibited; all through code |

### IV. Test Coverage Discipline ✅

| Requirement | Compliance |
|-------------|------------|
| Validation Before Apply | ✅ `terraform validate`, `ansible-lint`, dry-run modes |
| Contract Tests | ✅ Network connectivity assertions in test playbook |
| Integration Tests | ✅ End-to-end Tailscale connectivity test |
| Coverage Target | ✅ Critical paths: firewall rules, VPN, VM access |

### V. Extensibility by Design ✅

| Requirement | Compliance |
|-------------|------------|
| Modular Structure | ✅ Terraform modules per component; Ansible roles separable |
| Standard Interfaces | ✅ SSH, HTTPS, Tailscale (standard protocols) |
| Parameterization | ✅ Variables for IPs, subnets, resources in tfvars/group_vars |
| Documentation | ✅ quickstart.md, inline comments, README per module |

**Gate Status**: ✅ PASS - All principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/1-core-infrastructure/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (network contracts)
│   ├── network-topology.md
│   └── firewall-rules.md
├── checklists/
│   └── requirements.md  # Specification checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
terraform/
├── main.tf              # Root module orchestration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Provider versions
├── terraform.tfvars.example
└── modules/
    ├── libvirt-network/ # Private network definition
    ├── opnsense-vm/     # OPNsense VM resource
    └── proxmox-vm/      # Proxmox VM resource

ansible/
├── ansible.cfg          # Ansible configuration
├── inventory/
│   ├── hosts.yml        # Dynamic/static inventory
│   └── group_vars/
│       ├── all.yml      # Common variables
│       └── vault.yml    # Encrypted secrets
├── playbooks/
│   ├── site.yml         # Master playbook
│   ├── bootstrap.yml    # Initial VPS setup
│   ├── opnsense.yml     # OPNsense configuration
│   ├── proxmox.yml      # Proxmox configuration
│   └── tailscale.yml    # Tailscale integration
├── roles/
│   ├── common/          # Base system hardening
│   ├── libvirt/         # KVM/libvirt setup
│   ├── opnsense/        # OPNsense VM deployment
│   ├── proxmox/         # Proxmox VM deployment
│   └── tailscale/       # Tailscale client/subnet routing
└── tests/
    ├── connectivity.yml # Network connectivity tests
    └── security.yml     # Security validation tests

scripts/
├── deploy.sh            # Full deployment orchestration
├── destroy.sh           # Teardown script
└── test.sh              # Run all tests

docs/
└── README.md            # Project documentation
```

**Structure Decision**: Infrastructure monorepo with Terraform for VM provisioning and Ansible for configuration. Modular design allows independent updates to OPNsense or Proxmox components.

## Complexity Tracking

> No violations - all complexity justified by constitution requirements.

| Component | Justification |
|-----------|---------------|
| Terraform + Ansible | Constitution III requires IaC; both tools serve distinct purposes (provisioning vs config) |
| 2 VMs | Minimum viable: firewall (Constitution I) + hypervisor (feature goal) |
| Tailscale | Selected per spec FR-004; simpler than IPsec for existing tailnet |
