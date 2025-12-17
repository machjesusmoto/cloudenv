<!--
  SYNC IMPACT REPORT
  ==================
  Version Change: 0.0.0 → 1.0.0 (MAJOR - Initial ratification)

  Modified Principles: N/A (Initial creation)

  Added Sections:
  - Core Principles (5 principles defined)
  - Infrastructure Standards (new section)
  - Security Requirements (new section)
  - Governance

  Removed Sections: N/A (Initial creation)

  Templates Requiring Updates:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check section exists)
  - .specify/templates/spec-template.md: ✅ Compatible (Requirements align with principles)
  - .specify/templates/tasks-template.md: ✅ Compatible (Phase structure supports principles)

  Follow-up TODOs: None
-->

# CloudEnv Constitution

## Core Principles

### I. Security-First Design

All infrastructure deployments MUST implement defense-in-depth security:

- **Network Isolation**: Public-facing interfaces MUST be exclusively controlled by the firewall (OPNsense). No direct public access to internal services.
- **Encrypted Transit**: All inter-site communication MUST use encrypted tunnels (IPsec/WireGuard/Tailscale).
- **Least Privilege**: Services MUST run with minimum required permissions. No root unless architecturally required.
- **Credential Management**: Secrets MUST never be stored in code or logs. Use secure secret management patterns.
- **Audit Trail**: Security-relevant operations MUST be logged and auditable.
  - **Logging Targets**: OPNsense logs to `/var/log/opnsense/` locally and forwards to syslog collector (if configured).
  - **Retention**: Minimum 90 days for security logs (firewall, auth, VPN events).
  - **Format**: Syslog-compatible format (RFC 5424) for remote collection compatibility.
  - **Required Events**: Firewall blocks, SSH authentication, VPN tunnel state changes, admin UI access.

**Rationale**: Infrastructure with public IP exposure requires rigorous security posture. A compromised VPS can pivot to home network via VPN.

### II. Reliability Through Simplicity

Infrastructure MUST be simple, predictable, and recoverable:

- **Minimal Components**: Each deployment MUST justify its existence. No speculative additions.
- **Documented State**: All configuration MUST be declarative and version-controlled.
- **Graceful Failure**: Components MUST fail safely without cascading damage.
- **Recovery Path**: Every deployment MUST have a documented rollback procedure.
- **Idempotent Operations**: Running the same deployment twice MUST produce identical results.

**Rationale**: Complex systems fail in complex ways. Remote infrastructure is harder to recover; simplicity reduces failure modes.

### III. Infrastructure as Code

All infrastructure MUST be defined and deployed through code:

- **Declarative Configuration**: Infrastructure state MUST be described in code (Terraform, Ansible, shell scripts), not manual steps.
- **Version Control**: All IaC artifacts MUST be tracked in Git with meaningful commits.
- **Reproducibility**: Given the same inputs, deployment MUST produce identical infrastructure.
- **No Snowflakes**: Manual configuration drift is prohibited. Changes go through code.

**Rationale**: Manual infrastructure is undocumented infrastructure. IaC enables disaster recovery, auditing, and collaboration.

### IV. Test Coverage Discipline

Infrastructure code MUST have appropriate test coverage:

- **Validation Before Apply**: Configuration MUST be validated (syntax, schema, dry-run) before deployment.
- **Contract Tests**: API contracts and network connectivity assumptions MUST be verified.
- **Integration Tests**: End-to-end connectivity (VPN tunnel, service reachability) MUST be tested post-deployment.
- **Coverage Target**: Aim for meaningful test coverage; not every line, but every critical path.

**Rationale**: Infrastructure bugs manifest as outages. Testing reduces production surprises without mandating TDD overhead.

### V. Extensibility by Design

Infrastructure MUST support future growth without rewrites:

- **Modular Structure**: Components MUST be separable. Adding a new VM should not require firewall reconfiguration.
- **Standard Interfaces**: Use well-defined protocols (SSH, HTTPS, standard ports) over custom solutions.
- **Parameterization**: Hardcoded values MUST be extracted to configuration. IPs, ranges, credentials as variables.
- **Documentation**: Extension points MUST be documented for future maintainers.

**Rationale**: Today's VPS hosts OPNsense + Proxmox. Tomorrow it may host additional services. Design for evolution.

## Infrastructure Standards

### Target Environment

- **Provider**: SSDNodes VPS (Seattle region)
- **Resources**: 12 vCPU, 64GB RAM, 1200GB NVMe
- **Virtualization**: Passthrough enabled (nested virtualization capable)
- **Network**: Single public IPv4 assigned to host interface

### Core Components

| Component | Purpose | Network Role |
|-----------|---------|--------------|
| OPNsense Firewall | Perimeter security, NAT, VPN | Owns public IP (WAN), provides private subnet |
| Proxmox VE | Virtualization platform | Private network only, accessed via VPN |

### Network Architecture

- **WAN Interface**: Public IPv4 → OPNsense exclusive
- **LAN Interface**: Private subnet (e.g., 10.x.x.x or 192.168.x.x) → VMs, including Proxmox
- **VPN Tunnel**: Site-to-site to home network (IPsec preferred, WireGuard/Tailscale acceptable)
- **Access Pattern**: Home → VPN → Private subnet → Proxmox (as if on local LAN)

## Security Requirements

### Mandatory Controls

1. **Firewall Rules**: Default deny. Explicit allow rules only for required services.
2. **SSH Hardening**: Key-based auth only, no password auth, non-standard port permitted.
3. **VPN Authentication**: Strong pre-shared keys or certificate-based authentication.
4. **Update Policy**: Security patches MUST be applied within 7 days of release.
5. **Backup Strategy**: Configuration backups MUST exist before changes.

### Prohibited Practices

- Direct public access to Proxmox web UI or SSH
- Storing credentials in Git (even private repos) without encryption
- Disabling firewall for debugging without documented re-enablement
- Running services as root when unprivileged execution is possible

## Governance

### Amendment Process

1. Proposed amendments MUST be documented with rationale
2. Changes to principles require explicit approval
3. All amendments MUST include migration plan if breaking
4. Version MUST be incremented per semantic versioning rules

### Compliance Verification

- All pull requests MUST verify compliance with this constitution
- Constitution Check in plan.md MUST pass before implementation
- Complexity additions MUST be justified in Complexity Tracking table
- Security principle violations are blocking; other violations require documented exception

### Semantic Versioning Policy

- **MAJOR**: Principle removal, redefinition, or backward-incompatible governance change
- **MINOR**: New principle added, section expanded, or material guidance added
- **PATCH**: Clarifications, typo fixes, non-semantic refinements

**Version**: 1.0.0 | **Ratified**: 2025-12-16 | **Last Amended**: 2025-12-16
