# cloudenv Project Index

Comprehensive documentation index for the cloudenv infrastructure project.

## Quick Navigation

| Document | Purpose | Location |
|----------|---------|----------|
| [CLAUDE.md](../CLAUDE.md) | AI agent guidance | Project root |
| [Constitution](../.specify/memory/constitution.md) | Core principles | `.specify/memory/` |
| [Scripts API](SCRIPTS-API.md) | Bash script reference | `docs/` |
| [Spec Template](../.specify/templates/spec-template.md) | Feature specification format | `.specify/templates/` |
| [Plan Template](../.specify/templates/plan-template.md) | Technical planning format | `.specify/templates/` |
| [Tasks Template](../.specify/templates/tasks-template.md) | Implementation task format | `.specify/templates/` |

---

## 1. Project Overview

**cloudenv** is a cloud infrastructure project for deploying virtualized environments on remote VPS hosts using libvirt/KVM virtualization.

### Current State
- **Active Development**: Spec-kit workflow integration
- **Archived**: Original OPNsense + Proxmox design (Terraform/Ansible)

### Target Architecture
```
VPS Host (172.93.48.55)
├── virbr1 (10.9.8.0/24) - Private network
├── OPNsense VM (10.9.8.1) - Firewall/Router
│   ├── WAN interface (public)
│   ├── LAN interface (virbr1)
│   └── Tailscale integration
└── Proxmox VM (10.9.8.10) - Workload host
    ├── 8 vCPU, 48GB RAM
    ├── 100GB root disk
    └── 700GB data disk
```

---

## 2. Spec-Kit Workflow System

The project uses a specification-driven development workflow with 9 integrated commands.

### Workflow Phases

```
1. SPECIFY ─────► 2. CLARIFY ─────► 3. PLAN ─────► 4. TASKS ─────► 5. IMPLEMENT
   (What)           (Refine)         (How)         (Work Items)     (Execute)
                                        │
                                        └──► 6. ANALYZE (Validate consistency)
```

### Command Reference

| Command | Phase | Purpose | Artifacts |
|---------|-------|---------|-----------|
| `/speckit.specify` | 1 | Create feature specification | `spec.md` |
| `/speckit.clarify` | 2 | Identify and resolve ambiguities | Updates `spec.md` |
| `/speckit.plan` | 3 | Technical implementation planning | `plan.md`, `research.md`, `data-model.md`, `contracts/` |
| `/speckit.tasks` | 4 | Generate actionable task list | `tasks.md` |
| `/speckit.implement` | 5 | Execute tasks phase by phase | Source code |
| `/speckit.analyze` | - | Read-only consistency check | Validation report |
| `/speckit.checklist` | - | Generate quality checklist | `checklists/*.md` |
| `/speckit.constitution` | - | Manage project principles | `constitution.md` |
| `/speckit.taskstoissues` | - | Export to GitHub issues | GitHub API |

### Feature Branch Convention

Features use numbered branches: `###-feature-name`

```bash
# Examples
001-user-auth
005-fix-payment-bug
012-api-redesign
```

Auto-detection sources:
- Remote branches (`origin/###-*`)
- Local branches
- Specs directories (`specs/###-*`)

---

## 3. Directory Structure

```
cloudenv/
├── .claude/
│   └── commands/                    # Spec-kit slash command definitions
│       ├── speckit.specify.md       # Feature specification workflow
│       ├── speckit.plan.md          # Technical planning workflow
│       ├── speckit.tasks.md         # Task generation workflow
│       ├── speckit.implement.md     # Implementation workflow
│       ├── speckit.analyze.md       # Consistency analysis
│       ├── speckit.clarify.md       # Ambiguity resolution
│       ├── speckit.checklist.md     # Checklist generation
│       ├── speckit.constitution.md  # Constitution management
│       └── speckit.taskstoissues.md # GitHub export
│
├── .specify/
│   ├── memory/
│   │   └── constitution.md          # Non-negotiable project principles
│   │
│   ├── scripts/bash/
│   │   ├── common.sh                # Shared utility functions
│   │   ├── create-new-feature.sh    # Feature branch creation
│   │   ├── setup-plan.sh            # Plan initialization
│   │   ├── check-prerequisites.sh   # Pre-implementation validation
│   │   └── update-agent-context.sh  # AI context file updates
│   │
│   └── templates/
│       ├── spec-template.md         # Feature specification template
│       ├── plan-template.md         # Technical plan template
│       ├── tasks-template.md        # Task list template
│       ├── checklist-template.md    # Quality checklist template
│       └── agent-file-template.md   # AI agent context template
│
├── specs/                           # Feature specifications (per branch)
│   └── ###-feature-name/
│       ├── spec.md                  # WHAT users need
│       ├── plan.md                  # HOW to build it
│       ├── tasks.md                 # Work items
│       ├── research.md              # Technical decisions (optional)
│       ├── data-model.md            # Entity definitions (optional)
│       ├── quickstart.md            # Test scenarios (optional)
│       ├── contracts/               # API specs (optional)
│       └── checklists/              # Quality gates
│
├── shared/                          # Cross-feature resources
│
├── docs/
│   └── INDEX.md                     # This file
│
├── archive/
│   └── original-opnsense-design/
│       ├── terraform/               # Libvirt IaC
│       │   ├── terraform.tfvars     # Configuration values
│       │   └── .terraform/          # Provider cache
│       └── ansible/
│           └── roles/               # Configuration playbooks
│               ├── common/
│               ├── libvirt/
│               ├── opnsense/
│               └── tailscale/
│
└── CLAUDE.md                        # AI agent instructions
```

---

## 4. Key Scripts Reference

### create-new-feature.sh

Creates feature branches with auto-numbered naming.

```bash
# Usage
.specify/scripts/bash/create-new-feature.sh [OPTIONS] "description"

# Options
--json         Output as JSON
--short-name   Custom branch suffix
--number       Explicit feature number

# Example
.specify/scripts/bash/create-new-feature.sh --json "Add user auth" --short-name "user-auth"
# Creates: 006-user-auth (auto-detected next number)
```

### check-prerequisites.sh

Validates prerequisites before implementation.

```bash
# Usage
.specify/scripts/bash/check-prerequisites.sh [OPTIONS]

# Options
--json           Output as JSON
--require-tasks  Fail if tasks.md missing
--include-tasks  Include task details in output
--paths-only     Return only file paths

# Example
.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
```

### update-agent-context.sh

Updates AI agent context files from plan.md data.

```bash
# Usage
.specify/scripts/bash/update-agent-context.sh [AGENT_TYPE]

# Supported agents (17+)
claude, gemini, copilot, cursor, cody, codex, phind,
codeium, tabnine, replit, continue, codegpt, aider,
windsurf, deepsek, codestral

# Example
.specify/scripts/bash/update-agent-context.sh claude
```

### common.sh Functions

| Function | Purpose |
|----------|---------|
| `get_repo_root()` | Find repository root directory |
| `get_current_branch()` | Get current git branch name |
| `get_feature_paths()` | Extract paths for current feature |
| `find_feature_dir_by_prefix()` | Match feature by numeric prefix |
| `get_highest_feature_number()` | Auto-detect next feature number |

---

## 5. Archived Infrastructure Design

### Terraform Configuration

**Providers**:
- `dmacvicar/libvirt` v0.9.1 - KVM virtualization
- `hashicorp/local` v2.6.1 - Local resource management
- `hashicorp/null` v3.2.4 - Null resources
- `hashicorp/template` v2.2.0 - Template rendering

**Infrastructure Specs**:

| Resource | Specification |
|----------|---------------|
| VPS Host | `172.93.48.55` (qemu+ssh) |
| Private Network | `10.9.8.0/24` on `virbr1` |
| OPNsense VM | 2 vCPU, 4GB RAM, 32GB disk |
| OPNsense IP | `10.9.8.1` |
| Proxmox VM | 8 vCPU, 48GB RAM |
| Proxmox Root | 100GB disk |
| Proxmox Data | 700GB disk |
| Proxmox IP | `10.9.8.10` |

### Ansible Roles

| Role | Purpose |
|------|---------|
| `common` | Base system configuration |
| `libvirt` | KVM hypervisor setup |
| `opnsense` | Firewall configuration |
| `tailscale` | VPN overlay network |

### Secrets Management

Secrets injected via environment variables from 1Password:
- `TF_VAR_ssh_private_key`
- `TF_VAR_ssh_public_key`
- `TF_VAR_tailscale_auth_key`

---

## 6. Artifact Guidelines

### spec.md Quality Criteria

- Focus on WHAT and WHY (business perspective)
- User stories with P1/P2/P3 priorities
- Each story independently testable
- Success criteria technology-agnostic
- Maximum 3 `[NEEDS CLARIFICATION]` markers

### plan.md Quality Criteria

- Architecture decisions documented
- Constitution compliance verified
- All clarification markers resolved
- Generates supporting artifacts

### tasks.md Format

```markdown
## Phase N: [Phase Name]

- [ ] T### [P] [US#] Description with exact file path
```

- `T###` - Sequential task number
- `[P]` - Parallelizable (different files, no dependencies)
- `[US#]` - User Story reference from spec.md

### Phase Order

1. **Setup** - Project initialization
2. **Foundational** - Core infrastructure (blocks all stories)
3. **User Stories** - By priority (P1 → P2 → P3)
4. **Polish** - Cross-cutting concerns

---

## 7. Integration Patterns

### Git Workflow Integration

```bash
# Start new feature
.specify/scripts/bash/create-new-feature.sh "Feature description"

# Run specification
/speckit.specify "Feature description"

# Plan and implement
/speckit.plan
/speckit.tasks
/speckit.implement
```

### Non-Git Usage

Set `SPECIFY_FEATURE` environment variable:
```bash
export SPECIFY_FEATURE="003-my-feature"
```

### Agent Context Sync

After planning, sync context to AI agents:
```bash
.specify/scripts/bash/update-agent-context.sh claude
.specify/scripts/bash/update-agent-context.sh cursor
```

Preserves manual additions between `<!-- MANUAL ADDITIONS START -->` markers.

---

## 8. Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Feature not detected | Check branch name format `###-*` |
| Scripts fail | Ensure `SPECIFY_ROOT` or git root accessible |
| Constitution violations | Review `.specify/memory/constitution.md` |
| Missing prerequisites | Run `/speckit.plan` before `/speckit.tasks` |

### Validation Commands

```bash
# Check current feature detection
.specify/scripts/bash/check-prerequisites.sh --paths-only

# Verify consistency
/speckit.analyze
```

---

*Last Updated: December 2025*
