# OPNsense VM Module - Variables

variable "vm_name" {
  description = "Name of the OPNsense VM"
  type        = string
  default     = "opnsense"
}

variable "memory" {
  description = "Memory allocation in MB"
  type        = number
  default     = 4096

  validation {
    condition     = var.memory >= 2048
    error_message = "OPNsense requires at least 2048MB of RAM"
  }
}

variable "vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 2

  validation {
    condition     = var.vcpu >= 1
    error_message = "At least 1 vCPU is required"
  }
}

variable "disk_size" {
  description = "Root disk size in bytes"
  type        = number
  default     = 34359738368  # 32GB

  validation {
    condition     = var.disk_size >= 10737418240  # 10GB minimum
    error_message = "Disk size must be at least 10GB"
  }
}

variable "storage_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}

variable "iso_path" {
  description = "Path to OPNsense installation ISO"
  type        = string
  default     = "/var/lib/libvirt/iso/OPNsense.iso"
}

variable "iso_url" {
  description = "URL to download OPNsense ISO"
  type        = string
  default     = "https://mirror.wdc1.us.leaseweb.net/opnsense/releases/24.7/OPNsense-24.7-vga-amd64.img.bz2"
}

variable "download_iso" {
  description = "Download ISO if not present"
  type        = bool
  default     = false
}

variable "boot_from_iso" {
  description = "Boot from ISO for initial installation"
  type        = bool
  default     = true
}

variable "wan_interface" {
  description = "Physical interface name for macvtap WAN"
  type        = string
}

variable "wan_mac_address" {
  description = "MAC address for WAN interface (optional)"
  type        = string
  default     = null
}

variable "lan_network_id" {
  description = "Libvirt network ID for LAN interface"
  type        = string
}

variable "lan_mac_address" {
  description = "MAC address for LAN interface (optional)"
  type        = string
  default     = null
}

variable "use_cloudinit" {
  description = "Use cloud-init for initial configuration"
  type        = bool
  default     = false
}

variable "cloudinit_user_data" {
  description = "Cloud-init user data"
  type        = string
  default     = ""
}

variable "use_uefi" {
  description = "Use UEFI firmware"
  type        = bool
  default     = false
}

# LAN IP configuration (for outputs and documentation)
variable "lan_ip" {
  description = "LAN interface IP address"
  type        = string
  default     = "10.0.0.1"
}

variable "lan_netmask" {
  description = "LAN interface netmask"
  type        = string
  default     = "255.255.255.0"
}
