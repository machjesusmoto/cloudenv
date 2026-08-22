# Pre-Implementation Checklist: Core Infrastructure Setup

**Purpose**: Comprehensive requirements quality validation before implementation begins - validates that specifications are complete, clear, consistent, and measurable across all dimensions.
**Created**: 2025-12-16
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md) | [tasks.md](../tasks.md)
**Audience**: Author (pre-implementation gate)
**Depth**: Comprehensive (Security, IaC, Network, Deployment, Constitution)

---

## Constitution Compliance

### Principle I: Security-First Design

- [ ] CHK001 Are network isolation requirements explicitly specified for all components? [Completeness, Constitution I]
- [x] CHK002 Is "exclusively controlled by firewall" defined with specific technical criteria (interface binding, IP assignment)? [Clarity, Spec §FR-001] ✅ Added technical definition in spec.md US1
- [ ] CHK003 Are encrypted transit requirements specified for all inter-site communication paths? [Completeness, Constitution I]
- [ ] CHK004 Are least-privilege requirements documented for each service (OPNsense, Proxmox, Tailscale)? [Gap, Constitution I]
- [x] CHK005 Are credential management requirements specified (storage, rotation, access patterns)? [Completeness, Spec §Assumptions] ✅ Added FR-009 for credential rotation
- [x] CHK006 Are audit trail requirements defined with specific logging targets and retention? [Gap, Constitution I] ✅ Added detailed audit trail spec in constitution.md

### Principle II: Reliability Through Simplicity

- [ ] CHK007 Is the justification for each component (OPNsense, Proxmox) documented in requirements? [Completeness, Constitution II]
- [ ] CHK008 Are graceful failure requirements defined for each VM (what happens if OPNsense fails vs Proxmox fails)? [Gap, Constitution II]
- [ ] CHK009 Are rollback procedures documented as requirements, not just implementation details? [Gap, Constitution II]
- [ ] CHK010 Are idempotency requirements specified for all IaC operations? [Completeness, Constitution II]

### Principle III: Infrastructure as Code

- [ ] CHK011 Are requirements for declarative configuration vs imperative scripting clearly delineated? [Clarity, Constitution III]
- [ ] CHK012 Is the version control strategy for IaC artifacts specified as a requirement? [Completeness, plan.md §Project Structure]
- [ ] CHK013 Are reproducibility requirements quantified (identical outputs given same inputs)? [Measurability, Constitution III]
- [ ] CHK014 Are anti-snowflake requirements (no manual changes) documented with enforcement mechanisms? [Gap, Constitution III]

### Principle IV: Test Coverage Discipline

- [ ] CHK015 Are validation-before-apply requirements specified for all IaC tools (terraform validate, ansible-lint)? [Completeness, Constitution IV]
- [ ] CHK016 Are contract test requirements defined with specific assertions to verify? [Clarity, contracts/firewall-rules.md §Validation]
- [ ] CHK017 Are integration test requirements specified for end-to-end connectivity scenarios? [Completeness, Constitution IV]
- [ ] CHK018 Is "critical path" coverage defined with measurable criteria? [Ambiguity, Constitution IV]

### Principle V: Extensibility by Design

- [ ] CHK019 Are modular structure requirements documented (what constitutes a separable component)? [Clarity, Constitution V]
- [ ] CHK020 Are parameterization requirements specified for all hardcoded values (IPs, ports, ranges)? [Completeness, plan.md §variables.tf]
- [ ] CHK021 Are extension point documentation requirements defined? [Gap, Constitution V]

---

## Security Requirements Quality

### Network Security

- [ ] CHK022 Are default-deny firewall requirements specified with explicit allow-list format? [Completeness, Spec §FR-003]
- [ ] CHK023 Is "explicitly permitted services" enumerated with specific ports/protocols? [Clarity, Spec §US1 Scenario 1]
- [ ] CHK024 Are anti-spoofing requirements (RFC1918 blocking, bogon filtering) documented? [Gap, contracts/firewall-rules.md]
- [ ] CHK025 Are rate limiting requirements quantified with specific thresholds? [Clarity, contracts/firewall-rules.md §Rate Limiting]
- [x] CHK026 Are logging requirements for security events specified with format and destination? [Completeness, contracts/firewall-rules.md §Logging] ✅ Added to Constitution I audit trail (RFC 5424, /var/log/opnsense/, 90-day retention)

### Access Control

- [ ] CHK027 Are SSH hardening requirements specified with measurable criteria (key-only, port, algorithms)? [Completeness, Constitution §Security Requirements]
- [ ] CHK028 Is "temporary SSH access" requirement scope-limited with specific disablement criteria? [Clarity, Spec §FR-008]
- [ ] CHK029 Are VPN authentication requirements specified (auth method, key strength, rotation)? [Completeness, Constitution §Mandatory Controls]
- [ ] CHK030 Are Proxmox web UI access restrictions documented as requirements? [Completeness, Constitution §Prohibited Practices]

### Credential Management

- [ ] CHK031 Are secret storage requirements specified (Ansible Vault vs environment vs other)? [Clarity, research.md §Secret Management]
- [x] CHK032 Are credential rotation requirements defined with frequency and process? [Gap] ✅ Added FR-009 (90-day Tailscale, annual vault, personnel-change API)
- [ ] CHK033 Are requirements for secrets-in-logs prevention documented? [Gap, Constitution §Prohibited Practices]

---

## Infrastructure/IaC Requirements Quality

### Terraform Requirements

- [ ] CHK034 Are provider version requirements specified with pinning strategy? [Completeness, plan.md §versions.tf]
- [ ] CHK035 Are input variable requirements documented with types, defaults, and validation? [Completeness, data-model.md]
- [ ] CHK036 Are output value requirements specified for downstream consumption? [Gap, plan.md §outputs.tf]
- [ ] CHK037 Are state management requirements defined (local vs remote, locking)? [Gap]
- [ ] CHK038 Are module interface requirements specified (inputs/outputs for each module)? [Completeness, plan.md §modules/]

### Ansible Requirements

- [ ] CHK039 Are role responsibility boundaries clearly defined (what each role owns)? [Clarity, plan.md §roles/]
- [ ] CHK040 Are playbook execution order requirements documented? [Completeness, plan.md §playbooks/]
- [ ] CHK041 Are idempotency requirements specified for all tasks? [Completeness, Constitution II]
- [ ] CHK042 Are inventory structure requirements defined with group hierarchy? [Completeness, plan.md §inventory/]
- [ ] CHK043 Are vault encryption requirements specified (algorithm, password management)? [Gap]

### Automation Scripts

- [ ] CHK044 Are deploy.sh requirements specified with execution prerequisites? [Completeness, plan.md §scripts/]
- [ ] CHK045 Are destroy.sh requirements defined with safety checks and confirmations? [Gap]
- [ ] CHK046 Are test.sh requirements specified with expected outputs and exit codes? [Gap]

---

## Network Architecture Requirements Quality

### Topology Requirements

- [ ] CHK047 Are IP address allocation requirements documented for all static assignments? [Completeness, contracts/network-topology.md §IP Allocation]
- [ ] CHK048 Is CIDR notation consistent across all requirements documents? [Consistency, contracts/network-topology.md]
- [ ] CHK049 Are DHCP range requirements specified with start/end and lease duration? [Completeness, contracts/network-topology.md]
- [ ] CHK050 Are gateway requirements documented for each network segment? [Completeness, contracts/network-topology.md §Routing]
- [ ] CHK051 Are DNS requirements specified (resolver, upstream, local domain)? [Completeness, contracts/network-topology.md §DNS]

### Interface Requirements

- [ ] CHK052 Are interface naming conventions documented (vtnet0, eth0, etc.)? [Clarity, contracts/network-topology.md §Interface Mapping]
- [ ] CHK053 Are MAC address passthrough requirements specified for WAN interface? [Clarity, research.md §Network Architecture]
- [ ] CHK054 Are bridge requirements documented (virbr1 configuration)? [Completeness, data-model.md §Libvirt Network]

### VPN Requirements

- [ ] CHK055 Are Tailscale-specific requirements documented (auth key type, tags, ACLs)? [Completeness, Spec §FR-004]
- [ ] CHK056 Are subnet route advertisement requirements specified? [Completeness, contracts/network-topology.md §Tailscale]
- [ ] CHK057 Are VPN reconnection requirements quantified (timeout, retry, backoff)? [Clarity, Spec §FR-007]
- [ ] CHK058 Is "automatic reconnection" behavior defined with measurable criteria? [Ambiguity, Spec §US2 Scenario 3]
- [ ] CHK059 Are Tailscale admin console manual steps documented as requirements? [Completeness, quickstart.md §Step 7]

---

## Deployment Process Requirements Quality

### Prerequisites

- [ ] CHK060 Are local machine prerequisites specified with version requirements? [Completeness, quickstart.md §Prerequisites]
- [ ] CHK061 Are account prerequisites documented with specific permissions needed? [Completeness, quickstart.md §Account Requirements]
- [ ] CHK062 Are network prerequisites specified (no IP conflicts, ACL requirements)? [Completeness, quickstart.md §Network Requirements]

### Deployment Steps

- [ ] CHK063 Are deployment step dependencies explicitly documented? [Completeness, tasks.md §Dependencies]
- [ ] CHK064 Are checkpoint validation requirements specified between phases? [Gap, tasks.md §Checkpoints]
- [ ] CHK065 Is "4-hour deployment time" broken down into measurable phase estimates? [Clarity, Spec §SC-005]
- [ ] CHK066 Are parallel execution opportunities documented with dependency constraints? [Completeness, tasks.md §Parallel Opportunities]

### Verification

- [ ] CHK067 Are test output requirements specified with pass/fail criteria? [Clarity, quickstart.md §Step 9]
- [ ] CHK068 Are post-deployment validation requirements documented? [Completeness, Spec §Success Criteria]
- [ ] CHK069 Is "99% uptime" requirement defined with measurement methodology? [Measurability, Spec §SC-002]
- [ ] CHK070 Is "100ms RTT" requirement defined with measurement location and methodology? [Measurability, Spec §SC-001]

---

## User Story Requirements Quality

### US1: Secure Network Perimeter (P1)

- [ ] CHK071 Is "exclusively controlled" quantified with specific technical criteria? [Ambiguity, Spec §US1]
- [ ] CHK072 Are acceptance scenario test methods defined (how to verify each scenario)? [Gap, Spec §US1 Scenarios]
- [ ] CHK073 Are default-deny verification requirements specified? [Completeness, Spec §US1 Scenario 3]
- [ ] CHK074 Is the "new virtual network segment" requirement consistent with network topology contract? [Consistency, Spec §US1 Scenario 2 vs contracts/network-topology.md]

### US2: VPN Site-to-Site Connectivity (P2)

- [ ] CHK075 Is "bidirectional traffic flows" defined with specific protocols and ports? [Clarity, Spec §US2 Scenario 1]
- [ ] CHK076 Are "network disruption" scenarios defined for reconnection testing? [Gap, Spec §US2 Scenario 3]
- [ ] CHK077 Is "without manual intervention" quantified with specific timeout and retry behavior? [Ambiguity, Spec §US2 Scenario 3]
- [ ] CHK078 Are Tailscale-specific acceptance criteria aligned with Tailscale capability documentation? [Consistency, Spec §FR-004]

### US3: Proxmox VE Deployment (P3)

- [ ] CHK079 Is "accessible from home network via VPN" testable with specific URL/port? [Measurability, Spec §US3 Scenario 1]
- [ ] CHK080 Are "sufficient vCPU, RAM, and storage" requirements consistent with resource allocation in plan.md? [Consistency, Spec §US3 Scenario 3 vs plan.md]
- [ ] CHK081 Is "within 5 minutes" VM creation requirement measurable and realistic? [Measurability, Spec §SC-004]
- [ ] CHK082 Are nested virtualization requirements documented for Proxmox guests? [Gap, Spec §Edge Cases]

---

## Edge Case & Exception Requirements Quality

- [ ] CHK083 Are public IP change requirements (DHCP renewal) documented with handling behavior? [Completeness, Spec §Edge Cases]
- [ ] CHK084 Are VPN tunnel failure recovery requirements specified with user impact? [Completeness, Spec §Edge Cases]
- [ ] CHK085 Are nested virtualization fallback requirements documented? [Completeness, Spec §Edge Cases]
- [ ] CHK086 Are initial access removal requirements specified with verification method? [Gap, quickstart.md §Post-Deployment]
- [ ] CHK087 Are backup requirements defined with frequency, scope, and retention? [Gap, quickstart.md §Create Backup]
- [ ] CHK088 Are disaster recovery requirements documented with RTO/RPO? [Gap, Spec §SC-006]

---

## Traceability & Documentation Quality

- [ ] CHK089 Do all functional requirements have unique identifiers (FR-001 through FR-008)? [Completeness, Spec]
- [ ] CHK090 Do all success criteria have unique identifiers (SC-001 through SC-006)? [Completeness, Spec]
- [ ] CHK091 Are all tasks traceable to user stories via [US#] markers? [Completeness, tasks.md]
- [ ] CHK092 Are validation assertions in contracts traceable to functional requirements? [Consistency, contracts/]
- [ ] CHK093 Is the relationship between data-model entities and Terraform resources documented? [Completeness, data-model.md §Terraform Resource Mapping]
- [ ] CHK094 Are assumption dependencies validated against actual VPS provider capabilities? [Assumption, Spec §Assumptions]

---

## Notes

- Check items off as completed: `[x]`
- Add findings inline with `[FINDING: description]`
- Items marked `[Gap]` indicate missing requirements that should be added to spec
- Items marked `[Ambiguity]` indicate vague requirements needing clarification
- Items marked `[Consistency]` indicate potential conflicts between documents
- Address all `[Gap]` and `[Ambiguity]` items before starting implementation
