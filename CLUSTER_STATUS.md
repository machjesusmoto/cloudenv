# CloudEnv Talos Kubernetes Cluster Status

## Cluster Overview

| Component | Status | Details |
|-----------|--------|---------|
| Proxmox Host | vmhost-cloud1 | 10.0.0.1, Tailscale 100.84.93.46 |
| Talos Version | v1.12.0 | Upgraded from v1.9.1 |
| Kubernetes Version | v1.31.4 | |
| CNI | Cilium v1.17.1 | kube-proxy replacement enabled |
| ArgoCD | Deployed | v7.x (Helm chart) |
| Control Plane | 3 nodes HA | All Ready |

## Node Information

| Node | IP | Role | Status |
|------|-----|------|--------|
| talos-cp-1 | 10.0.0.11 | control-plane | Ready |
| talos-cp-2 | 10.0.0.12 | control-plane | Ready |
| talos-cp-3 | 10.0.0.13 | control-plane | Ready |

## Network Configuration

- **Cluster VIP**: 10.0.0.100
- **Pod CIDR**: 10.244.0.0/16 (default)
- **Service CIDR**: 10.96.0.0/12 (default)
- **kubePrism Port**: 7445 (localhost)

## Access Information

### Talos API
```bash
talosctl --nodes 10.0.0.11 health
talosctl --nodes 10.0.0.100 dashboard
```

### Kubernetes API
```bash
kubectl get nodes
kubectl cluster-info
```

### ArgoCD
```bash
# Port forward to access UI
kubectl port-forward service/argocd-server -n argocd 8080:443

# Login credentials
# Username: admin
# Password: <ARGOCD_ADMIN_PASSWORD>
```

## Pending Tasks

### TrueNAS Setup (Manual)
- VM 200 running at 10.0.0.2 (needs console access)
- Complete initial TrueNAS Scale configuration:
  - Set admin password
  - Configure network (10.0.0.2/24, gateway 10.0.0.1)
  - Create storage pool from /dev/sdb
  - Enable iSCSI service
  - Configure API access for Democratic CSI

### Democratic CSI Installation
- Requires TrueNAS API access
- Will provide persistent storage for cluster workloads

## Configuration Files

- Talos configs: `/tmp/talos-configs/`
- Talosconfig: `~/.talos/config`
- Kubeconfig: `~/.kube/config`

## Created: 2025-12-26
