# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**cloudenv** is a cloud infrastructure project for deploying virtualized environments on a remote VPS using libvirt/KVM. The original design (now archived) focused on:
- OPNsense firewall VM for network isolation and routing
- Proxmox VE nested VM for workload hosting
- Tailscale overlay network for secure remote access
- Terraform + Ansible for IaC provisioning

The project uses **spec-kit** workflow for specification-driven development with Claude Code integration.

## Spec-Kit Workflow

This project follows a structured specification → planning → implementation workflow. The primary commands are:

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
/speckit.clarify    # Identify underspecified areas and ask clarification questions
/speckit.checklist  # Generate custom checklist for the current feature
/speckit.constitution  # Create/update project constitution
/speckit.taskstoissues # Convert tasks to GitHub issues
```

### Feature Branch Convention

Features use numbered branches: `###-feature-name` (e.g., `001-user-auth`, `005-fix-payment-bug`)

The system auto-detects the highest number from:
- Remote branches
- Local branches
- Specs directories (`specs/###-*`)

## Project Structure

```
cloudenv/
├── .claude/commands/      # Spec-kit slash commands
├── .specify/
│   ├── memory/            # Constitution and project memory
│   ├── scripts/bash/      # Workflow automation scripts
│   └── templates/         # spec.md, plan.md, tasks.md templates
├── specs/                 # Feature specifications (created per feature branch)
│   └── ###-feature-name/
│       ├── spec.md        # Feature specification (WHAT, not HOW)
│       ├── plan.md        # Technical implementation plan
│       ├── tasks.md       # Actionable task list
│       ├── research.md    # Technical decisions (optional)
│       ├── data-model.md  # Entity definitions (optional)
│       ├── quickstart.md  # Test scenarios (optional)
│       ├── contracts/     # API specifications (optional)
│       └── checklists/    # Quality validation checklists
├── shared/                # Shared resources across features
└── archive/               # Archived designs
    └── original-opnsense-design/
        ├── terraform/     # Libvirt provider configs
        └── ansible/       # Configuration playbooks
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

## Spec-Kit Artifact Guidelines

### spec.md (Specification)
- Focus on **WHAT** users need and **WHY**
- Written for business stakeholders, not developers
- User stories with priorities (P1, P2, P3)
- Each story must be independently testable
- Use `[NEEDS CLARIFICATION: ...]` markers sparingly (max 3)
- Success criteria must be measurable and technology-agnostic

### plan.md (Technical Plan)
- Architecture and tech stack decisions
- Constitution compliance checks
- Research phase resolves all `NEEDS CLARIFICATION` markers
- Generates `data-model.md`, `contracts/`, `quickstart.md`

### tasks.md (Task List)
- Strict checklist format: `- [ ] T### [P] [US#] Description with file path`
- `[P]` = parallelizable task
- `[US#]` = maps to User Story from spec
- Phases: Setup → Foundational → User Stories (by priority) → Polish

## Archived Infrastructure Design

The `archive/original-opnsense-design/` contains:

### Terraform (libvirt provider)
- **VPS Host**: `172.93.48.55` via `qemu+ssh://`
- **Private Network**: `10.9.8.0/24` (virbr1)
- **OPNsense VM**: 2 vCPU, 4GB RAM, 32GB disk at `10.9.8.1`
- **Proxmox VM**: 8 vCPU, 48GB RAM, 100GB root + 700GB data at `10.9.8.10`
- **Modules**: `opnsense-vm`, `proxmox-vm`, `libvirt-network`

### Ansible Roles
- `common`: Base configuration
- `libvirt`: Hypervisor setup
- `opnsense`: Firewall configuration
- `tailscale`: VPN overlay

### Secrets Management
SSH keys and Tailscale auth keys fetched from 1Password via `TF_VAR_*` environment variables.

## Constitution

The project constitution (`.specify/memory/constitution.md`) defines non-negotiable principles. Constitution violations are automatically flagged as CRITICAL during `/speckit.analyze`. The constitution template covers:
- Core development principles
- Quality standards
- Governance rules

## Integration Notes

- Scripts support both git and non-git repositories
- `SPECIFY_FEATURE` environment variable can override branch detection
- All paths in spec-kit commands must be absolute
- Feature directories found by numeric prefix matching (e.g., branch `004-fix-bug` matches `specs/004-*`)

## Documentation

For comprehensive project documentation, see:
- **[Project Index](docs/INDEX.md)** - Full documentation index with navigation
- **[Constitution](.specify/memory/constitution.md)** - Core project principles
