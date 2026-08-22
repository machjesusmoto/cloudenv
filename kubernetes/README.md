# Kubernetes Cluster with Talos Linux

Production-ready 3-node Kubernetes cluster using Talos Linux as the immutable OS, with TrueNAS Scale providing shared NFS storage and ArgoCD enabling GitOps-based workload management.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Proxmox VE Host                              │
│                   (12 vCPU, 64GB RAM)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ talos-cp-1   │  │ talos-cp-2   │  │ talos-cp-3   │          │
│  │ 10.9.8.11    │  │ 10.9.8.12    │  │ 10.9.8.13    │          │
│  │ 3vCPU/14GB   │  │ 3vCPU/14GB   │  │ 3vCPU/14GB   │          │
│  │ Control Plane│  │ Control Plane│  │ Control Plane│          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └────────────┬────┴─────────────────┘                   │
│                      │                                          │
│              ┌───────┴───────┐                                  │
│              │   VIP:        │                                  │
│              │ 10.9.8.100    │                                  │
│              │ (Talos VIP)   │                                  │
│              └───────────────┘                                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    TrueNAS Scale                          │  │
│  │                    10.9.8.20                              │  │
│  │                    2vCPU/16GB                             │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  ZFS Pool: k8s-storage (200GB)                     │  │  │
│  │  │  └── Dataset: nfs (NFS share for K8s PVCs)         │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Tailscale (VPN)
                              ▼
                    ┌─────────────────┐
                    │   Remote Admin  │
                    │   kubectl/      │
                    │   talosctl      │
                    └─────────────────┘
```

## Directory Structure

```
kubernetes/
├── bootstrap/              # Initial cluster setup
│   ├── talos/              # Talos machine configs
│   │   ├── patches/        # Node-specific patches
│   │   └── controlplane.yaml.template
│   ├── truenas/            # TrueNAS setup docs
│   └── scripts/            # Bootstrap automation
│
├── core/                   # Base infrastructure (ArgoCD-managed)
│   ├── namespaces/         # Namespace definitions
│   ├── storage/            # CSI driver, StorageClasses
│   │   └── democratic-csi/
│   ├── networking/         # CNI, network policies
│   │   └── cilium/
│   └── security/           # Pod security, SOPS config
│
├── apps/                   # Applications (ArgoCD-managed)
│   ├── argocd/             # ArgoCD self-management
│   └── monitoring/         # Prometheus/Grafana (P3)
│
└── tests/                  # Validation tests
    ├── smoke/              # Quick health checks
    └── integration/        # Full stack tests
```

## Prerequisites

### Required Tools

```bash
# Talos CLI
curl -sL https://talos.dev/install | sh

# Kubernetes CLI
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# SOPS and age for secrets encryption
# Arch: pacman -S sops age
# Ubuntu: snap install sops; apt install age

# Helm for CNI and CSI installation
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Required Access

- Proxmox VE web UI (via Tailscale)
- Tailscale network access to 10.9.8.0/24 subnet

## Quick Start

See [quickstart.md](../specs/001-k8s-talos-cluster/quickstart.md) for detailed step-by-step deployment instructions.

### TL;DR

```bash
# 1. Bootstrap cluster (after TrueNAS and VMs are ready)
./bootstrap/scripts/generate-configs.sh
./bootstrap/scripts/bootstrap-cluster.sh

# 2. Verify cluster health
./tests/smoke/cluster-health.sh

# 3. Access cluster
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

## Complete Deployment Guide

### Phase 1: Prerequisites

1. **Install Required Tools**:
   ```bash
   # Talos CLI
   curl -sL https://talos.dev/install | sh

   # kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl && sudo mv kubectl /usr/local/bin/

   # Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

   # SOPS and age (Arch Linux)
   sudo pacman -S sops age
   ```

2. **Configure Tailscale Access**:
   - Ensure Tailscale is connected
   - Verify 10.9.8.0/24 subnet is accessible
   ```bash
   tailscale ping 10.9.8.20  # Test TrueNAS
   ```

### Phase 2: TrueNAS Setup

1. **Create TrueNAS VM** in Proxmox:
   - VM ID: 200
   - 2 vCPU, 16GB RAM
   - 100GB OS disk + 200GB storage disk
   - Static IP: 10.9.8.20/24

2. **Configure Storage**:
   - Create ZFS pool `k8s-storage` on second disk
   - Create dataset `k8s-storage/nfs` with LZ4 compression
   - Configure NFS share for 10.9.8.0/24

3. **Generate API Key**:
   - TrueNAS UI → API Keys → Add
   - Name: `k8s-csi`
   - Save key securely (will be encrypted with SOPS)

See [bootstrap/truenas/VM-SETUP.md](bootstrap/truenas/VM-SETUP.md) for details.

### Phase 3: Kubernetes Cluster Bootstrap

1. **Create Talos VMs** in Proxmox (VM IDs 201-203):
   ```
   talos-cp-1: 10.9.8.11 (3 vCPU, 14GB RAM, 50GB)
   talos-cp-2: 10.9.8.12 (3 vCPU, 14GB RAM, 50GB)
   talos-cp-3: 10.9.8.13 (3 vCPU, 14GB RAM, 50GB)
   ```

2. **Generate Cluster Secrets**:
   ```bash
   cd kubernetes/bootstrap/talos
   talosctl gen secrets -o secrets.yaml
   ```

3. **Encrypt Secrets with SOPS**:
   ```bash
   # Generate age key (first time only)
   age-keygen -o ~/.config/sops/age/keys.txt

   # Encrypt secrets
   sops --encrypt secrets.yaml > talossecrets.yaml.enc
   rm secrets.yaml
   ```

4. **Generate and Apply Configurations**:
   ```bash
   ./bootstrap/scripts/generate-configs.sh
   # Apply to each node in maintenance mode
   ```

5. **Bootstrap Cluster**:
   ```bash
   ./bootstrap/scripts/bootstrap-cluster.sh
   ```

6. **Install Cilium CNI**:
   ```bash
   ./bootstrap/scripts/install-cilium.sh
   ```

7. **Verify Cluster**:
   ```bash
   ./tests/smoke/cluster-health.sh
   kubectl get nodes
   ```

### Phase 4: Storage Setup

1. **Encrypt TrueNAS Credentials**:
   ```bash
   cd kubernetes/core/storage/democratic-csi
   # Edit driver-config-secret.yaml with API key
   sops --encrypt driver-config-secret.yaml > driver-config-secret.enc.yaml
   rm driver-config-secret.yaml
   ```

2. **Install democratic-csi**:
   ```bash
   # Create namespace
   kubectl apply -f namespace.yaml

   # Apply encrypted secret
   sops --decrypt driver-config-secret.enc.yaml | kubectl apply -f -

   # Add Helm repo and install
   helm repo add democratic-csi https://democratic-csi.github.io/charts/
   helm install democratic-csi democratic-csi/democratic-csi \
     -n democratic-csi -f values.yaml

   # Apply StorageClass
   kubectl apply -f storageclass.yaml
   ```

3. **Verify Storage**:
   ```bash
   ./tests/smoke/storage-test.sh
   ```

### Phase 5: GitOps with ArgoCD

1. **Install ArgoCD**:
   ```bash
   ./bootstrap/scripts/install-argocd.sh
   ```

2. **Access ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access https://localhost:8080

   # Get admin password
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d && echo
   ```

3. **Deploy App-of-Apps**:
   ```bash
   kubectl apply -f kubernetes/apps/argocd/app-of-apps.yaml
   ```

4. **Verify ArgoCD**:
   ```bash
   ./tests/smoke/argocd-test.sh
   ```

### Phase 6: Validate Remote Access

```bash
# From Tailscale-connected device
./tests/smoke/access-test.sh

# Manual verification
talosctl health --nodes 10.9.8.100
kubectl get nodes
kubectl get pods -A
```

## Runbooks

### Daily Operations

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# View recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Backup Procedures

```bash
# Backup etcd (run from control plane)
talosctl etcd snapshot kubernetes/backup/etcd-$(date +%Y%m%d).snapshot \
  --nodes 10.9.8.11

# Backup ArgoCD
kubectl get applications -n argocd -o yaml > kubernetes/backup/argocd-apps.yaml
```

### Disaster Recovery

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and recovery procedures.

## Components

| Component | Version | Purpose |
|-----------|---------|---------|
| Talos Linux | 1.9.x | Immutable Kubernetes OS |
| Kubernetes | 1.31.x | Container orchestration |
| Cilium | 1.16+ | CNI with kube-proxy replacement |
| TrueNAS Scale | 24.10+ | NFS storage backend |
| democratic-csi | 0.14+ | CSI driver for TrueNAS |
| ArgoCD | 2.13+ | GitOps controller |

## Network Configuration

| Resource | IP Address | Purpose |
|----------|------------|---------|
| talos-cp-1 | 10.9.8.11 | Control plane node 1 |
| talos-cp-2 | 10.9.8.12 | Control plane node 2 |
| talos-cp-3 | 10.9.8.13 | Control plane node 3 |
| Kubernetes VIP | 10.9.8.100 | Talos-managed API VIP |
| TrueNAS | 10.9.8.20 | Storage backend |
| Pod CIDR | 10.244.0.0/16 | Pod network |
| Service CIDR | 10.96.0.0/12 | Service network |

## Security

- **No SSH**: Talos is API-only (talosctl)
- **Encrypted Secrets**: SOPS with age encryption
- **Network Isolation**: Tailscale-only access
- **GitOps**: All changes via Git + ArgoCD

## Troubleshooting

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.

## Related Documentation

- [Specification](../specs/001-k8s-talos-cluster/spec.md)
- [Implementation Plan](../specs/001-k8s-talos-cluster/plan.md)
- [Quickstart Guide](../specs/001-k8s-talos-cluster/quickstart.md)
