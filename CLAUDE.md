# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CloudEnv is a multi-feature infrastructure project for deploying secure cloud services on SSDNodes VPS. The project uses **spec-kit** workflow for specification-driven development with Claude Code integration.

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

## Spec-Kit Workflow

This project follows a structured specification → planning → implementation workflow.

### Core Workflow Commands

```bash
# 1. Create a new feature specification
/speckit.specify "description of the feature"

# 2. Create technical implementation plan
/speckit.plan

# 3. Generate actionable task list
/speckit.tasks

# 4. Analyze consistency across artifacts (read-only)
/speckit.analyze

# 5. Execute implementation
/speckit.implement
```

### Supporting Commands

```bash
/speckit.clarify       # Identify underspecified areas and ask clarification questions
/speckit.checklist     # Generate custom checklist for the current feature
/speckit.constitution  # Create/update project constitution
/speckit.taskstoissues # Convert tasks to GitHub issues
```

### Feature Branch Convention

Features use numbered branches: `###-feature-name` (e.g., `001-k8s-talos-cluster`)

The system auto-detects the highest number from:
- Remote branches
- Local branches
- Specs directories (`specs/###-*`)

## Directory Structure

```
cloudenv/
├── .claude/commands/           # Spec-kit slash commands
├── .specify/
│   ├── memory/                 # Constitution and project memory
│   ├── scripts/bash/           # Workflow automation scripts
│   └── templates/              # spec.md, plan.md, tasks.md templates
├── specs/                      # Feature specifications (per feature branch)
│   └── ###-feature-name/
│       ├── spec.md             # Feature specification (WHAT, not HOW)
│       ├── plan.md             # Technical implementation plan
│       ├── tasks.md            # Actionable task list
│       ├── research.md         # Technical decisions (optional)
│       ├── data-model.md       # Entity definitions (optional)
│       ├── quickstart.md       # Test scenarios (optional)
│       ├── contracts/          # API specifications (optional)
│       └── checklists/         # Quality validation checklists
├── features/                   # Legacy feature directory (archived)
│   ├── 1-core-infrastructure/  # ✅ Complete - Proxmox + Tailscale
│   └── 2-tailscale-acl-configuration/ # ✅ Complete
├── shared/                     # Shared resources across features
├── archive/                    # Archived designs
│   └── original-opnsense-design/
├── docs/                       # Project documentation
└── CLAUDE.md                   # This file
```

## Key Scripts

```bash
# Create new feature branch and initialize spec
.specify/scripts/bash/create-new-feature.sh --json "feature description" --short-name "branch-suffix"

# Setup implementation plan
.specify/scripts/bash/setup-plan.sh --json

# Check prerequisites for implementation
.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks

# Update agent context after planning
.specify/scripts/bash/update-agent-context.sh claude
```

## Current Architecture

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

## Constitution Principles

This project follows a formal constitution (`.specify/memory/constitution.md`) with six core principles:

1. **Infrastructure as Code**: All config declarative, version controlled, reproducible
2. **Public Repository Security**: No secrets, no identifying IPs, audit-ready commits
3. **Immutable Infrastructure**: API-driven systems (Talos), GitOps, declarative updates
4. **Defense in Depth**: Network segmentation, Tailscale access, Pod Security Standards
5. **Observable Systems**: Prometheus endpoints, structured logging, health checks
6. **Resource Efficiency**: Right-sized allocations, memory ballooning, reclaim unused

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

## Access Methods

| Method | URL/Command | Notes |
|--------|-------------|-------|
| Proxmox Web UI | https://100.84.93.46:8006 | Via Tailscale |
| SSH via Tailscale | `ssh root@100.84.93.46` | Recommended |
| SSH via Public IP | `ssh root@<VPS_PUBLIC_IP>` | Requires provider firewall allow |

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
