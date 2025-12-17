# Libvirt Network Module - Variables

variable "network_name" {
  description = "Name of the libvirt network"
  type        = string
  default     = "vmnet"
}

variable "network_mode" {
  description = "Network mode (nat, route, bridge, isolated)"
  type        = string
  default     = "route"

  validation {
    condition     = contains(["nat", "route", "bridge", "isolated"], var.network_mode)
    error_message = "Network mode must be one of: nat, route, bridge, isolated"
  }
}

variable "network_cidr" {
  description = "CIDR block for the network"
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.network_cidr, 0))
    error_message = "Network CIDR must be a valid IPv4 CIDR block"
  }
}

variable "network_domain" {
  description = "DNS domain for the network"
  type        = string
  default     = "cloudenv.local"
}

variable "bridge_name" {
  description = "Name of the bridge interface"
  type        = string
  default     = "virbr1"
}

variable "autostart" {
  description = "Autostart the network on host boot"
  type        = bool
  default     = true
}

variable "dns_enabled" {
  description = "Enable DNS for the network"
  type        = bool
  default     = true
}

variable "dns_local_only" {
  description = "Only resolve local DNS queries"
  type        = bool
  default     = true
}

variable "create_management_network" {
  description = "Create additional isolated management network"
  type        = bool
  default     = false
}

variable "management_network_cidr" {
  description = "CIDR block for the management network"
  type        = string
  default     = "10.0.100.0/24"
}
