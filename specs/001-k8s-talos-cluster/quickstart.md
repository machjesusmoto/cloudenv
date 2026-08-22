# Quickstart: Kubernetes Cluster with Talos Linux

**Date**: 2025-12-24 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Deploy a 3-node Kubernetes cluster with Talos Linux, TrueNAS storage, and ArgoCD GitOps.

---

## Prerequisites

### Required Tools
```bash
# Install talosctl
curl -sL https://talos.dev/install | sh

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Install SOPS and age (for secrets)
# Arch: pacman -S sops age
# Ubuntu: snap install sops; apt install age

# Install Helm (for democratic-csi and Cilium)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
talosctl version --client
kubectl version --client
sops --version
age --version
helm version
```

### Required Access
- Proxmox VE web UI (https://100.84.93.46:8006 via Tailscale)
- Tailscale network access to 10.9.8.0/24

### Required Downloads
1. **Talos ISO**: Visit [factory.talos.dev](https://factory.talos.dev)
   - Version: 1.9.x
   - Platform: metal, amd64
   - Extension: `siderolabs/qemu-guest-agent`
   - Download: `metal-amd64.iso`

2. **TrueNAS Scale ISO**: Download from [truenas.com/download-truenas-scale](https://www.truenas.com/download-truenas-scale/)
   - Version: 24.10.x (DragonFish)

---

## Phase 1: VM Provisioning (Proxmox)

### Step 1.1: Upload ISOs
```bash
# In Proxmox UI: Datacenter > pve-vps > local > ISO Images > Upload
# Upload: talos-metal-amd64.iso, TrueNAS-SCALE-24.10.x.iso
```

### Step 1.2: Create TrueNAS VM

| Setting | Value |
|---------|-------|
| VM ID | 200 |
| Name | truenas-scale |
| ISO | TrueNAS-SCALE-24.10.x.iso |
| OS Type | Linux 6.x |
| CPU | 2 cores (host type) |
| RAM | 16384 MB |
| Disk 1 (OS) | 100 GB, VirtIO SCSI |
| Disk 2 (Pool) | 200 GB, VirtIO SCSI |
| Network | vmbr1, VirtIO |

```bash
# After creation, boot and install TrueNAS Scale
# Set static IP: 10.9.8.20/24, Gateway: 10.9.8.1
# Web UI: https://10.9.8.20
```

### Step 1.3: Create Talos VMs

Create 3 VMs with identical settings:

| Setting | talos-cp-1 | talos-cp-2 | talos-cp-3 |
|---------|------------|------------|------------|
| VM ID | 201 | 202 | 203 |
| Name | talos-cp-1 | talos-cp-2 | talos-cp-3 |
| ISO | talos-metal-amd64.iso |
| OS Type | Linux 6.x |
| CPU | 3 cores (host type) |
| RAM | 14336 MB (ballooning enabled) |
| Disk | 50 GB, VirtIO SCSI |
| Network | vmbr1, VirtIO |

```bash
# Boot VMs - they will wait for machine config
# Note maintenance mode IPs from console (DHCP or link-local)
```

---

## Phase 2: TrueNAS Configuration

### Step 2.1: Initial Setup
1. Access TrueNAS UI: https://10.9.8.20
2. Set admin password
3. Configure network: System Settings > Network
   - Static IP: 10.9.8.20/24
   - Gateway: 10.9.8.1
   - DNS: 10.9.8.1, 1.1.1.1

### Step 2.2: Create Storage Pool
1. Storage > Create Pool
   - Name: `k8s-storage`
   - Add disk: second 200GB disk
   - Layout: Stripe (single disk)

### Step 2.3: Create NFS Dataset
1. Storage > k8s-storage > Add Dataset
   - Name: `nfs`
   - Compression: LZ4
   - Quota: 180 GiB

### Step 2.4: Configure NFS Share
1. Shares > UNIX Shares (NFS) > Add
   - Path: `/mnt/k8s-storage/nfs`
   - Maproot User: root
   - Maproot Group: wheel
   - Networks: `10.9.8.0/24`
2. Services > NFS > Enable, Start Automatically

### Step 2.5: Create API Key
1. Credentials > Local Users > root > API Keys > Add
   - Name: `k8s-csi`
   - Save the key securely (needed for democratic-csi)

---

## Phase 3: Talos Cluster Bootstrap

### Step 3.1: Generate Cluster Secrets
```bash
# Create working directory
mkdir -p ~/cloudenv-k8s && cd ~/cloudenv-k8s

# Generate secrets (do this ONCE, store securely)
talosctl gen secrets -o secrets.yaml

# Encrypt secrets for Git storage
sops --encrypt secrets.yaml > secrets.enc.yaml
rm secrets.yaml  # Remove plaintext
```

### Step 3.2: Generate Machine Configs
```bash
# Generate configs using secrets
talosctl gen config cloudenv-k8s https://10.9.8.100:6443 \
  --with-secrets secrets.enc.yaml \
  --output-dir ./configs \
  --config-patch @patches/common.yaml

# Generated files:
# - configs/controlplane.yaml
# - configs/worker.yaml (not used - all nodes are control plane)
# - configs/talosconfig
```

### Step 3.3: Create Node Patches
```bash
mkdir -p patches

# Node 1 patch
cat > patches/talos-cp-1.yaml << 'EOF'
machine:
  network:
    hostname: talos-cp-1
    interfaces:
      - interface: eth0
        addresses:
          - 10.9.8.11/24
EOF

# Node 2 patch
cat > patches/talos-cp-2.yaml << 'EOF'
machine:
  network:
    hostname: talos-cp-2
    interfaces:
      - interface: eth0
        addresses:
          - 10.9.8.12/24
EOF

# Node 3 patch
cat > patches/talos-cp-3.yaml << 'EOF'
machine:
  network:
    hostname: talos-cp-3
    interfaces:
      - interface: eth0
        addresses:
          - 10.9.8.13/24
EOF
```

### Step 3.4: Apply Machine Configs
```bash
# Apply config to each node (use maintenance mode IPs from console)
talosctl apply-config --insecure \
  --nodes <NODE1_MAINTENANCE_IP> \
  --file configs/controlplane.yaml \
  --config-patch @patches/talos-cp-1.yaml

talosctl apply-config --insecure \
  --nodes <NODE2_MAINTENANCE_IP> \
  --file configs/controlplane.yaml \
  --config-patch @patches/talos-cp-2.yaml

talosctl apply-config --insecure \
  --nodes <NODE3_MAINTENANCE_IP> \
  --file configs/controlplane.yaml \
  --config-patch @patches/talos-cp-3.yaml

# Nodes will reboot and configure themselves
```

### Step 3.5: Bootstrap Cluster
```bash
# Configure talosctl to use the generated config
export TALOSCONFIG=./configs/talosconfig

# Wait for nodes to be ready (check console for IP assignment)
# Then bootstrap on ONE node only
talosctl bootstrap --nodes 10.9.8.11

# Monitor bootstrap progress
talosctl --nodes 10.9.8.11 dmesg --follow
```

### Step 3.6: Get Kubeconfig
```bash
# Generate kubeconfig
talosctl kubeconfig --nodes 10.9.8.11 ./kubeconfig

# Verify cluster access
export KUBECONFIG=./kubeconfig
kubectl get nodes

# Expected output:
# NAME         STATUS     ROLES           AGE   VERSION
# talos-cp-1   NotReady   control-plane   1m    v1.31.4
# talos-cp-2   NotReady   control-plane   1m    v1.31.4
# talos-cp-3   NotReady   control-plane   1m    v1.31.4
# (NotReady until CNI installed)
```

---

## Phase 4: CNI Installation (Cilium)

### Step 4.1: Add Helm Repository
```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

### Step 4.2: Install Cilium
```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=10.9.8.100 \
  --set k8sServicePort=6443 \
  --set ipam.mode=kubernetes \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true

# Wait for Cilium to be ready
kubectl -n kube-system wait --for=condition=ready pod -l k8s-app=cilium --timeout=300s

# Verify nodes are Ready
kubectl get nodes
# All nodes should now show Ready status
```

---

## Phase 5: Storage Installation (democratic-csi)

### Step 5.1: Create Namespace and Secret
```bash
kubectl create namespace democratic-csi

# Create secret with TrueNAS credentials
cat > democratic-csi-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: democratic-csi-driver-config
  namespace: democratic-csi
type: Opaque
stringData:
  driver-config-file.yaml: |
    driver: freenas-nfs
    instance_id: truenas-nfs
    httpConnection:
      protocol: https
      host: 10.9.8.20
      port: 443
      apiKey: "<YOUR_TRUENAS_API_KEY>"
      allowInsecure: true
      apiVersion: 2
    zfs:
      datasetParentName: k8s-storage/nfs
      datasetEnableQuotas: true
      datasetPermissionsMode: "0770"
      datasetPermissionsUser: root
      datasetPermissionsGroup: wheel
    nfs:
      shareHost: 10.9.8.20
      shareAllowedNetworks:
        - 10.9.8.0/24
      shareMaprootUser: root
      shareMaprootGroup: wheel
EOF

# Encrypt and apply
sops --encrypt democratic-csi-secret.yaml > democratic-csi-secret.enc.yaml
kubectl apply -f democratic-csi-secret.yaml
rm democratic-csi-secret.yaml  # Remove plaintext
```

### Step 5.2: Install democratic-csi
```bash
helm repo add democratic-csi https://democratic-csi.github.io/charts/
helm repo update

helm install democratic-csi democratic-csi/democratic-csi \
  --namespace democratic-csi \
  --set csiDriver.name=org.democratic-csi.nfs \
  --set driver.existingConfigSecret=democratic-csi-driver-config \
  --set driver.config.driver=freenas-nfs \
  --set storageClasses[0].name=truenas-nfs \
  --set storageClasses[0].defaultClass=true \
  --set storageClasses[0].reclaimPolicy=Delete \
  --set storageClasses[0].allowVolumeExpansion=true

# Verify installation
kubectl -n democratic-csi get pods
kubectl get storageclass
```

### Step 5.3: Test Storage
```bash
# Create test PVC
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: truenas-nfs
EOF

# Verify PVC is bound
kubectl get pvc test-pvc
# STATUS should be "Bound"

# Cleanup test
kubectl delete pvc test-pvc
```

---

## Phase 6: GitOps Installation (ArgoCD)

### Step 6.1: Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s
```

### Step 6.2: Get Admin Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # Add newline
```

### Step 6.3: Access ArgoCD UI
```bash
# Port forward (from Tailscale-connected machine)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access: https://localhost:8080
# Username: admin
# Password: (from Step 6.2)
```

### Step 6.4: Create App-of-Apps (Optional)
```bash
# After pushing kubernetes/ manifests to Git repo
cat << 'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<OWNER>/cloudenv.git
    targetRevision: main
    path: kubernetes/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

---

## Verification Checklist

### Cluster Health
```bash
# All nodes Ready
kubectl get nodes -o wide

# All system pods Running
kubectl get pods -A

# Talos health check
talosctl --nodes 10.9.8.11,10.9.8.12,10.9.8.13 health

# Etcd health
talosctl --nodes 10.9.8.11 etcd status
```

### Storage Health
```bash
# StorageClass available
kubectl get storageclass

# CSI driver healthy
kubectl -n democratic-csi get pods

# Test PVC creation
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: verify-pvc
spec:
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 100Mi
  storageClassName: truenas-nfs
EOF
kubectl get pvc verify-pvc  # Should be Bound
kubectl delete pvc verify-pvc
```

### Network Health
```bash
# Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status

# Hubble connectivity (if enabled)
kubectl -n kube-system port-forward svc/hubble-ui 12000:80 &
# Access: http://localhost:12000
```

### ArgoCD Health
```bash
# ArgoCD status
kubectl -n argocd get pods
kubectl -n argocd get applications
```

---

## Troubleshooting

### Talos Issues
```bash
# Check node logs
talosctl --nodes 10.9.8.11 dmesg | tail -100

# Check kubelet logs
talosctl --nodes 10.9.8.11 logs kubelet

# Reset node (if needed)
talosctl --nodes 10.9.8.11 reset --graceful=false
```

### Storage Issues
```bash
# Check CSI driver logs
kubectl -n democratic-csi logs -l app=democratic-csi-controller

# Verify TrueNAS connectivity
kubectl -n democratic-csi exec -it deploy/democratic-csi-controller -- \
  curl -k https://10.9.8.20/api/v2.0/system/info

# Check NFS mount on node
talosctl --nodes 10.9.8.11 read /proc/mounts | grep nfs
```

### Network Issues
```bash
# Check Cilium status
kubectl -n kube-system exec -it ds/cilium -- cilium status --verbose

# Test pod connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://kubernetes.default.svc
```

---

## Next Steps

1. **Configure SOPS**: Set up age keys and `.sops.yaml` for secrets encryption
2. **Push to Git**: Commit all manifests to repository
3. **Enable GitOps**: Configure ArgoCD to manage cluster from Git
4. **Add Workloads**: Deploy applications via ArgoCD Applications
5. **Monitoring (P3)**: Deploy Prometheus/Grafana stack

---

## File Locations Summary

| File | Location | Notes |
|------|----------|-------|
| talosconfig | `~/.talos/config` or local | Talos API access |
| kubeconfig | `~/.kube/config` or local | Kubernetes API access |
| secrets.enc.yaml | Git repo (encrypted) | Cluster secrets |
| Machine configs | Git repo | controlplane.yaml + patches |
| Helm values | Git repo | Cilium, democratic-csi |
| ArgoCD apps | Git repo | kubernetes/apps/ |
