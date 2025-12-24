# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloudEnv is a multi-feature infrastructure project for deploying secure cloud services on SSDNodes VPS. The project is organized by feature, with each feature having its own specification and implementation.

## Project Philosophy: Public Portfolio

**This repository is a living DevOps portfolio** - treated as a production environment and maintained in public view.

### Implications

1. **Security-First**: All commits audited for secrets, credentials, and sensitive data before pushing
2. **No Hardcoded IPs**: Public IPs use placeholders (`<VPS_PUBLIC_IP>`, `<VPS_GATEWAY>`)
3. **Production Standards**: Code quality, documentation, and practices reflect production-grade work
4. **Transparency**: Demonstrates real-world infrastructure skills and decision-making

### Sensitive Data Handling

| Data Type | Policy |
|-----------|--------|
| Public VPS IPs | Use `<VPS_PUBLIC_IP>` placeholder |
| API Keys/Secrets | Never commit; use 1Password refs (`op://...`) or env vars |
| Tailscale IPs (100.x.x.x) | Acceptable (ephemeral, non-routable externally) |
| Home LAN subnets (RFC1918) | Acceptable (non-routable) |

### Pre-Push Security Checklist

```bash
# Check for secrets
git diff --cached | grep -iE "password|secret|token|api.?key|tskey-api"

# Check for public IPs (adjust pattern for your IP range)
git diff --cached | grep -E "\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b" | grep -v "10\.\|192\.168\.\|100\.\|127\."
```

### Current Architecture (Feature 1: Core Infrastructure)

```
Internet ──► SSDNodes Provider Firewall ──► Proxmox VE Host (<VPS_PUBLIC_IP>)
                                                    │
                                                    ├── vmbr0 (public: <VPS_PUBLIC_IP>/24)
                                                    ├── vmbr1 (private: 10.0.0.1/24)
                                                    ├── Tailscale (100.84.93.46)
                                                    │       └── advertises 10.0.0.0/24
                                                    └── Future VMs on vmbr1

Home Network ──► Tailscale ──► pve-vps (100.84.93.46) ──► 10.0.0.0/24
```

**Deployed Components**:
- **Proxmox VE 9.1.2**: Virtualization platform directly on Debian 13 host
- **Tailscale 1.92.3**: Subnet router on host, advertising 10.0.0.0/24
- **SSDNodes Provider Firewall**: Edge protection (default deny, SSH from admin IP only)

## Directory Structure

```
cloudenv/
├── features/                          # Feature-based organization
│   ├── 1-core-infrastructure/         # ✅ Complete - Proxmox + Tailscale
│   │   ├── spec.md                    # Requirements and user stories
│   │   ├── plan.md                    # Implementation plan
│   │   ├── tasks.md                   # Task breakdown and status
│   │   ├── quickstart.md              # Deployment guide
│   │   └── contracts/                 # Network topology, firewall rules
│   └── 2-xxx/                         # Future features
│
├── shared/                            # Shared infrastructure code
│   ├── terraform/                     # Reusable Terraform modules
│   └── ansible/                       # Reusable Ansible roles
│
├── archive/                           # Archived/unused designs
│   └── original-opnsense-design/      # Initial OPNsense-based design (unused)
│
├── scripts/                           # Project-wide scripts
├── docs/                              # Project documentation
└── CLAUDE.md                          # This file
```

## Constitution Principles

This project follows a formal constitution (`.specify/memory/constitution.md`) with five core principles:

1. **Security-First Design**: Network isolation, encrypted transit, least privilege
2. **Reliability Through Simplicity**: Minimal components, documented state, graceful failure
3. **Infrastructure as Code**: All config declarative, version controlled, reproducible
4. **Test Coverage Discipline**: Validation before apply, contract tests, integration tests
5. **Extensibility by Design**: Modular structure, standard interfaces, parameterized configuration

## Feature Development Workflow

### Creating a New Feature

1. Create feature directory:
   ```bash
   mkdir -p features/N-feature-name
   ```

2. Use spec-kit commands to initialize:
   ```
   /speckit.specify    # Create feature specification
   /speckit.plan       # Generate implementation plan
   /speckit.tasks      # Generate task breakdown
   /speckit.implement  # Execute tasks
   ```

3. Each feature should contain:
   - `spec.md` - User stories and requirements
   - `plan.md` - Implementation plan with constitution compliance
   - `tasks.md` - Phased task breakdown
   - `quickstart.md` - Deployment/usage guide
   - `contracts/` - Interface contracts (optional)

### Feature Naming Convention

Features are numbered sequentially: `N-descriptive-name`
- `1-core-infrastructure` - Base VPS setup
- `2-kubernetes-cluster` - K8s deployment (example)
- `3-monitoring-stack` - Observability (example)

## Access Methods

| Method | URL/Command | Notes |
|--------|-------------|-------|
| Proxmox Web UI | https://100.84.93.46:8006 | Via Tailscale |
| SSH via Tailscale | `ssh root@100.84.93.46` | Recommended |
| SSH via Public IP | `ssh root@<VPS_PUBLIC_IP>` | Requires provider firewall allow |

## Network Configuration

| Interface | IP Address | Purpose |
|-----------|------------|---------|
| vmbr0 | <VPS_PUBLIC_IP>/24 | Public bridge (WAN) |
| vmbr1 | 10.0.0.1/24 | Private bridge (LAN for VMs) |
| tailscale0 | 100.84.93.46 | Tailscale VPN |

### VM Network Configuration

VMs should be created on vmbr1:
- **IP Range**: 10.0.0.2 - 10.0.0.254
- **Gateway**: 10.0.0.1
- **DNS**: 10.0.0.1 or external (1.1.1.1)
- **Static IPs**: 10.0.0.2 - 10.0.0.49
- **DHCP Pool**: 10.0.0.100 - 10.0.0.199 (future)

## Resource Budget

| Resource | Total | Used | Available |
|----------|-------|------|-----------|
| vCPU | 12 | ~2 (host overhead) | ~10 |
| RAM | 64GB | ~4GB (host) | ~60GB |
| Storage | 1200GB | ~50GB (OS) | ~1150GB |

## Security Notes

- SSH password authentication is disabled
- Provider firewall blocks all except SSH from admin IP
- Proxmox UI only accessible via Tailscale (no public exposure)
- VMs isolated on private network with NAT egress
- Tailscale provides encrypted overlay for all management traffic

## Maintenance Commands

```bash
# SSH to VPS
ssh root@100.84.93.46

# Check Proxmox version
pveversion

# Check Tailscale status
tailscale status

# Update system
apt-get update && apt-get dist-upgrade
```
