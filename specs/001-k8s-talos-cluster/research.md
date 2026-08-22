# Phase 0 Research: Kubernetes Cluster with Talos Linux

**Date**: 2025-12-24 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This document captures technology decisions and research findings for the Kubernetes cluster implementation.

---

## 1. Talos + Proxmox Integration

### Decision
Use **manual VM creation via Proxmox UI** with Talos ISO from factory.talos.dev, configured with QEMU guest agent extension.

### Rationale
- **Simplicity**: Manual VM creation is straightforward for 4 VMs (3 Talos + 1 TrueNAS)
- **QEMU Guest Agent**: factory.talos.dev allows building custom images with `siderolabs/qemu-guest-agent` extension for Proxmox integration
- **No Terraform Dependency**: Avoids adding Terraform provider complexity for simple infrastructure
- **Reproducibility**: VM specs documented in plan.md; machine configs are the source of truth

### Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Terraform bpg/proxmox | Full IaC, reproducible | Additional dependency, learning curve, overkill for 4 VMs | Complexity vs value ratio too high |
| Terraform telmate/proxmox | Popular provider | Less maintained, API limitations | Provider quality concerns |
| Packer + Terraform | Golden images | Multi-tool complexity | Over-engineered for this scale |

### Implementation Notes
```bash
# Generate Talos install image with QEMU guest agent
# Visit: https://factory.talos.dev
# Select: Talos 1.9.x, amd64, nocloud
# Add extension: siderolabs/qemu-guest-agent
# Download: metal-amd64.iso or metal-amd64.raw.xz

# VM Creation in Proxmox (repeat for talos-cp-1, talos-cp-2, talos-cp-3)
# - CPU: 3 vCPU (host type)
# - RAM: 14GB (ballooning enabled)
# - Disk: 50GB virtio-scsi
# - Network: vmbr1 (10.9.8.0/24)
# - Boot: Talos ISO
```

---

## 2. TrueNAS CSI Driver Selection

### Decision
Use **democratic-csi** with NFS backend for ReadWriteMany, iSCSI for ReadWriteOnce.

### Rationale
- **Official Support**: Maintained by iXsystems, the company behind TrueNAS
- **Dual Protocol**: Supports both NFS (RWX) and iSCSI (RWO) from single driver
- **Snapshot Support**: CSI snapshots work with TrueNAS ZFS snapshots
- **Active Development**: Regular releases, good community adoption
- **Helm Chart**: Easy deployment via official Helm chart

### Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| truenas-csi-driver | Simpler config | Less maintained, fewer features | democratic-csi is the de facto standard |
| NFS subdir provisioner | Very simple | No iSCSI, no snapshots, no official TrueNAS integration | Missing critical features |
| OpenEBS | Kubernetes-native | Requires local storage, not suited for shared storage VM | Architecture mismatch |

### Implementation Notes
```yaml
# democratic-csi driver modes for TrueNAS Scale:
# - freenas-nfs: NFS shares via TrueNAS API
# - freenas-iscsi: iSCSI targets via TrueNAS API
# - freenas-api-nfs: Newer API-based NFS (experimental)
# - freenas-api-iscsi: Newer API-based iSCSI (experimental)

# Recommended: freenas-nfs for RWX workloads (simpler, more compatible)
# TrueNAS API credentials stored in Kubernetes secret
```

---

## 3. Kubernetes API VIP Strategy

### Decision
Use **Talos built-in VIP** feature (not kube-vip) with shared IP 10.9.8.100.

### Rationale
- **Native Integration**: Talos has built-in VIP support using etcd leader election
- **No Additional Components**: No separate DaemonSet or deployment needed
- **Proven Stability**: Part of Talos core, well-tested
- **Simple Configuration**: Single line in machine config (`machine.network.interfaces[].vip`)

### Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| kube-vip | Feature-rich, supports services | Additional component, redundant with Talos VIP | Talos VIP is simpler and sufficient |
| HAProxy | External LB, proven | Requires separate VM/container, single point of failure | Over-engineering for 3-node cluster |
| Cilium LB | Integrated with CNI | Requires BGP or L2 announcement, complex setup | Too complex for lab environment |
| MetalLB | Popular for bare metal | Another component to manage, overlaps with Cilium | Cilium can handle service LB if needed |

### Implementation Notes
```yaml
# In Talos machine config (controlplane.yaml):
machine:
  network:
    interfaces:
      - interface: eth0
        addresses:
          - 10.9.8.11/24  # Node-specific IP
        vip:
          ip: 10.9.8.100  # Shared VIP for Kubernetes API
        routes:
          - network: 0.0.0.0/0
            gateway: 10.9.8.1

# IMPORTANT: Use node IPs for talosctl, VIP for kubectl
# talosctl --nodes 10.9.8.11,10.9.8.12,10.9.8.13
# kubectl --server https://10.9.8.100:6443
```

---

## 4. Secrets Management Strategy

### Decision
Use **SOPS with age encryption** for Git-committed secrets, with optional migration to sealed-secrets later.

### Rationale
- **Git-Native**: Encrypted secrets can be committed to public repository safely
- **Simple Key Management**: age uses simple file-based keys (no external KMS needed)
- **ArgoCD Integration**: SOPS plugin available for ArgoCD decryption
- **Constitution Compliance**: Meets "Public Repository Security" principle
- **Flexibility**: Works outside Kubernetes for bootstrap secrets (talosconfig)

### Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| sealed-secrets | Kubernetes-native, cluster-bound | Requires running cluster, can't encrypt pre-bootstrap secrets | Can't encrypt talosconfig before cluster exists |
| External Secrets Operator | Cloud KMS integration | Requires external service, complexity | No cloud KMS in homelab environment |
| Vault | Full-featured secrets management | Heavy dependency, operational overhead | Over-engineering for homelab |
| 1Password Connect | Already using 1Password | Requires external service, network dependency | Adds external dependency to cluster bootstrap |

### Implementation Notes
```bash
# Generate age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Create .sops.yaml in repo root
cat > .sops.yaml << 'EOF'
creation_rules:
  - path_regex: .*\.enc\.yaml$
    age: >-
      age1... # public key from keys.txt
EOF

# Encrypt secrets
sops --encrypt secrets.yaml > secrets.enc.yaml

# ArgoCD integration via sops-secrets-operator or ksops plugin
```

---

## 5. ArgoCD Installation Method

### Decision
Use **kubectl apply** with official install manifest, then GitOps-manage ArgoCD itself.

### Rationale
- **Simplicity**: Single command bootstrap, no Helm complexity
- **Official Method**: Recommended by ArgoCD documentation
- **Self-Managing**: After bootstrap, ArgoCD manages its own upgrades via Git
- **Minimal Dependencies**: No Helm required for initial setup

### Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Helm Chart | More configuration options | Additional tool, values file management | Overkill for standard install |
| Kustomize Remote | GitOps-friendly | Still need initial apply | Same as kubectl apply essentially |
| ArgoCD Autopilot | Full GitOps bootstrap | Complex, opinionated structure | Too prescriptive for learning environment |

### Implementation Notes
```bash
# Bootstrap ArgoCD (one-time manual step)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access via Tailscale (port-forward or ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# After bootstrap, create Application CR to manage ArgoCD from Git
# This enables ArgoCD to manage its own configuration going forward
```

---

## Additional Research Findings

### Talos Linux Specific Notes
- **No SSH**: All management via `talosctl` API - aligns with Immutable Infrastructure principle
- **Cluster Config Generation**: `talosctl gen config` creates controlplane.yaml, worker.yaml, talosconfig
- **Machine Config Patches**: Use patches for node-specific settings (hostname, IP)
- **Upgrade Path**: `talosctl upgrade` for OS, `talosctl upgrade-k8s` for Kubernetes

### Cilium CNI Notes
- **Talos Integration**: Talos supports Cilium as default CNI via machine config
- **kube-proxy Replacement**: Cilium can replace kube-proxy (recommended)
- **Network Policies**: Native support for Kubernetes NetworkPolicy
- **Hubble**: Optional observability component for network visibility

### TrueNAS Scale Notes
- **API Access**: democratic-csi uses TrueNAS REST API (enable in UI)
- **ZFS Pool**: Create dedicated pool for Kubernetes PVs
- **NFS Service**: Enable NFS service, configure allowed networks (10.9.8.0/24)
- **User Account**: Create API user with dataset permissions for CSI driver

---

## Research Summary

| Question | Decision | Confidence |
|----------|----------|------------|
| Talos + Proxmox | Manual VM creation with factory.talos.dev ISO | High |
| CSI Driver | democratic-csi with NFS + iSCSI | High |
| Kubernetes API VIP | Talos built-in VIP | High |
| Secrets Management | SOPS with age encryption | High |
| ArgoCD Bootstrap | kubectl apply + self-management | High |

All research questions resolved. Ready to proceed to Phase 1: Design & Contracts.
