# Kubernetes Cluster Terraform Infrastructure

Automated deployment of a production-ready Kubernetes cluster using Talos Linux on Proxmox VE.

## Overview

This Terraform configuration automates the complete cluster lifecycle:

1. **TrueNAS VM Creation** - Storage backend for persistent volumes
2. **Talos VM Provisioning** - Control plane and worker nodes
3. **Cluster Bootstrap** - Talos secrets, config application, etcd bootstrap
4. **CNI Installation** - Cilium with kube-proxy replacement
5. **Storage Setup** - Democratic CSI for TrueNAS integration
6. **GitOps Platform** - ArgoCD for declarative workload management

## Prerequisites

### Required Tools

```bash
# Terraform
curl -fsSL https://releases.hashicorp.com/terraform/1.9.0/terraform_1.9.0_linux_amd64.zip -o /tmp/tf.zip
unzip /tmp/tf.zip -d ~/.local/bin

# Talosctl (for verification)
curl -sL https://talos.dev/install | sh

# kubectl (for verification)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl ~/.local/bin/
```

### Proxmox Requirements

1. **Proxmox VE 8.x** with API access enabled
2. **API Token** with required permissions:
   - `VM.Allocate`
   - `VM.Clone`
   - `VM.Config.*`
   - `VM.PowerMgmt`
   - `Datastore.AllocateSpace`
   - `Sys.Modify` (for ISO upload)

3. **Storage Pools**:
   - LVM or ZFS storage for VM disks
   - ISO storage for boot images

4. **Network Bridge** (typically `vmbr0`)

### Create Proxmox API Token

```bash
# Via Proxmox UI:
# Datacenter → Permissions → API Tokens → Add
# User: root@pam (or dedicated user)
# Token ID: terraform
# Privilege Separation: Unchecked (for simplicity)

# Note the Token ID and Secret
```

## Quick Start

### 1. Initialize Terraform

```bash
cd kubernetes/terraform
terraform init
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

**Required Variables:**
- `proxmox_endpoint` - Proxmox API URL
- `proxmox_api_token` - API token (format: `user@realm!tokenid=secret`)
- `proxmox_node` - Proxmox node name

### 3. Upload TrueNAS ISO (Manual Step)

Download TrueNAS Scale ISO and upload to Proxmox:

```bash
# Download
wget https://download.truenas.com/TrueNAS-SCALE-Dragonfish/24.10.2/TrueNAS-SCALE-24.10.2.iso

# Upload via Proxmox UI or:
scp TrueNAS-SCALE-24.10.2.iso root@proxmox:/var/lib/vz/template/iso/
```

### 4. Deploy Infrastructure

```bash
# Preview changes
terraform plan

# Apply (creates VMs, bootstraps cluster)
terraform apply
```

### 5. Verify Deployment

```bash
# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -A

# Check Talos health
talosctl health
```

## Phased Deployment

For more control, use targeted deployment:

### Phase 1: TrueNAS Only

```bash
terraform apply -target=proxmox_virtual_machine.truenas
```

After TrueNAS boots, manually:
1. Complete TrueNAS setup wizard
2. Create ZFS pool `k8s-storage`
3. Create dataset `k8s-storage/nfs`
4. Configure NFS share
5. Generate API key

### Phase 2: Talos Cluster

```bash
# Add API key to terraform.tfvars
# truenas_api_key = "your-api-key-here"

terraform apply -target=proxmox_virtual_machine.controlplane \
                -target=talos_machine_secrets.this
```

### Phase 3: Bootstrap & Configure

```bash
terraform apply
```

## Configuration Reference

### Control Plane Nodes

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cpu` | 3 | vCPU count |
| `memory` | 14336 | Memory in MB |
| `disk` | 50 | Disk size in GB |
| `ip` | varies | Static IP address |

### Network Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `network_gateway` | 10.9.8.1 | Default gateway |
| `network_dns` | [10.9.8.1, 1.1.1.1] | DNS servers |
| `network_cidr` | 24 | Subnet prefix length |
| `cluster_vip` | 10.9.8.100 | Talos VIP for HA |

### Component Versions

| Component | Version | Variable |
|-----------|---------|----------|
| Talos Linux | v1.9.1 | `talos_version` |
| Kubernetes | 1.31.4 | `kubernetes_version` |
| Cilium | 1.16.5 | `cilium_version` |
| Democratic CSI | 0.14.7 | `democratic_csi_version` |
| ArgoCD | 7.7.16 | `argocd_version` |

## Outputs

After deployment, key outputs include:

```bash
# View all outputs
terraform output

# Get kubeconfig
terraform output -raw kubeconfig > ~/.kube/config

# Get talosconfig
terraform output -raw talos_client_configuration

# Get access instructions
terraform output access_instructions
```

## State Management

### Remote Backend (Recommended)

For team collaboration, configure remote backend in `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "k8s-cluster/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### State Backup

```bash
# Backup state before major changes
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d)
```

## Troubleshooting

### VM Creation Fails

```bash
# Check Proxmox task log
pvesh get /nodes/pve/tasks

# Verify API token permissions
pveum acl list
```

### Talos Bootstrap Timeout

```bash
# Check node status
talosctl -n 10.9.8.11 dmesg | tail -50

# Check machine config
talosctl -n 10.9.8.11 get machineconfig
```

### Cilium Installation Fails

```bash
# Check Cilium pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# Check Cilium status
kubectl exec -n kube-system ds/cilium -- cilium status
```

### CSI Driver Issues

```bash
# Check CSI pods
kubectl get pods -n democratic-csi

# Test PVC creation
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: truenas-nfs
  resources:
    requests:
      storage: 1Gi
EOF
```

## Destroy Infrastructure

```bash
# Remove everything (DESTRUCTIVE!)
terraform destroy

# Or remove specific components
terraform destroy -target=helm_release.argocd
terraform destroy -target=helm_release.democratic_csi
```

## Security Considerations

1. **Never commit `terraform.tfvars`** - Contains API tokens
2. **Encrypt state file** - Use remote backend with encryption
3. **Rotate API tokens** - Periodically regenerate Proxmox tokens
4. **Backup secrets** - Store `talos_machine_secrets` output securely

## Integration with Manual Steps

Some steps still require manual intervention:

| Task | Reason |
|------|--------|
| TrueNAS initial setup | Web UI required for wizard completion |
| ZFS pool creation | Hardware-dependent configuration |
| TrueNAS API key | Generated after TrueNAS is running |
| SOPS key management | Security-sensitive key generation |

These are handled by the bootstrap scripts in `../bootstrap/scripts/`.

## File Structure

```
terraform/
├── versions.tf          # Provider version constraints
├── providers.tf         # Provider configurations
├── variables.tf         # Input variables
├── main.tf              # Main infrastructure resources
├── outputs.tf           # Output values
├── terraform.tfvars.example  # Example configuration
└── README.md            # This file
```
