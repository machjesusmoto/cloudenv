# Input Variables for Kubernetes Cluster Infrastructure
# All sensitive values should be provided via terraform.tfvars or environment variables

# ============================================================================
# Proxmox Configuration
# ============================================================================

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL"
  type        = string
  default     = "https://proxmox.local:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format 'user@realm!tokenid=secret'"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_iso_storage" {
  description = "Proxmox storage pool for ISO images"
  type        = string
  default     = "local"
}

variable "proxmox_bridge" {
  description = "Proxmox network bridge name"
  type        = string
  default     = "vmbr0"
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "network_gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "10.9.8.1"
}

variable "network_dns" {
  description = "DNS server IP addresses"
  type        = list(string)
  default     = ["10.9.8.1", "1.1.1.1"]
}

variable "network_cidr" {
  description = "Network CIDR prefix length"
  type        = number
  default     = 24
}

# ============================================================================
# TrueNAS Configuration
# ============================================================================

variable "truenas_enabled" {
  description = "Whether to deploy TrueNAS VM"
  type        = bool
  default     = true
}

variable "truenas_vmid" {
  description = "Proxmox VM ID for TrueNAS"
  type        = number
  default     = 200
}

variable "truenas_ip" {
  description = "TrueNAS static IP address"
  type        = string
  default     = "10.9.8.20"
}

variable "truenas_cpu" {
  description = "TrueNAS vCPU count"
  type        = number
  default     = 2
}

variable "truenas_memory" {
  description = "TrueNAS memory in MB"
  type        = number
  default     = 16384
}

variable "truenas_os_disk_size" {
  description = "TrueNAS OS disk size in GB"
  type        = number
  default     = 100
}

variable "truenas_data_disk_size" {
  description = "TrueNAS data disk size in GB"
  type        = number
  default     = 200
}

variable "truenas_iso" {
  description = "TrueNAS Scale ISO filename"
  type        = string
  default     = "TrueNAS-SCALE-24.10.2.iso"
}

# ============================================================================
# Talos Cluster Configuration
# ============================================================================

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.9.1"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.4"
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "talos-cluster"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint (VIP)"
  type        = string
  default     = "https://10.9.8.100:6443"
}

variable "cluster_vip" {
  description = "Talos VIP for control plane HA"
  type        = string
  default     = "10.9.8.100"
}

# ============================================================================
# Control Plane Nodes
# ============================================================================

variable "controlplane_nodes" {
  description = "Control plane node configurations"
  type = list(object({
    name   = string
    vmid   = number
    ip     = string
    cpu    = optional(number, 3)
    memory = optional(number, 14336)
    disk   = optional(number, 50)
  }))
  default = [
    {
      name   = "talos-cp-1"
      vmid   = 201
      ip     = "10.9.8.11"
      cpu    = 3
      memory = 14336
      disk   = 50
    },
    {
      name   = "talos-cp-2"
      vmid   = 202
      ip     = "10.9.8.12"
      cpu    = 3
      memory = 14336
      disk   = 50
    },
    {
      name   = "talos-cp-3"
      vmid   = 203
      ip     = "10.9.8.13"
      cpu    = 3
      memory = 14336
      disk   = 50
    }
  ]
}

# ============================================================================
# Worker Nodes (Optional)
# ============================================================================

variable "worker_nodes" {
  description = "Worker node configurations (empty for control-plane-only cluster)"
  type = list(object({
    name   = string
    vmid   = number
    ip     = string
    cpu    = optional(number, 4)
    memory = optional(number, 8192)
    disk   = optional(number, 100)
  }))
  default = []
}

# ============================================================================
# Cilium CNI Configuration
# ============================================================================

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.16.5"
}

variable "cilium_kube_proxy_replacement" {
  description = "Enable Cilium kube-proxy replacement"
  type        = bool
  default     = true
}

# ============================================================================
# Democratic CSI Configuration
# ============================================================================

variable "democratic_csi_enabled" {
  description = "Whether to deploy democratic-csi for TrueNAS storage"
  type        = bool
  default     = true
}

variable "democratic_csi_version" {
  description = "Democratic CSI Helm chart version"
  type        = string
  default     = "0.14.7"
}

variable "truenas_api_key" {
  description = "TrueNAS API key for CSI driver"
  type        = string
  sensitive   = true
  default     = ""
}

variable "truenas_nfs_dataset" {
  description = "TrueNAS NFS dataset path"
  type        = string
  default     = "k8s-storage/nfs"
}

# ============================================================================
# ArgoCD Configuration
# ============================================================================

variable "argocd_enabled" {
  description = "Whether to deploy ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.16"
}

variable "argocd_namespace" {
  description = "ArgoCD namespace"
  type        = string
  default     = "argocd"
}

# ============================================================================
# Output Paths
# ============================================================================

variable "output_dir" {
  description = "Directory for generated configuration files"
  type        = string
  default     = "../bootstrap/talos/configurations"
}

variable "kubeconfig_path" {
  description = "Path to save kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "talosconfig_path" {
  description = "Path to save talosconfig file"
  type        = string
  default     = "~/.talos/config"
}
