# Spec-Kit Scripts API Reference

Comprehensive API documentation for the `.specify/scripts/bash/` utility scripts.

---

## Table of Contents

1. [common.sh](#commonsh) - Shared utility functions
2. [create-new-feature.sh](#create-new-featuresh) - Feature branch creation
3. [setup-plan.sh](#setup-plansh) - Plan initialization
4. [check-prerequisites.sh](#check-prerequisitessh) - Pre-implementation validation
5. [update-agent-context.sh](#update-agent-contextsh) - AI agent context management

---

## common.sh

**Purpose**: Shared utility functions sourced by all spec-kit scripts.

**Location**: `.specify/scripts/bash/common.sh`

### Functions

#### `get_repo_root()`

Finds the repository root directory by traversing up from current location.

```bash
# Returns: Absolute path to repository root
# Exit: 1 if not in a git repository

REPO_ROOT=$(get_repo_root)
```

**Algorithm**: Walks up directory tree looking for `.git` directory.

---

#### `get_current_branch()`

Gets the current git branch name.

```bash
# Returns: Branch name string
# Exit: 1 if not in git repository or detached HEAD

BRANCH=$(get_current_branch)
```

**Note**: Returns empty string if `SPECIFY_FEATURE` environment variable is set.

---

#### `get_feature_paths()`

Outputs shell variable assignments for all feature-related paths.

```bash
# Usage: Must be eval'd to set variables
eval $(get_feature_paths)

# Variables set:
#   REPO_ROOT       - Repository root path
#   CURRENT_BRANCH  - Current branch name (or SPECIFY_FEATURE)
#   HAS_GIT         - "true" or "false"
#   FEATURE_DIR     - specs/###-feature-name/
#   FEATURE_SPEC    - specs/###-feature-name/spec.md
#   IMPL_PLAN       - specs/###-feature-name/plan.md
#   TASKS           - specs/###-feature-name/tasks.md
#   RESEARCH        - specs/###-feature-name/research.md
#   DATA_MODEL      - specs/###-feature-name/data-model.md
#   CONTRACTS_DIR   - specs/###-feature-name/contracts/
#   QUICKSTART      - specs/###-feature-name/quickstart.md
```

**Environment**: Respects `SPECIFY_FEATURE` and `SPECIFY_ROOT` variables.

---

#### `find_feature_dir_by_prefix(prefix)`

Locates feature directory matching a numeric prefix.

```bash
# Parameters:
#   prefix - Numeric prefix (e.g., "001", "12")
#
# Returns: Directory name (e.g., "001-user-auth")
# Exit: 1 if not found

DIR=$(find_feature_dir_by_prefix "001")
```

**Search Order**:
1. `specs/###-*` directories
2. Remote branches (`origin/###-*`)
3. Local branches (`###-*`)

---

#### `get_highest_feature_number()`

Determines the highest existing feature number for auto-increment.

```bash
# Returns: Integer (highest feature number found, or 0)

HIGHEST=$(get_highest_feature_number)
NEXT=$((HIGHEST + 1))
```

**Sources Checked**:
- Remote branches
- Local branches
- Specs directories

---

#### `check_feature_branch(branch, has_git)`

Validates that current branch follows feature naming convention.

```bash
# Parameters:
#   branch   - Branch name to validate
#   has_git  - "true" or "false"
#
# Exit: 0 if valid, 1 if invalid

check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1
```

**Valid Patterns**: `###-*` where `###` is 1-4 digits.

---

#### `check_file(path, label)`

Outputs file existence status for text mode display.

```bash
# Parameters:
#   path  - File path to check
#   label - Display label
#
# Output: "✓ label" or "✗ label"

check_file "$RESEARCH" "research.md"
```

---

#### `check_dir(path, label)`

Outputs directory existence status for text mode display.

```bash
# Parameters:
#   path  - Directory path to check
#   label - Display label
#
# Output: "✓ label" or "✗ label"

check_dir "$CONTRACTS_DIR" "contracts/"
```

---

## create-new-feature.sh

**Purpose**: Creates feature branches with auto-numbered naming convention.

**Location**: `.specify/scripts/bash/create-new-feature.sh`

### Usage

```bash
.specify/scripts/bash/create-new-feature.sh [OPTIONS] "description"
```

### Options

| Option | Description |
|--------|-------------|
| `--json` | Output results in JSON format |
| `--short-name NAME` | Custom branch suffix (default: auto-generated from description) |
| `--number NUM` | Explicit feature number (default: auto-increment) |
| `--help`, `-h` | Show help message |

### Examples

```bash
# Auto-numbered with generated name
.specify/scripts/bash/create-new-feature.sh "Add user authentication"
# Creates: 006-add-user-authentication

# Custom short name
.specify/scripts/bash/create-new-feature.sh --short-name "user-auth" "Add user authentication"
# Creates: 006-user-auth

# Explicit number
.specify/scripts/bash/create-new-feature.sh --number 100 "Major refactor"
# Creates: 100-major-refactor

# JSON output for scripting
.specify/scripts/bash/create-new-feature.sh --json "New feature"
# Output: {"branch":"007-new-feature","number":"007","created":true}
```

### Output Formats

**Text Mode** (default):
```
Created feature branch: 006-user-auth
Feature number: 006
Branch created: true
```

**JSON Mode** (`--json`):
```json
{
  "branch": "006-user-auth",
  "number": "006",
  "created": true
}
```

### Internal Functions

| Function | Purpose |
|----------|---------|
| `find_repo_root()` | Locate git repository root |
| `get_highest_from_specs()` | Find highest number in specs/ |
| `get_highest_from_branches()` | Find highest number in branches |
| `check_existing_branches()` | Validate branch doesn't exist |
| `clean_branch_name()` | Sanitize description for branch name |
| `generate_branch_name()` | Create full branch name from parts |

### Constraints

- **Branch name limit**: 244 bytes (GitHub maximum)
- **Number format**: Zero-padded to 3 digits minimum
- **Character sanitization**: Removes special chars, converts spaces to hyphens

---

## setup-plan.sh

**Purpose**: Initializes plan.md from template for current feature branch.

**Location**: `.specify/scripts/bash/setup-plan.sh`

### Usage

```bash
.specify/scripts/bash/setup-plan.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--json` | Output results in JSON format |
| `--help`, `-h` | Show help message |

### Examples

```bash
# Standard initialization
.specify/scripts/bash/setup-plan.sh
# Copies template to specs/###-feature/plan.md

# JSON output
.specify/scripts/bash/setup-plan.sh --json
```

### Output Formats

**Text Mode**:
```
Copied plan template to /path/to/specs/001-feature/plan.md
FEATURE_SPEC: /path/to/specs/001-feature/spec.md
IMPL_PLAN: /path/to/specs/001-feature/plan.md
SPECS_DIR: /path/to/specs/001-feature
BRANCH: 001-feature
HAS_GIT: true
```

**JSON Mode**:
```json
{
  "FEATURE_SPEC": "/path/to/specs/001-feature/spec.md",
  "IMPL_PLAN": "/path/to/specs/001-feature/plan.md",
  "SPECS_DIR": "/path/to/specs/001-feature",
  "BRANCH": "001-feature",
  "HAS_GIT": "true"
}
```

### Behavior

1. Validates current branch follows `###-*` pattern
2. Creates feature directory if missing
3. Copies `.specify/templates/plan-template.md` to `specs/###-feature/plan.md`
4. Creates empty plan.md if template missing

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Not on feature branch or validation failed |

---

## check-prerequisites.sh

**Purpose**: Validates prerequisites before implementation phase.

**Location**: `.specify/scripts/bash/check-prerequisites.sh`

### Usage

```bash
.specify/scripts/bash/check-prerequisites.sh [OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--json` | Output in JSON format |
| `--require-tasks` | Fail if tasks.md missing |
| `--include-tasks` | Include tasks.md in available docs |
| `--paths-only` | Output path variables only (no validation) |
| `--help`, `-h` | Show help message |

### Examples

```bash
# Basic prerequisite check (plan.md required)
.specify/scripts/bash/check-prerequisites.sh

# Implementation prerequisites (plan.md + tasks.md required)
.specify/scripts/bash/check-prerequisites.sh --require-tasks --include-tasks

# Get feature paths for scripting
.specify/scripts/bash/check-prerequisites.sh --paths-only --json

# Full JSON output with task details
.specify/scripts/bash/check-prerequisites.sh --json --include-tasks
```

### Output Formats

**Text Mode**:
```
FEATURE_DIR:/path/to/specs/001-feature
AVAILABLE_DOCS:
✓ research.md
✗ data-model.md
✓ contracts/
✗ quickstart.md
```

**JSON Mode**:
```json
{
  "FEATURE_DIR": "/path/to/specs/001-feature",
  "AVAILABLE_DOCS": ["research.md", "contracts/"]
}
```

**Paths Only (JSON)**:
```json
{
  "REPO_ROOT": "/path/to/repo",
  "BRANCH": "001-feature",
  "FEATURE_DIR": "/path/to/specs/001-feature",
  "FEATURE_SPEC": "/path/to/specs/001-feature/spec.md",
  "IMPL_PLAN": "/path/to/specs/001-feature/plan.md",
  "TASKS": "/path/to/specs/001-feature/tasks.md"
}
```

### Validation Rules

| Artifact | Always Required | With `--require-tasks` |
|----------|-----------------|------------------------|
| Feature directory | Yes | Yes |
| plan.md | Yes | Yes |
| tasks.md | No | Yes |
| research.md | No (optional) | No (optional) |
| data-model.md | No (optional) | No (optional) |
| contracts/ | No (optional) | No (optional) |
| quickstart.md | No (optional) | No (optional) |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All required prerequisites met |
| 1 | Missing required artifact or invalid branch |

---

## update-agent-context.sh

**Purpose**: Updates AI coding assistant context files from plan.md data.

**Location**: `.specify/scripts/bash/update-agent-context.sh`

### Usage

```bash
.specify/scripts/bash/update-agent-context.sh [AGENT_TYPE]
```

### Supported Agents (17+)

| Agent | Context File | Description |
|-------|--------------|-------------|
| `claude` | `CLAUDE.md` | Claude Code / Anthropic |
| `gemini` | `GEMINI.md` | Google Gemini |
| `copilot` | `.github/copilot-instructions.md` | GitHub Copilot |
| `cursor-agent` | `.cursor/rules/agent.mdc` | Cursor Agent |
| `qwen` | `QWEN.md` | Alibaba Qwen |
| `opencode` | `OPENCODE.md` | OpenCode |
| `codex` | `CODEX.md` | OpenAI Codex |
| `windsurf` | `.windsurfrules` | Windsurf |
| `kilocode` | `KILOCODE.md` | KiloCode |
| `auggie` | `AUGGIE.md` | Auggie |
| `roo` | `.roo/rules.md` | Roo |
| `codebuddy` | `CODEBUDDY.md` | CodeBuddy |
| `qoder` | `QODER.md` | Qoder |
| `amp` | `AMP.md` | Amp |
| `shai` | `SHAI.md` | Shai |
| `q` | `Q.md` | Amazon Q |
| `bob` | `BOB.md` | Bob |

### Examples

```bash
# Update Claude context
.specify/scripts/bash/update-agent-context.sh claude

# Update Cursor context
.specify/scripts/bash/update-agent-context.sh cursor-agent

# Update GitHub Copilot
.specify/scripts/bash/update-agent-context.sh copilot
```

### Data Extraction

The script parses `plan.md` to extract:

| Section | Extracted Data |
|---------|----------------|
| Technologies | Languages, frameworks, tools |
| Project Structure | Directory layout, file patterns |
| Commands | Build, test, lint commands |
| Code Style | Conventions, patterns |
| Recent Changes | Latest modifications |

### Manual Additions Preservation

Content between these markers is preserved across updates:

```markdown
<!-- MANUAL ADDITIONS START -->
Your custom content here
<!-- MANUAL ADDITIONS END -->
```

### Output

The script generates agent-specific context files with:

1. **Header**: Auto-generated warning and timestamp
2. **Active Technologies**: From plan.md tech stack
3. **Project Structure**: From plan.md directory layout
4. **Commands**: Build, test, lint commands
5. **Code Style**: Conventions and patterns
6. **Recent Changes**: Latest modifications
7. **Manual Additions**: Preserved user content

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid agent type or missing plan.md |

---

## Dependencies

### Script Dependencies

```
common.sh ◄─── create-new-feature.sh
    ▲
    │
    ├──────── setup-plan.sh
    │
    ├──────── check-prerequisites.sh
    │
    └──────── update-agent-context.sh
```

### External Dependencies

| Dependency | Used By | Purpose |
|------------|---------|---------|
| `git` | All scripts | Branch operations, repo detection |
| `bash 4+` | All scripts | Associative arrays, advanced features |
| `grep` | All scripts | Pattern matching |
| `sed` | update-agent-context.sh | Text transformation |
| `awk` | update-agent-context.sh | Field extraction |

---

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `SPECIFY_FEATURE` | Override feature detection | Current git branch |
| `SPECIFY_ROOT` | Override repository root | Git root detection |

### Example Usage

```bash
# Work on specific feature without switching branches
export SPECIFY_FEATURE="003-my-feature"
.specify/scripts/bash/check-prerequisites.sh

# Work in non-git directory
export SPECIFY_ROOT="/path/to/project"
export SPECIFY_FEATURE="001-initial"
.specify/scripts/bash/setup-plan.sh
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Not on feature branch" | Branch name doesn't match `###-*` | Checkout feature branch or set `SPECIFY_FEATURE` |
| "plan.md not found" | Missing implementation plan | Run `/speckit.plan` first |
| "tasks.md not found" | Missing task list (with `--require-tasks`) | Run `/speckit.tasks` first |
| "Feature directory not found" | Missing specs directory | Run `/speckit.specify` first |

### Exit Code Summary

| Code | All Scripts |
|------|-------------|
| 0 | Success |
| 1 | Validation error or missing requirement |
| 2 | Usage error (invalid options) |

---

*Generated by /sc:document - December 2025*
