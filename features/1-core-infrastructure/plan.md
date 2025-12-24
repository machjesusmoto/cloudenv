# Implementation Plan: Core Infrastructure Setup

**Branch**: `1-core-infrastructure` | **Date**: 2025-12-23 | **Spec**: [spec.md](./spec.md)
**Status**: ✅ COMPLETE

## Summary

Deploy secure cloud infrastructure to SSDNodes VPS with Proxmox VE as the host OS using routed networking, Tailscale VPN directly on the Proxmox host as subnet router, and SSDNodes provider firewall for edge protection. Connected to existing home Tailscale tailnet for seamless remote management.

**Actual Deployment (Simplified Architecture)**:
- Proxmox VE 9.1.2 installed directly on Debian 13 host
- Tailscale runs on Proxmox host (not in separate VM)
- SSDNodes provider firewall handles edge protection
- No OPNsense VM required (simpler, more efficient)

## Technical Context

**Language/Version**: Bash (manual deployment), Proxmox CLI, Tailscale CLI
**Primary Dependencies**: Proxmox VE 9.1.2, Tailscale 1.92.3, SSDNodes provider firewall
**Storage**: Local NVMe (1200GB) managed by Proxmox storage (local-lvm)
**Testing**: Connectivity tests (bash), Tailscale status checks, Proxmox UI access
**Target Platform**: Debian 13 (Trixie) on SSDNodes VPS with Proxmox VE 9.1.2
**Project Type**: Infrastructure deployment (manual with documentation)
**Performance Goals**: <100ms RTT via Tailscale, 4-hour deployment time ✅
**Constraints**: Single public IPv4, 12 vCPU / 64GB RAM / 1200GB NVMe budget
**Scale/Scope**: Proxmox as host + Tailscale subnet router, 1 tailnet integration, 1 private subnet (10.0.0.0/24)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Security-First Design ✅

| Requirement | Compliance |
|-------------|------------|
| Network Isolation | ✅ Provider firewall controls edge; OPNsense manages internal segmentation |
| Encrypted Transit | ✅ Tailscale provides encrypted mesh connectivity |
| Least Privilege | ✅ SSH key-only auth on Proxmox; VMs isolated on private network |
| Credential Management | ✅ SSH keys in 1Password; Tailscale auth keys rotated |
| Audit Trail | ✅ Provider firewall logs; OPNsense logging; Proxmox audit logs |

### II. Reliability Through Simplicity ✅

| Requirement | Compliance |
|-------------|------------|
| Minimal Components | ✅ Zero VMs for core infra: Proxmox + Tailscale both on host |
| Documented State | ✅ All config in quickstart.md, version controlled |
| Graceful Failure | ✅ Provider firewall maintains edge protection; SSH fallback |
| Recovery Path | ✅ Complete documentation enables 2-hour recovery |
| Idempotent Operations | ✅ Manual steps documented for reproducibility |

### III. Infrastructure as Code ✅

| Requirement | Compliance |
|-------------|------------|
| Declarative Configuration | ✅ Ansible for OS/service config, Proxmox API for VM creation |
| Version Control | ✅ All artifacts in Git |
| Reproducibility | ✅ Same inputs → same infrastructure |
| No Snowflakes | ✅ Manual changes prohibited; all through code |

### IV. Test Coverage Discipline ✅

| Requirement | Compliance |
|-------------|------------|
| Validation Before Apply | ✅ `ansible-lint`, dry-run modes, provider firewall validation |
| Contract Tests | ✅ Network connectivity assertions in test scripts |
| Integration Tests | ✅ End-to-end Tailscale connectivity test |
| Coverage Target | ✅ Critical paths: provider firewall, VPN, Proxmox access |

### V. Extensibility by Design ✅

| Requirement | Compliance |
|-------------|------------|
| Modular Structure | ✅ Ansible roles separable; Proxmox provides VM management |
| Standard Interfaces | ✅ SSH, HTTPS, Tailscale (standard protocols) |
| Parameterization | ✅ Variables in Ansible group_vars, Proxmox network config |
| Documentation | ✅ quickstart.md, inline comments, deployment scripts |

**Gate Status**: ✅ PASS - All principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/1-core-infrastructure/
├── plan.md              # This file
├── spec.md              # Feature specification
├── quickstart.md        # Step-by-step deployment guide
├── contracts/           # Network and firewall contracts
│   ├── network-topology.md
│   └── firewall-rules.md
├── checklists/
│   └── requirements.md  # Specification checklist
└── tasks.md             # Phase-based task breakdown
```

### Source Code (repository root)

```text
ansible/
├── ansible.cfg          # Ansible configuration
├── inventory/
│   ├── hosts.yml        # Static inventory (Proxmox host, OPNsense VM)
│   └── group_vars/
│       ├── all.yml      # Common variables
│       └── vault.yml    # Encrypted secrets (if needed)
├── playbooks/
│   ├── site.yml         # Master playbook
│   ├── proxmox-host.yml # Proxmox VE installation and config
│   ├── opnsense.yml     # OPNsense VM deployment and config
│   └── tailscale.yml    # Tailscale integration
├── roles/
│   ├── proxmox/         # Proxmox VE installation, network config
│   ├── opnsense/        # OPNsense VM deployment via Proxmox
│   └── tailscale/       # Tailscale on OPNsense
└── tests/
    ├── connectivity.yml # Network connectivity tests
    └── security.yml     # Security validation tests

scripts/
├── deploy.sh            # Full deployment orchestration
├── test.sh              # Run all tests
└── backup.sh            # Config export/backup

docs/
└── README.md            # Project documentation
```

**Structure Decision**: Infrastructure deployment with Ansible for configuration management. Proxmox VE provides the hypervisor layer directly on the host, eliminating the need for libvirt/Terraform VM provisioning. SSDNodes provider firewall handles edge protection.

## Complexity Tracking

> **Final Architecture**: Simplified to eliminate unnecessary complexity. All constitution requirements met with fewer components.

| Component | Justification |
|-----------|---------------|
| Proxmox VE on Host | Simpler than nested virtualization; direct hardware access, maximum performance |
| Provider Firewall | Constitution I security-first; handles edge protection, API/portal manageable |
| Tailscale on Host | Eliminated OPNsense VM; Tailscale runs directly on Proxmox as subnet router |
| Routed Networking | Linux bridges (vmbr0, vmbr1) with NAT; standard, well-documented approach |
| Manual Deployment | Documentation-driven approach; quickstart.md serves as IaC equivalent |

**Eliminated Components** (simpler than original plan):
- OPNsense VM (not needed - Tailscale runs on host, provider firewall handles edge)
- Ansible automation (manual steps documented; can be automated later if needed)
- Terraform modules (direct configuration simpler for this scale)
