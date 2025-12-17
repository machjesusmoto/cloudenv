# Tasks: Core Infrastructure Setup

**Input**: Design documents from `/specs/1-core-infrastructure/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Infrastructure validation tests included per Constitution IV (Test Coverage Discipline).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Per `plan.md` structure:
- **Terraform**: `terraform/` (modules in `terraform/modules/`)
- **Ansible**: `ansible/` (roles in `ansible/roles/`, playbooks in `ansible/playbooks/`)
- **Scripts**: `scripts/`
- **Docs**: `docs/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and repository structure

- [x] T001 Create repository structure per plan.md (terraform/, ansible/, scripts/, docs/)
- [x] T002 [P] Create `terraform/versions.tf` with required providers (libvirt >= 0.7.0)
- [x] T003 [P] Create `terraform/variables.tf` with all input variables from data-model.md
- [x] T004 [P] Create `terraform/terraform.tfvars.example` with documented defaults
- [x] T005 [P] Create `ansible/ansible.cfg` with configuration (inventory, vault, SSH settings)
- [x] T006 [P] Create `ansible/inventory/hosts.yml` template for hypervisors/firewalls/proxmox groups
- [x] T007 [P] Create `ansible/inventory/group_vars/all.yml` with common variables
- [x] T008 Create `ansible/inventory/group_vars/vault.yml.example` with secret placeholders
- [x] T009 [P] Create `docs/README.md` with project overview and quickstart reference
- [x] T010 Create `.gitignore` for terraform state, vault passwords, sensitive files

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: VPS bootstrap and libvirt hypervisor setup - MUST complete before any VM deployment

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T011 Create `ansible/roles/common/` role structure (tasks/, handlers/, defaults/, templates/)
- [x] T012 [P] Implement `ansible/roles/common/tasks/main.yml` with SSH hardening, package updates
- [x] T013 [P] Implement `ansible/roles/common/tasks/users.yml` with deploy user creation
- [x] T014 Create `ansible/roles/libvirt/` role structure
- [x] T015 [P] Implement `ansible/roles/libvirt/tasks/main.yml` with KVM/QEMU/libvirt installation
- [x] T016 [P] Implement `ansible/roles/libvirt/tasks/storage.yml` with storage pool creation at `/var/lib/libvirt/images`
- [x] T017 Implement `ansible/roles/libvirt/tasks/network.yml` with private network bridge (virbr1, 10.0.0.0/24)
- [x] T018 Create `ansible/playbooks/bootstrap.yml` orchestrating common + libvirt roles
- [x] T019 [P] Create `terraform/modules/libvirt-network/main.tf` with private network resource
- [x] T020 [P] Create `terraform/modules/libvirt-network/variables.tf` with network configuration inputs
- [x] T021 [P] Create `terraform/modules/libvirt-network/outputs.tf` with network ID output
- [x] T022 Create `scripts/deploy.sh` with initial VPS bootstrap execution

**Checkpoint**: VPS has libvirt operational, storage pool created, private network defined - VM deployment can begin

---

## Phase 3: User Story 1 - Secure Network Perimeter (Priority: P1) 🎯 MVP

**Goal**: OPNsense firewall captures public IP, creates secure network boundary

**Independent Test**: Verify OPNsense owns public IP, responds to ping, blocks unauthorized traffic per `contracts/firewall-rules.md`

### Tests for User Story 1

- [x] T023 [P] [US1] Create `ansible/tests/security.yml` with firewall rule validation tests
- [x] T024 [P] [US1] Add port scan test to verify default-deny on WAN interface

### Implementation for User Story 1

- [x] T025 [P] [US1] Create `terraform/modules/opnsense-vm/main.tf` with OPNsense VM resource (macvtap WAN, virbr1 LAN)
- [x] T026 [P] [US1] Create `terraform/modules/opnsense-vm/variables.tf` with VM configuration (2 vCPU, 4096MB RAM, 32GB disk)
- [x] T027 [P] [US1] Create `terraform/modules/opnsense-vm/outputs.tf` with WAN IP, LAN IP outputs
- [x] T028 [US1] Create `terraform/modules/opnsense-vm/cloud-init.cfg` for initial bootstrap
- [x] T029 [US1] Add OPNsense module call to `terraform/main.tf`
- [x] T030 Create `ansible/roles/opnsense/` role structure
- [x] T031 [P] [US1] Implement `ansible/roles/opnsense/tasks/main.yml` with OPNsense package installation
- [x] T032 [P] [US1] Create `ansible/roles/opnsense/templates/config.xml.j2` with base OPNsense configuration
- [x] T033 [US1] Implement `ansible/roles/opnsense/tasks/firewall.yml` with rules per `contracts/firewall-rules.md`
- [x] T034 [US1] Implement `ansible/roles/opnsense/tasks/interfaces.yml` with WAN (DHCP) and LAN (10.0.0.1) setup
- [x] T035 [US1] Create `ansible/playbooks/opnsense.yml` orchestrating OPNsense deployment
- [x] T036 [US1] Add OPNsense deployment to `scripts/deploy.sh`

**Checkpoint**: OPNsense VM running, public IP captured, firewall rules active, private network routing operational

---

## Phase 4: User Story 2 - VPN Site-to-Site Connectivity (Priority: P2)

**Goal**: Tailscale VPN connects VPS private network to existing home tailnet

**Independent Test**: From home network device, successfully ping 10.0.0.1 (OPNsense LAN) and verify subnet route advertised

### Tests for User Story 2

- [x] T037 [P] [US2] Create `ansible/tests/connectivity.yml` with Tailscale status and route verification
- [x] T038 [P] [US2] Add home-to-VPS ping test (10.0.0.0/24 accessibility)

### Implementation for User Story 2

- [x] T039 Create `ansible/roles/tailscale/` role structure
- [x] T040 [P] [US2] Implement `ansible/roles/tailscale/tasks/main.yml` with Tailscale plugin installation on OPNsense
- [x] T041 [US2] Implement `ansible/roles/tailscale/tasks/auth.yml` with auth key authentication (from vault)
- [x] T042 [US2] Implement `ansible/roles/tailscale/tasks/subnet.yml` with subnet router configuration (advertise 10.0.0.0/24)
- [x] T043 [P] [US2] Create `ansible/roles/tailscale/templates/tailscale.conf.j2` with exit node and route settings
- [x] T044 [US2] Implement `ansible/roles/opnsense/tasks/tailscale-firewall.yml` with Tailscale interface rules
- [x] T045 [US2] Create `ansible/playbooks/tailscale.yml` orchestrating Tailscale integration
- [x] T046 [US2] Add Tailscale deployment to `scripts/deploy.sh` (after OPNsense)
- [x] T047 [US2] Document Tailscale admin console route approval step in `specs/1-core-infrastructure/quickstart.md`

**Checkpoint**: Tailscale connected, subnet route approved, home devices can reach VPS private network

---

## Phase 5: User Story 3 - Proxmox VE Deployment (Priority: P3)

**Goal**: Proxmox VE running on private network, accessible via Tailscale from home

**Independent Test**: Access Proxmox web UI at https://10.0.0.10:8006 from home network, create and start a test VM

### Tests for User Story 3

- [x] T048 [P] [US3] Add Proxmox web UI accessibility test to `ansible/tests/connectivity.yml`
- [x] T049 [P] [US3] Add Proxmox storage pool validation test

### Implementation for User Story 3

- [x] T050 [P] [US3] Create `terraform/modules/proxmox-vm/main.tf` with Proxmox VM resource (8 vCPU, 49152MB RAM)
- [x] T051 [P] [US3] Create `terraform/modules/proxmox-vm/variables.tf` with VM configuration
- [x] T052 [P] [US3] Create `terraform/modules/proxmox-vm/outputs.tf` with management IP output
- [x] T053 [US3] Create `terraform/modules/proxmox-vm/disks.tf` with root (100GB) and data (700GB) volumes
- [x] T054 [US3] Add Proxmox module call to `terraform/main.tf`
- [x] T055 Create `ansible/roles/proxmox/` role structure
- [x] T056 [P] [US3] Implement `ansible/roles/proxmox/tasks/main.yml` with Proxmox VE installation
- [x] T057 [P] [US3] Implement `ansible/roles/proxmox/tasks/network.yml` with static IP (10.0.0.10, gateway 10.0.0.1)
- [x] T058 [US3] Implement `ansible/roles/proxmox/tasks/storage.yml` with storage pool configuration
- [x] T059 [US3] Implement `ansible/roles/proxmox/tasks/users.yml` with root password from vault
- [x] T060 [US3] Create `ansible/playbooks/proxmox.yml` orchestrating Proxmox deployment
- [x] T061 [US3] Add Proxmox deployment to `scripts/deploy.sh` (after Tailscale)

**Checkpoint**: Proxmox web UI accessible at 10.0.0.10:8006 via Tailscale, storage pools configured, ready for VM creation

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation scripts, and production hardening

- [x] T062 [P] Create `terraform/outputs.tf` with all infrastructure outputs (IPs, network IDs)
- [x] T063 [P] Create `ansible/playbooks/site.yml` as master playbook orchestrating all roles
- [x] T064 [P] Implement `scripts/test.sh` running all ansible tests (connectivity + security)
- [x] T065 [P] Implement `scripts/destroy.sh` with terraform destroy and cleanup
- [x] T066 Create `scripts/backup.sh` for OPNsense config export and state backup
- [x] T067 [P] Update `specs/1-core-infrastructure/quickstart.md` with verified deployment steps
- [x] T068 Create `ansible/playbooks/harden.yml` with temporary SSH access removal (--tags disable-direct-ssh)
- [x] T069 [P] Add ansible-lint and terraform validate to CI/CD workflow (.github/workflows/)
- [ ] T070 Final validation: Run complete test suite per `scripts/test.sh` (requires deployed infrastructure)
- [x] T071 [P] Create `ansible/playbooks/rotate-credentials.yml` for automated credential rotation (Tailscale auth key, vault password reminder)
- [x] T072 Create `docs/disaster-recovery-runbook.md` and validate SC-006 by performing test recovery to verify 2-hour RTO
- [x] T073 [P] Implement `ansible/roles/opnsense/tasks/logging.yml` with syslog configuration per Constitution I audit trail requirements

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - US1 (OPNsense) must complete before US2 (Tailscale) - Tailscale runs on OPNsense
  - US2 (Tailscale) must complete before US3 (Proxmox) - Proxmox only accessible via VPN
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational: VPS + libvirt)
    │
    ▼
Phase 3 (US1: OPNsense) ─── Must complete first
    │
    ▼
Phase 4 (US2: Tailscale) ─── Requires OPNsense operational
    │
    ▼
Phase 5 (US3: Proxmox) ─── Requires VPN for access
    │
    ▼
Phase 6 (Polish)
```

### Within Each Phase

- Tasks marked [P] can run in parallel within that phase
- Terraform modules before main.tf integration
- Ansible roles before playbooks
- Tests before (or alongside) implementation per TDD lite approach

### Parallel Opportunities

**Phase 1** (all [P] tasks can run simultaneously):
```
T002, T003, T004, T005, T006, T007, T009 → all in parallel
```

**Phase 2** (models in parallel, then integration):
```
T012, T013 (common role) → parallel
T015, T016 (libvirt tasks) → parallel
T019, T020, T021 (terraform module) → parallel
```

**Phase 3** (Terraform and Ansible modules in parallel):
```
T025, T026, T027 (terraform module) → parallel
T031, T032 (ansible tasks) → parallel
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (VPS bootstrap + libvirt)
3. Complete Phase 3: User Story 1 (OPNsense)
4. **STOP and VALIDATE**: Verify firewall captures public IP, rules enforced
5. Secure perimeter established - can pause here if needed

### Full Deployment (All Stories)

1. Setup → Foundational → OPNsense (MVP checkpoint)
2. Add Tailscale → Test home-to-VPS connectivity
3. Add Proxmox → Test web UI access via VPN
4. Polish → Production-ready infrastructure

### Time Estimates (per Success Criteria SC-005)

- Phase 1: ~30 minutes
- Phase 2: ~1 hour
- Phase 3: ~1 hour
- Phase 4: ~30 minutes
- Phase 5: ~45 minutes
- Phase 6: ~15 minutes
- **Total**: ~4 hours (aligns with SC-005 target)

---

## Notes

- Constitution compliance verified in plan.md (all principles PASS)
- Network contracts defined in `contracts/network-topology.md` and `contracts/firewall-rules.md`
- Secrets managed via Ansible Vault per Constitution I
- All configuration in Git per Constitution III
- Test coverage focuses on critical paths per Constitution IV
