# Data Model: Kubernetes Cluster with Talos Linux

**Date**: 2025-12-24 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This document defines entities, configurations, and relationships for the Kubernetes cluster infrastructure.

---

## Entity Definitions

### 1. TalosNode

A Talos Linux virtual machine running Kubernetes control plane components.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `hostname` | string | Node hostname | Pattern: `talos-cp-[1-3]` |
| `ip_address` | string | Static IP on cluster network | Range: `10.9.8.11-13` |
| `role` | enum | Node role | `controlplane` (workers deferred) |
| `vcpu` | integer | Virtual CPU count | Fixed: `3` |
| `memory_gb` | integer | RAM allocation | Fixed: `14` |
| `disk_gb` | integer | Root disk size | Fixed: `50` |
| `talos_version` | string | Talos Linux version | `1.9.x` |
| `kubernetes_version` | string | Kubernetes version | `1.31.x` |

**Relationships**:
- Member of `TalosCluster` (1:N)
- Connected to `ClusterNetwork` via eth0
- Participates in `VIP` election

### 2. TalosCluster

The Kubernetes cluster formed by TalosNode instances.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `name` | string | Cluster name | `cloudenv-k8s` |
| `vip` | string | Kubernetes API VIP | `10.9.8.100` |
| `pod_cidr` | string | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | string | Service network CIDR | `10.96.0.0/12` |
| `dns_domain` | string | Cluster DNS domain | `cluster.local` |
| `cni` | string | Container Network Interface | `cilium` |

**Relationships**:
- Contains 3 `TalosNode` instances
- Connects to `TrueNASStorage` for PVs
- Hosts `ArgoCD` deployment

### 3. TrueNASStorage

TrueNAS Scale VM providing shared storage via NFS/iSCSI.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `hostname` | string | VM hostname | `truenas-scale` |
| `ip_address` | string | Static IP | `10.9.8.20` |
| `vcpu` | integer | Virtual CPU count | Fixed: `2` |
| `memory_gb` | integer | RAM allocation | Fixed: `16` |
| `os_disk_gb` | integer | OS disk size | Fixed: `100` |
| `pool_disk_gb` | integer | ZFS pool disk size | Fixed: `200` |
| `pool_name` | string | ZFS pool name | `k8s-storage` |
| `nfs_network` | string | Allowed NFS clients | `10.9.8.0/24` |

**Relationships**:
- Provides PVs to `TalosCluster`
- Accessed by `DemocraticCSI` driver

### 4. DemocraticCSI

CSI driver deployment for TrueNAS integration.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `namespace` | string | Deployment namespace | `democratic-csi` |
| `driver_name` | string | CSI driver identifier | `org.democratic-csi.nfs` |
| `truenas_host` | string | TrueNAS API endpoint | `10.9.8.20` |
| `truenas_port` | integer | API port | `443` (HTTPS) |
| `api_key` | secret | TrueNAS API key | Encrypted via SOPS |
| `nfs_share_path` | string | Base path for NFS shares | `/mnt/k8s-storage/nfs` |

**Relationships**:
- Connects to `TrueNASStorage` API
- Creates `StorageClass` resources
- Provisions `PersistentVolume` on demand

### 5. StorageClass

Kubernetes StorageClass for dynamic provisioning.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `name` | string | StorageClass name | `truenas-nfs`, `truenas-iscsi` |
| `provisioner` | string | CSI driver reference | `org.democratic-csi.nfs` |
| `reclaim_policy` | enum | PV reclaim behavior | `Delete` or `Retain` |
| `volume_binding_mode` | enum | When to bind | `Immediate` |
| `allow_expansion` | boolean | Allow PVC resize | `true` |

**Relationships**:
- Created by `DemocraticCSI`
- Referenced by `PersistentVolumeClaim`

### 6. ArgoCD

GitOps deployment managing cluster workloads.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `namespace` | string | Deployment namespace | `argocd` |
| `version` | string | ArgoCD version | `2.13.x` |
| `repo_url` | string | Git repository URL | This repository |
| `target_revision` | string | Git branch/tag | `main` |
| `sync_policy` | enum | Auto-sync behavior | `automated` with prune |

**Relationships**:
- Deploys to `TalosCluster`
- Manages `Application` resources
- Watches Git repository for changes

### 7. CiliumCNI

Container Network Interface providing pod networking.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `namespace` | string | Deployment namespace | `kube-system` |
| `version` | string | Cilium version | `1.16.x` |
| `kube_proxy_replacement` | boolean | Replace kube-proxy | `true` |
| `hubble_enabled` | boolean | Enable observability | `true` |
| `pod_cidr` | string | Pod network range | `10.244.0.0/16` |

**Relationships**:
- Runs on all `TalosNode` instances
- Provides networking for all pods
- Enforces `NetworkPolicy` resources

---

## Configuration Hierarchy

```
cloudenv/
├── Cluster Level
│   ├── talosconfig              # Talos API credentials (gitignored)
│   ├── kubeconfig               # Kubernetes API credentials (gitignored)
│   └── talossecrets.yaml.enc    # Encrypted cluster secrets (SOPS)
│
├── Node Level (per TalosNode)
│   ├── controlplane.yaml        # Base machine config (template)
│   └── patches/
│       ├── talos-cp-1.yaml      # Node-specific: hostname, IP
│       ├── talos-cp-2.yaml
│       └── talos-cp-3.yaml
│
├── Storage Level
│   ├── truenas-config.yaml      # TrueNAS initial setup reference
│   ├── democratic-csi/
│   │   ├── values.yaml          # Helm values
│   │   └── secret.enc.yaml      # API credentials (SOPS)
│   └── storage-classes.yaml     # StorageClass definitions
│
├── Networking Level
│   ├── cilium/
│   │   └── values.yaml          # Helm values
│   └── network-policies.yaml    # Default network policies
│
└── GitOps Level
    ├── argocd/
    │   ├── install.yaml         # ArgoCD deployment
    │   └── app-of-apps.yaml     # Root Application
    └── applications/            # Individual Application CRs
```

---

## State Transitions

### Cluster Lifecycle

```
[Not Exists]
    │
    ▼ (create VMs, apply machine configs)
[Bootstrapping]
    │
    ▼ (talosctl bootstrap)
[Initializing]
    │
    ▼ (etcd ready, API server ready)
[Running]
    │
    ├──▶ [Upgrading] ──▶ [Running]
    │
    ├──▶ [Degraded] ──▶ [Running] (node recovery)
    │
    └──▶ [Destroyed]
```

### Node Lifecycle

```
[Provisioned] ──▶ [Configured] ──▶ [Joined] ──▶ [Ready]
                                        │
                                        ├──▶ [NotReady] ──▶ [Ready]
                                        │
                                        ├──▶ [Cordoned] ──▶ [Ready]
                                        │
                                        └──▶ [Removed]
```

### PersistentVolume Lifecycle

```
[Available] ──▶ [Bound] ──▶ [Released] ──▶ [Available] (Retain)
                    │                           │
                    │                           └──▶ [Deleted] (Delete)
                    │
                    └──▶ [Failed]
```

---

## Validation Rules

### Network Validation
- All node IPs must be in `10.9.8.0/24` range
- VIP `10.9.8.100` must not conflict with node IPs
- Pod CIDR must not overlap with cluster network
- Service CIDR must not overlap with pod CIDR

### Resource Validation
- Total vCPU allocation ≤ 11 (host has 12, reserve 1)
- Total RAM allocation ≤ 58GB (host has ~63GB, reserve ~5GB)
- Talos nodes: minimum 2 vCPU, 4GB RAM per node
- TrueNAS: minimum 2 vCPU, 8GB RAM (16GB recommended)

### Security Validation
- All secrets must be encrypted (SOPS with age)
- No plaintext credentials in Git
- Pod Security Standards: baseline minimum
- Network policies: default deny ingress (recommended)

### High Availability Validation
- Minimum 3 control plane nodes for etcd quorum
- VIP must be accessible when any 2/3 nodes are healthy
- Storage must support ReadWriteMany for HA workloads

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Proxmox VE Host                              │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────────────┐  │
│  │ talos-cp-1│ │ talos-cp-2│ │ talos-cp-3│ │   truenas-scale     │  │
│  │ 10.9.8.11 │ │ 10.9.8.12 │ │ 10.9.8.13 │ │     10.9.8.20       │  │
│  │  3vCPU    │ │  3vCPU    │ │  3vCPU    │ │      2vCPU          │  │
│  │  14GB RAM │ │  14GB RAM │ │  14GB RAM │ │     16GB RAM        │  │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └──────────┬──────────┘  │
│        │             │             │                   │             │
│        └─────────────┼─────────────┘                   │             │
│                      │                                 │             │
│              ┌───────┴───────┐                         │             │
│              │ VIP: 10.9.8.100│                        │             │
│              │ (K8s API)      │                        │             │
│              └───────┬───────┘                         │             │
│                      │                                 │             │
└──────────────────────┼─────────────────────────────────┼─────────────┘
                       │                                 │
              virbr1 (10.9.8.0/24)                       │
                       │                                 │
         ┌─────────────┴─────────────┐                   │
         │      TalosCluster         │                   │
         │  ┌─────────────────────┐  │     NFS/iSCSI     │
         │  │      Cilium CNI     │  │◄──────────────────┘
         │  │  Pod: 10.244.0.0/16 │  │
         │  └─────────────────────┘  │
         │  ┌─────────────────────┐  │
         │  │   democratic-csi    │──┼──► TrueNAS API (443)
         │  │   StorageClasses    │  │
         │  └─────────────────────┘  │
         │  ┌─────────────────────┐  │
         │  │      ArgoCD         │──┼──► Git Repository
         │  │   (GitOps Engine)   │  │
         │  └─────────────────────┘  │
         └───────────────────────────┘
```

---

## External Dependencies

| Dependency | Version | Source | Purpose |
|------------|---------|--------|---------|
| Talos Linux | 1.9.x | factory.talos.dev | Immutable OS |
| Kubernetes | 1.31.x | Built into Talos | Container orchestration |
| Cilium | 1.16.x | quay.io/cilium | CNI + Network policies |
| democratic-csi | 0.14.x | Helm chart | TrueNAS CSI driver |
| ArgoCD | 2.13.x | argoproj | GitOps controller |
| TrueNAS Scale | 24.10.x | truenas.com | Shared storage |
| SOPS | 3.9.x | mozilla/sops | Secrets encryption |
| age | 1.2.x | filippo.io/age | Encryption key management |
