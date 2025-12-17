# Proxmox VM Module Variables
# T051: VM configuration variables

# VM Resources
variable "vcpus" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 8
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 49152  # 48GB
}

variable "hostname" {
  description = "VM hostname"
  type        = string
  default     = "proxmox"
}

# Disk Configuration (T053)
variable "root_disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 100
}

variable "data_disk_size" {
  description = "Data disk size in GB for VM storage"
  type        = number
  default     = 700
}

# Network Configuration
variable "proxmox_ip" {
  description = "Static IP for Proxmox on private network"
  type        = string
  default     = "10.0.0.10"
}

variable "gateway_ip" {
  description = "Gateway IP (OPNsense LAN)"
  type        = string
  default     = "10.0.0.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["10.0.0.1", "1.1.1.1"]
}

variable "private_network_name" {
  description = "Name of the private libvirt network"
  type        = string
  default     = "private"
}

# Storage Configuration
variable "storage_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}

variable "debian_iso_url" {
  description = "URL or path to Debian 12 cloud image (for Proxmox base)"
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
}

# Authentication
variable "ssh_public_key" {
  description = "SSH public key for root access"
  type        = string
  sensitive   = true
}

variable "root_password" {
  description = "Root password (from vault)"
  type        = string
  sensitive   = true
}
