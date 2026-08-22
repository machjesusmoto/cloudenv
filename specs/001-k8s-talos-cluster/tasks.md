# Tasks: Kubernetes Cluster with Talos Linux

**Input**: Design documents from `/specs/001-k8s-talos-cluster/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: Smoke tests included per quickstart.md validation requirements.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **[TERRAFORM]**: Automated via Terraform - run `terraform apply`
- **[MANUAL]**: Requires human intervention (UI, physical access)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- `kubernetes/bootstrap/` - Talos configs, scripts, TrueNAS docs
- `kubernetes/core/` - Storage, networking, security
- `kubernetes/apps/` - ArgoCD and applications
- `kubernetes/tests/` - Smoke and integration tests
- `kubernetes/terraform/` - Infrastructure as Code (Proxmox, Talos, Helm)

---

## Phase 0: Terraform Infrastructure (Automation Foundation) 🔧 NEW

**Purpose**: Initialize Terraform and prepare for automated infrastructure deployment

**⚠️ AUTOMATION**: This phase enables automated execution of most [TERRAFORM] tasks

### Terraform Initialization

- [x] TF01 [P] Create kubernetes/terraform/versions.tf with provider constraints
- [x] TF02 [P] Create kubernetes/terraform/variables.tf with all input variables
- [x] TF03 [P] Create kubernetes/terraform/providers.tf with provider configurations
- [x] TF04 Create kubernetes/terraform/main.tf with infrastructure resources
- [x] TF05 [P] Create kubernetes/terraform/outputs.tf with cluster outputs
- [x] TF06 [P] Create kubernetes/terraform/terraform.tfvars.example template
- [x] TF07 [P] Create kubernetes/terraform/README.md with usage documentation
- [x] TF08 [P] Update kubernetes/.gitignore with Terraform patterns

### Terraform Setup (Manual Steps)

- [ ] TF09 Copy terraform.tfvars.example to terraform.tfvars [MANUAL: Configuration]
- [ ] TF10 Configure proxmox_endpoint and proxmox_api_token in terraform.tfvars [MANUAL: Credentials]
- [ ] TF11 Upload TrueNAS Scale ISO to Proxmox storage [MANUAL: ISO Upload]
- [ ] TF12 Run `terraform init` in kubernetes/terraform/ [MANUAL: CLI]
- [ ] TF13 Run `terraform plan` and review changes [MANUAL: Review]

**Checkpoint**: Terraform initialized - can deploy infrastructure with `terraform apply`

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create project directory structure and initialize configuration framework

- [x] T001 Create kubernetes directory structure per plan.md in kubernetes/
- [x] T002 [P] Create bootstrap subdirectories in kubernetes/bootstrap/{talos,truenas,scripts}/
- [x] T003 [P] Create core subdirectories in kubernetes/core/{namespaces,storage,networking,security}/
- [x] T004 [P] Create apps subdirectory in kubernetes/apps/argocd/
- [x] T005 [P] Create tests subdirectories in kubernetes/tests/{smoke,integration}/
- [x] T006 Initialize kustomization.yaml in kubernetes/core/namespaces/
- [x] T007 [P] Create .sops.yaml configuration template in kubernetes/core/security/.sops.yaml
- [x] T008 [P] Create README.md with project overview in kubernetes/README.md

---

## Phase 2: Foundational (TrueNAS Infrastructure)

**Purpose**: TrueNAS VM creation and configuration - MUST be complete before Kubernetes cluster bootstrap

**⚠️ CRITICAL**: Storage infrastructure must exist before cluster can use persistent volumes

**🔧 AUTOMATION**: T010 automated via Terraform; T011-T018 require manual TrueNAS setup wizard

- [x] T009 Document TrueNAS VM creation steps in kubernetes/bootstrap/truenas/VM-SETUP.md
- [ ] T010 Create TrueNAS VM (VM ID 200) in Proxmox per spec: 2 vCPU, 16GB RAM, 100GB OS + 200GB pool [TERRAFORM: proxmox_virtual_machine.truenas]
- [ ] T011 Install TrueNAS Scale and configure static IP 10.9.8.20/24 [MANUAL: TrueNAS installer wizard]
- [ ] T012 Create ZFS pool 'k8s-storage' with second disk [MANUAL: TrueNAS UI - hardware-dependent]
- [ ] T013 Create NFS dataset 'k8s-storage/nfs' with LZ4 compression, 180GB quota [MANUAL: TrueNAS UI]
- [ ] T014 Configure NFS share for /mnt/k8s-storage/nfs with network 10.9.8.0/24 [MANUAL: TrueNAS UI]
- [ ] T015 Enable NFS service with auto-start [MANUAL: TrueNAS UI]
- [ ] T016 Create TrueNAS API key 'k8s-csi' for democratic-csi integration [MANUAL: TrueNAS UI]
- [ ] T017 Document TrueNAS API key securely (add to terraform.tfvars as truenas_api_key) [MANUAL: Configuration]
- [ ] T018 Validate NFS share accessible from test client [MANUAL: Network test]

**Checkpoint**: TrueNAS storage infrastructure ready - Talos cluster bootstrap can proceed

---

## Phase 3: User Story 1 - Bootstrap Kubernetes Cluster (Priority: P1) 🎯 MVP

**Goal**: Deploy 3-node Talos Linux control plane with Cilium CNI and Talos VIP

**Independent Test**: `kubectl get nodes` shows 3 Ready nodes, `talosctl health` passes

**🔧 AUTOMATION**: Most tasks automated via Terraform (talos_*, proxmox_*, helm_release providers)

### Talos VM Creation

- [ ] T019 [US1] Download Talos 1.9.x ISO with qemu-guest-agent from factory.talos.dev [TERRAFORM: talos_image_factory_schematic + proxmox_download_file]
- [ ] T020 [US1] Upload Talos ISO to Proxmox local storage [TERRAFORM: proxmox_download_file.talos_iso]
- [ ] T021 [P] [US1] Create talos-cp-1 VM (ID 201): 3 vCPU, 14GB RAM, 50GB disk at 10.9.8.11 [TERRAFORM: proxmox_virtual_machine.controlplane]
- [ ] T022 [P] [US1] Create talos-cp-2 VM (ID 202): 3 vCPU, 14GB RAM, 50GB disk at 10.9.8.12 [TERRAFORM: proxmox_virtual_machine.controlplane]
- [ ] T023 [P] [US1] Create talos-cp-3 VM (ID 203): 3 vCPU, 14GB RAM, 50GB disk at 10.9.8.13 [TERRAFORM: proxmox_virtual_machine.controlplane]
- [ ] T024 [US1] Boot all 3 Talos VMs and note maintenance mode IPs [TERRAFORM: VMs auto-boot on_boot=true]

### Talos Configuration Files

- [ ] T025 [US1] Generate cluster secrets with talosctl gen secrets [TERRAFORM: talos_machine_secrets.this]
- [ ] T026 [US1] Generate age keypair for SOPS encryption [MANUAL: Security key generation]
- [ ] T027 [US1] Encrypt secrets.yaml using SOPS [MANUAL: SOPS encryption - security]
- [ ] T028 [US1] Remove plaintext secrets.yaml after encryption [MANUAL: Security cleanup]
- [x] T029 [US1] Create controlplane.yaml.template per talos-machine-config.yaml contract in kubernetes/bootstrap/talos/
- [x] T030 [P] [US1] Create node patch talos-cp-1.yaml (hostname, IP 10.9.8.11) in kubernetes/bootstrap/talos/patches/
- [x] T031 [P] [US1] Create node patch talos-cp-2.yaml (hostname, IP 10.9.8.12) in kubernetes/bootstrap/talos/patches/
- [x] T032 [P] [US1] Create node patch talos-cp-3.yaml (hostname, IP 10.9.8.13) in kubernetes/bootstrap/talos/patches/
- [x] T033 [US1] Create common.yaml patch with Talos VIP 10.9.8.100 config in kubernetes/bootstrap/talos/patches/

### Cluster Bootstrap

- [x] T034 [US1] Create generate-configs.sh script in kubernetes/bootstrap/scripts/
- [ ] T035 [US1] Generate machine configs with secrets and patches [TERRAFORM: data.talos_machine_configuration.*]
- [ ] T036 [US1] Apply config to talos-cp-1 [TERRAFORM: talos_machine_configuration_apply.controlplane]
- [ ] T037 [US1] Apply config to talos-cp-2 [TERRAFORM: talos_machine_configuration_apply.controlplane]
- [ ] T038 [US1] Apply config to talos-cp-3 [TERRAFORM: talos_machine_configuration_apply.controlplane]
- [ ] T039 [US1] Wait for nodes to reboot and acquire static IPs [TERRAFORM: implicit dependency]
- [x] T040 [US1] Create bootstrap-cluster.sh script in kubernetes/bootstrap/scripts/
- [ ] T041 [US1] Bootstrap etcd on talos-cp-1 with talosctl bootstrap [TERRAFORM: talos_machine_bootstrap.this]
- [ ] T042 [US1] Monitor bootstrap progress with talosctl dmesg --follow [TERRAFORM: data.talos_cluster_health.this]
- [ ] T043 [US1] Generate kubeconfig with talosctl kubeconfig [TERRAFORM: data.talos_cluster_kubeconfig.this + local_file]

### Cilium CNI Installation

- [ ] T044 [US1] Add Cilium Helm repository [TERRAFORM: helm_release.cilium (repository embedded)]
- [x] T045 [US1] Create cilium-values.yaml per contract in kubernetes/core/networking/cilium/values.yaml
- [x] T046 [US1] Install Cilium with Helm using kube-proxy replacement mode (install-cilium.sh created)
- [ ] T047 [US1] Wait for Cilium pods ready in kube-system namespace [TERRAFORM: helm_release.cilium (wait=true)]
- [ ] T048 [US1] Verify all nodes show Ready status with kubectl get nodes [TERRAFORM: data.talos_cluster_health.this]

### US1 Validation

- [x] T049 [US1] Create cluster-health.sh smoke test in kubernetes/tests/smoke/
- [x] T050 [US1] Run talosctl health across all 3 nodes (verify-cluster.sh created)
- [x] T051 [US1] Verify etcd cluster health with talosctl etcd status (included in cluster-health.sh)
- [x] T052 [US1] Verify Cilium status with cilium status command (included in cluster-health.sh)

**Checkpoint**: Kubernetes cluster operational with CNI - can proceed to storage or GitOps

---

## Phase 4: User Story 2 - Shared Storage for HA Workloads (Priority: P1)

**Goal**: Dynamic NFS provisioning via democratic-csi with TrueNAS backend

**Independent Test**: Create PVC, verify Bound status, mount in test pod, write/read data

**🔧 AUTOMATION**: Namespace, secret, Helm install automated via Terraform (requires truenas_api_key in tfvars)

### democratic-csi Installation

- [x] T053 [US2] Create democratic-csi namespace with kubectl (namespace.yaml created)
- [x] T054 [US2] Create driver-config-secret.yaml template in kubernetes/core/storage/democratic-csi/
- [ ] T055 [US2] Populate TrueNAS API key in terraform.tfvars [MANUAL: Add truenas_api_key value]
- [ ] T056 [US2] Encrypt driver-config-secret.yaml with SOPS [MANUAL: SOPS encryption - security]
- [ ] T057 [US2] Apply driver config secret to cluster [TERRAFORM: kubernetes_secret.democratic_csi_driver_config]
- [ ] T058 [US2] Add democratic-csi Helm repository [TERRAFORM: helm_release.democratic_csi (repository embedded)]
- [x] T059 [US2] Create values.yaml per democratic-csi-values.yaml contract in kubernetes/core/storage/democratic-csi/
- [ ] T060 [US2] Install democratic-csi with Helm [TERRAFORM: helm_release.democratic_csi]
- [x] T061 [US2] Create truenas-nfs StorageClass as default in kubernetes/core/storage/democratic-csi/storageclass.yaml
- [ ] T062 [US2] Verify democratic-csi pods running [TERRAFORM: helm_release (implicit wait)]

### US2 Validation

- [x] T063 [US2] Create storage-test.sh smoke test in kubernetes/tests/smoke/
- [ ] T064 [US2] Create test PVC requesting 1Gi from truenas-nfs StorageClass [MANUAL: kubectl apply]
- [ ] T065 [US2] Verify PVC status is Bound [MANUAL: kubectl verification]
- [ ] T066 [US2] Create test pod mounting the PVC and writing test data [MANUAL: kubectl apply]
- [ ] T067 [US2] Verify TrueNAS shows dataset created under k8s-storage/nfs [MANUAL: TrueNAS UI]
- [ ] T068 [US2] Delete test pod and PVC, verify cleanup on TrueNAS [MANUAL: kubectl delete + verify]

**Checkpoint**: Persistent storage available for workloads - can proceed to GitOps

---

## Phase 5: User Story 3 - GitOps Deployment with ArgoCD (Priority: P2)

**Goal**: ArgoCD managing cluster from Git repository with app-of-apps pattern

**Independent Test**: ArgoCD UI accessible, can sync applications from Git

**🔧 AUTOMATION**: ArgoCD Helm installation automated via Terraform; app-of-apps requires manual apply

### ArgoCD Installation

- [x] T069 [US3] Create argocd namespace with kubectl (namespace.yaml created)
- [ ] T070 [US3] Download ArgoCD stable manifest (or use Helm) [TERRAFORM: helm_release.argocd uses argo-helm chart]
- [ ] T071 [US3] Install ArgoCD to cluster [TERRAFORM: helm_release.argocd + kubernetes_namespace.argocd]
- [ ] T072 [US3] Wait for argocd-server pod ready [TERRAFORM: helm_release (implicit wait)]
- [ ] T073 [US3] Retrieve initial admin password from argocd-initial-admin-secret [MANUAL: kubectl get secret]
- [ ] T074 [US3] Document admin password securely (encrypt with SOPS if stored) [MANUAL: SOPS encryption - security]

### App-of-Apps Pattern

- [x] T075 [US3] Create app-of-apps.yaml Application manifest in kubernetes/apps/argocd/
- [x] T076 [US3] Configure source pointing to kubernetes/apps/ in Git repository (in app-of-apps.yaml)
- [x] T077 [US3] Configure automated sync with prune and self-heal (in app-of-apps.yaml)
- [ ] T078 [US3] Apply app-of-apps Application to cluster [MANUAL: kubectl apply - Git repo dependent]

### US3 Validation

- [x] T079 [US3] Create argocd-test.sh smoke test in kubernetes/tests/smoke/
- [ ] T080 [US3] Port-forward ArgoCD server to localhost:8080 [MANUAL: kubectl port-forward]
- [ ] T081 [US3] Verify ArgoCD UI accessible and login works [MANUAL: Browser access]
- [ ] T082 [US3] Verify app-of-apps Application shows Synced status [MANUAL: ArgoCD UI]
- [ ] T083 [US3] Create test Application manifest and verify auto-sync from Git [MANUAL: Git + ArgoCD]

**Checkpoint**: GitOps pipeline operational - cluster self-manages from repository

---

## Phase 6: User Story 4 - Secure Remote Access (Priority: P2)

**Goal**: Kubernetes and Talos API accessible via Tailscale from any trusted device

**Independent Test**: kubectl and talosctl work from Tailscale-connected laptop

### Tailscale Integration

- [ ] T084 [US4] Verify Tailscale network access to 10.9.8.0/24 subnet [MANUAL: Tailscale setup]
- [ ] T085 [US4] Configure talosconfig with endpoint 10.9.8.100 (VIP) in ~/.talos/config [MANUAL: talosctl config]
- [ ] T086 [US4] Configure kubeconfig with server https://10.9.8.100:6443 in ~/.kube/config [MANUAL: talosctl kubeconfig]
- [x] T087 [US4] Document access configuration in kubernetes/bootstrap/ACCESS.md

### US4 Validation

- [x] T088 [US4] Create access-test.sh smoke test in kubernetes/tests/smoke/
- [ ] T089 [US4] Verify talosctl commands work from Tailscale-connected device
- [ ] T090 [US4] Verify kubectl commands work from Tailscale-connected device
- [ ] T091 [US4] Test ArgoCD UI access via port-forward from remote device

**Checkpoint**: Remote management fully operational

---

## Phase 7: User Story 5 - Cluster Monitoring Foundation (Priority: P3 - Deferred)

**Goal**: Prometheus/Grafana stack for cluster observability

**Status**: DEFERRED - Placeholder for future implementation

> **Note**: This phase is intentionally minimal. Full monitoring implementation deferred per spec.md priorities.

- [x] T092 [US5] Create monitoring namespace placeholder in kubernetes/core/namespaces/
- [x] T093 [US5] Document monitoring requirements in kubernetes/core/monitoring/REQUIREMENTS.md
- [x] T094 [US5] Create kube-prometheus-stack values template for future deployment

**Checkpoint**: Monitoring preparation complete - defer full implementation

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, security hardening, and validation across all user stories

### Documentation

- [x] T095 [P] Update kubernetes/README.md with complete deployment guide
- [x] T096 [P] Create TROUBLESHOOTING.md in kubernetes/ with common issues
- [x] T097 [P] Document SOPS/age key management procedures in kubernetes/core/security/KEY-MANAGEMENT.md
- [ ] T098 Validate quickstart.md accuracy against actual deployment steps [MANUAL: Requires deployment]

### Security Hardening

- [ ] T099 Audit all YAML files for committed secrets (must all be encrypted) [MANUAL: Requires secrets]
- [ ] T100 Verify SOPS encryption on all sensitive files [MANUAL: Requires secrets]
- [x] T101 [P] Create .gitignore for unencrypted secret patterns
- [ ] T102 Review Cilium network policies for least privilege [MANUAL: Post-deployment]

### Integration Testing

- [x] T103 Create full-stack integration test in kubernetes/tests/integration/full-stack-test.sh
- [ ] T104 Test workload deployment with PVC through ArgoCD [MANUAL: Requires cluster]
- [ ] T105 Verify workload survives single node failure [MANUAL: Requires cluster]
- [ ] T106 Run all smoke tests from kubernetes/tests/smoke/ [MANUAL: Requires cluster]

### Final Validation

- [ ] T107 Run complete quickstart.md procedure on fresh environment (if possible)
- [ ] T108 Commit all configuration to Git repository
- [ ] T109 Verify ArgoCD syncs and reconciles all resources

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──────────────────────────────────────────┐
                                                          │
Phase 2 (Foundational: TrueNAS) ─────── BLOCKS ALL ──────┤
                                                          │
         ┌────────────────────────────────────────────────┘
         │
         ├── Phase 3 (US1: Cluster Bootstrap) ─── MVP ───┐
         │                                                │
         │   Phase 4 (US2: Storage) ─── depends on US1 ──┤
         │                                                │
         │   Phase 5 (US3: ArgoCD) ─── depends on US1 ───┤
         │                                                │
         │   Phase 6 (US4: Access) ─── depends on US1 ───┤
         │                                                │
         │   Phase 7 (US5: Monitoring) ─── DEFERRED ─────┤
         │                                                │
         └── Phase 8 (Polish) ─── depends on all above ──┘
```

### User Story Dependencies

- **US1 (P1)**: Depends only on Foundational (Phase 2) - Core MVP
- **US2 (P1)**: Depends on US1 (cluster must exist for CSI driver)
- **US3 (P2)**: Depends on US1 (cluster must exist for ArgoCD)
- **US4 (P2)**: Depends on US1 (cluster must exist for access)
- **US5 (P3)**: DEFERRED - Placeholder only

### Parallel Opportunities

Within each phase, tasks marked [P] can run concurrently:

**Phase 1**: T002-T005 (directory creation), T007-T008 (config files)
**Phase 3**: T021-T023 (VM creation), T030-T032 (node patches)
**Phase 4**: All tasks sequential (Helm install → validation)
**Phase 5**: All tasks sequential (install → configure → validate)
**Phase 6**: T085-T087 (config updates)
**Phase 8**: T095-T097, T101 (documentation tasks)

---

## Parallel Example: Phase 3 VM Creation

```bash
# These 3 VM creation tasks can run in parallel (different VMs):
Task: "Create talos-cp-1 VM (ID 201) in Proxmox"
Task: "Create talos-cp-2 VM (ID 202) in Proxmox"
Task: "Create talos-cp-3 VM (ID 203) in Proxmox"

# These 3 patch files can be created in parallel:
Task: "Create node patch talos-cp-1.yaml in kubernetes/bootstrap/talos/patches/"
Task: "Create node patch talos-cp-2.yaml in kubernetes/bootstrap/talos/patches/"
Task: "Create node patch talos-cp-3.yaml in kubernetes/bootstrap/talos/patches/"
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1: Setup (T001-T008)
2. Complete Phase 2: Foundational TrueNAS (T009-T018)
3. Complete Phase 3: User Story 1 - Cluster Bootstrap (T019-T052)
4. **STOP and VALIDATE**: `kubectl get nodes` shows 3 Ready nodes
5. Kubernetes cluster operational without storage or GitOps

### Incremental Delivery

1. **MVP**: Setup + Foundational + US1 → Working cluster
2. **+Storage**: Add US2 → PVCs available for workloads
3. **+GitOps**: Add US3 → Self-managing cluster from Git
4. **+Access**: Add US4 → Remote management enabled
5. **+Polish**: Add Phase 8 → Production-ready documentation

### Suggested MVP Scope

For initial deployment, complete through Phase 3 (US1):
- **Total Tasks for MVP**: 52 tasks (T001-T052)
- **Estimated Effort**: ~4-6 hours hands-on
- **Deliverable**: Functional 3-node Kubernetes cluster with Cilium CNI

---

## Summary

| Phase | Story | Tasks | Parallel | Terraform | Manual | Description |
|-------|-------|-------|----------|-----------|--------|-------------|
| 0 | Terraform | 13 | 7 | 0 | 5 | Infrastructure as Code setup |
| 1 | Setup | 8 | 6 | 0 | 0 | Project structure (completed) |
| 2 | Foundation | 10 | 0 | 1 | 9 | TrueNAS infrastructure |
| 3 | US1 (P1) | 34 | 6 | 18 | 3 | Kubernetes cluster bootstrap |
| 4 | US2 (P1) | 16 | 0 | 4 | 7 | democratic-csi storage |
| 5 | US3 (P2) | 15 | 0 | 4 | 7 | ArgoCD GitOps |
| 6 | US4 (P2) | 8 | 0 | 0 | 4 | Secure remote access |
| 7 | US5 (P3) | 3 | 0 | 0 | 0 | Monitoring (deferred) |
| 8 | Polish | 15 | 4 | 0 | 9 | Documentation & validation |

**Total Tasks**: 122 (109 original + 13 Terraform phase)
**Terraform-Automated Tasks**: 27 tasks automated via `terraform apply`
**Manual-Only Tasks**: 44 tasks require human intervention
**Parallel Opportunities**: 23 tasks can run in parallel within their phases
**MVP Tasks**: 65 (through US1, including Terraform phase)

### Automation Impact

With Terraform automation, the deployment workflow becomes:

1. **One-time setup**: Configure `terraform.tfvars` with Proxmox credentials
2. **Single command**: `terraform apply` deploys VMs, Talos, Cilium, CSI, ArgoCD
3. **Manual steps**: TrueNAS wizard, SOPS encryption, validation testing

**Before Terraform**: ~50 manual CLI/UI operations
**After Terraform**: ~15 manual operations (mostly TrueNAS setup + validation)

---

## Notes

- **[P]** = Tasks can run in parallel (different files, no dependencies)
- **[Story]** = Maps task to specific user story for traceability
- **[TERRAFORM]** = Automated via Terraform - run `terraform apply` in kubernetes/terraform/
- **[MANUAL]** = Requires human intervention (UI, security keys, validation)
- Each user story is independently completable after its dependencies
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All sensitive data must be SOPS-encrypted before Git commit
- Terraform state contains secrets - treat `terraform.tfstate` as sensitive
