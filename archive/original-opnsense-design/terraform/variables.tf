# Input Variables for Core Infrastructure
# See data-model.md for entity definitions

#------------------------------------------------------------------------------
# Provider Configuration
#------------------------------------------------------------------------------

variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

#------------------------------------------------------------------------------
# VPS Host Configuration
#------------------------------------------------------------------------------

variable "vps_hostname" {
  description = "FQDN of the VPS host"
  type        = string
}

variable "ssh_port" {
  description = "SSH port for host access"
  type        = number
  default     = 22
}

#------------------------------------------------------------------------------
# Storage Pool Configuration
#------------------------------------------------------------------------------

variable "storage_pool_name" {
  description = "Name of the libvirt storage pool"
  type        = string
  default     = "default"
}

variable "storage_pool_path" {
  description = "Filesystem path for storage pool"
  type        = string
  default     = "/var/lib/libvirt/images"
}

#------------------------------------------------------------------------------
# Network Configuration
#------------------------------------------------------------------------------

variable "private_network_name" {
  description = "Name of the private libvirt network"
  type        = string
  default     = "vmnet-private"
}

variable "private_network_cidr" {
  description = "CIDR for private network"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_network_bridge" {
  description = "Bridge device name for private network"
  type        = string
  default     = "virbr1"
}

variable "gateway_ip" {
  description = "Gateway IP (OPNsense LAN)"
  type        = string
  default     = "10.0.0.1"
}

#------------------------------------------------------------------------------
# OPNsense VM Configuration
#------------------------------------------------------------------------------

variable "opnsense_name" {
  description = "OPNsense VM name"
  type        = string
  default     = "opnsense"
}

variable "opnsense_vcpus" {
  description = "vCPUs allocated to OPNsense"
  type        = number
  default     = 2
}

variable "opnsense_memory_mb" {
  description = "Memory in MB for OPNsense"
  type        = number
  default     = 4096
}

variable "opnsense_disk_gb" {
  description = "Root disk size in GB for OPNsense"
  type        = number
  default     = 32
}

variable "opnsense_image_source" {
  description = "URL or path to OPNsense image"
  type        = string
  default     = ""
}

variable "opnsense_wan_interface" {
  description = "Host interface for OPNsense WAN (macvtap)"
  type        = string
  default     = "eth0"
}

variable "opnsense_lan_ip" {
  description = "OPNsense LAN interface IP"
  type        = string
  default     = "10.0.0.1"
}

#------------------------------------------------------------------------------
# Proxmox VM Configuration
#------------------------------------------------------------------------------

variable "proxmox_name" {
  description = "Proxmox VM name"
  type        = string
  default     = "proxmox"
}

variable "proxmox_vcpus" {
  description = "vCPUs allocated to Proxmox"
  type        = number
  default     = 8
}

variable "proxmox_memory_mb" {
  description = "Memory in MB for Proxmox"
  type        = number
  default     = 49152  # 48GB
}

variable "proxmox_root_disk_gb" {
  description = "Root disk size in GB for Proxmox"
  type        = number
  default     = 100
}

variable "proxmox_data_disk_gb" {
  description = "Data disk size in GB for Proxmox"
  type        = number
  default     = 700
}

variable "proxmox_image_source" {
  description = "URL or path to Proxmox ISO"
  type        = string
  default     = ""
}

variable "proxmox_ip" {
  description = "Proxmox static IP address"
  type        = string
  default     = "10.0.0.10"
}

#------------------------------------------------------------------------------
# Tailscale Configuration
#------------------------------------------------------------------------------

variable "tailscale_auth_key" {
  description = "Tailscale authentication key (from vault)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_advertised_routes" {
  description = "Routes to advertise to tailnet"
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

#------------------------------------------------------------------------------
# SSH Configuration
#------------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

#------------------------------------------------------------------------------
# Proxmox Authentication
#------------------------------------------------------------------------------

variable "proxmox_root_password" {
  description = "Root password for Proxmox VM (from vault)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "debian_cloud_image_url" {
  description = "URL to Debian cloud image for Proxmox base"
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
}
