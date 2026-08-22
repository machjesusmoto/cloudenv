# Implementation Plan: Kubernetes Cluster with Talos Linux

**Branch**: `001-k8s-talos-cluster` | **Date**: 2025-12-24 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-k8s-talos-cluster/spec.md`

## Summary

Deploy a production-ready 3-node Kubernetes cluster using Talos Linux as the immutable OS, with TrueNAS Scale providing shared NFS storage for HA workloads, and ArgoCD enabling GitOps-based workload management. The cluster will be accessible exclusively via Tailscale, with no public exposure.

## Technical Context

**Language/Version**: Infrastructure as Code (Talos machine configs v1.9+, Kubernetes manifests v1.31+)
**Primary Dependencies**: Talos Linux 1.9.x, TrueNAS Scale 24.10+, Cilium 1.16+, ArgoCD 2.13+, democratic-csi 0.14+
**Storage**: TrueNAS Scale with ZFS pool providing NFS (ReadWriteMany) and iSCSI (ReadWriteOnce)
**Testing**: talosctl health, kubectl cluster-info, shell scripts for integration validation
**Target Platform**: Proxmox VE 9.1.2 on SSDNodes VPS (12 vCPU, 64GB RAM, 1.2TB storage)
**Project Type**: Infrastructure deployment (IaC + GitOps)
**Performance Goals**: <500ms Kubernetes API latency, >100 IOPS per PVC, 3-minute ArgoCD sync
**Constraints**: 1 vCPU / 4.8GB RAM remaining for host after VM allocation, 10-minute boot target
**Scale/Scope**: 3-node control plane (3x3vCPU/14GB), 1 TrueNAS VM (2vCPU/16GB), single cluster

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Validation

| Principle | Status | Evidence |
|-----------|--------|----------|
| **I. Infrastructure as Code** | PASS | All configs Git-tracked: Talos machine configs, K8s manifests, ArgoCD Applications |
| **II. Public Repository Security** | PASS | Secrets via sealed-secrets/SOPS; IPs use placeholders; talosconfig/kubeconfig gitignored |
| **III. Immutable Infrastructure** | PASS | Talos Linux is API-only (no SSH); ArgoCD for GitOps; all changes via declarative updates |
| **IV. Defense in Depth** | PASS | Network isolation (virbr1), Tailscale-only access, Pod Security Standards, secrets encrypted |
| **V. Observable Systems** | DEFERRED | P3 story covers Prometheus/Grafana; acceptable to defer for MVP |
| **VI. Resource Efficiency** | PASS | Right-sized VMs, memory ballooning enabled, host retains minimal overhead |

### Post-Design Validation (Phase 1 Complete)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Infrastructure as Code | VERIFY | Confirm all generated configs are Git-tracked |
| II. Public Repository Security | VERIFY | Audit contracts/ for any embedded secrets |
| III. Immutable Infrastructure | VERIFY | Confirm no SSH-based config patterns in design |
| IV. Defense in Depth | VERIFY | Validate network policies in data-model |
| V. Observable Systems | N/A | Deferred to P3 |
| VI. Resource Efficiency | VERIFY | Confirm resource allocations match spec |

## Project Structure

### Documentation (this feature)

```text
specs/001-k8s-talos-cluster/
├── plan.md              # This file
├── research.md          # Phase 0: Technology decisions and research
├── data-model.md        # Phase 1: Entities, configs, relationships
├── quickstart.md        # Phase 1: Deployment guide
├── contracts/           # Phase 1: API contracts, config schemas
│   ├── talos-machine-config.yaml    # Talos controlplane config schema
│   ├── truenas-nfs-share.yaml       # TrueNAS NFS export config
│   ├── democratic-csi-values.yaml   # CSI driver Helm values
│   ├── argocd-values.yaml           # ArgoCD Helm values
│   └── cilium-values.yaml           # Cilium CNI Helm values
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
kubernetes/
├── bootstrap/
│   ├── talos/
│   │   ├── controlplane.yaml.template    # Machine config template
│   │   ├── talossecrets.yaml.enc         # Encrypted cluster secrets
│   │   └── patches/                       # Node-specific patches
│   ├── truenas/
│   │   └── truenas-scale-config.yaml     # TrueNAS initial setup
│   └── scripts/
│       ├── bootstrap-cluster.sh          # One-shot cluster bootstrap
│       ├── generate-configs.sh           # Generate machine configs
│       └── verify-cluster.sh             # Health verification
│
├── core/
│   ├── kustomization.yaml
│   ├── namespaces/
│   ├── storage/
│   │   ├── democratic-csi/               # CSI driver manifests
│   │   └── storage-classes.yaml
│   ├── networking/
│   │   ├── cilium/                       # CNI manifests
│   │   └── network-policies.yaml
│   └── security/
│       ├── pod-security-standards.yaml
│       └── sealed-secrets/
│
├── apps/
│   ├── argocd/
│   │   ├── install.yaml                  # ArgoCD Helm release
│   │   └── app-of-apps.yaml              # Root application
│   └── monitoring/                        # P3 - deferred
│       └── .gitkeep
│
└── tests/
    ├── smoke/
    │   ├── cluster-health.sh
    │   └── storage-test.yaml
    └── integration/
        └── failover-test.sh
```

**Structure Decision**: Infrastructure project with GitOps pattern. Bootstrap scripts for initial cluster setup, core/ for base infrastructure managed by ArgoCD, apps/ for user workloads. Tests are shell scripts and kubectl-applied validation manifests.

## Complexity Tracking

> No constitution violations requiring justification. Design aligns with all 6 principles.

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| 3 control-plane nodes | Required | etcd quorum needs 3 nodes for fault tolerance |
| TrueNAS as separate VM | Required | Shared storage for pod HA; cannot run on Talos |
| ArgoCD for GitOps | Required | Constitution mandates IaC workflow |
| Cilium over Flannel | Preferred | Constitution specifies Cilium; provides network policies |

## Research Questions (Phase 0)

The following must be resolved before detailed design:

1. **Talos + Proxmox Integration**: Best method for VM creation (Terraform vs manual)?
2. **TrueNAS CSI Driver**: democratic-csi vs truenas-csi-driver - which is maintained?
3. **VIP for Kubernetes API**: kube-vip vs HAProxy vs Cilium LB?
4. **Secrets Management**: sealed-secrets vs SOPS vs external secrets operator?
5. **ArgoCD Initial Bootstrap**: Helm vs manifest-based installation?

## Dependencies

| Dependency | Source | Version | Status |
|------------|--------|---------|--------|
| Talos Linux | factory.talos.dev | 1.9.x | Available |
| TrueNAS Scale | truenas.com | 24.10+ | Available |
| Cilium | quay.io/cilium | 1.16+ | Available |
| ArgoCD | argoproj | 2.13+ | Available |
| democratic-csi | democratic-csi/charts | 0.14+ | Available |
| kube-vip | kube-vip/kube-vip | 0.8+ | Available |

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Host resource exhaustion | Medium | High | Memory ballooning, monitoring alerts |
| etcd quorum loss | Low | Critical | 3-node control plane, regular backups |
| TrueNAS VM failure | Low | High | ZFS snapshots, documented recovery |
| Tailscale connectivity loss | Low | Medium | Document direct Proxmox console access |
| Talos upgrade issues | Low | Medium | Test upgrades in maintenance window |
