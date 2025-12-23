# Libvirt Network Module
# Constitution III: Infrastructure as Code
# Creates isolated network for VM communication
#
# Compatible with libvirt provider v0.7.x

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

# Private network for VMs
resource "libvirt_network" "vmnet" {
  name      = var.network_name
  autostart = var.autostart

  # Network forwarding mode
  mode = var.network_mode

  # Bridge configuration
  bridge = var.bridge_name

  # Domain configuration
  domain = var.network_domain

  # IP configuration with DHCP disabled
  addresses = [var.network_cidr]

  # DNS configuration
  dns {
    enabled    = var.dns_enabled
    local_only = var.dns_local_only
  }

  # DHCP disabled - static IPs only
  dhcp {
    enabled = false
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Optional management network
resource "libvirt_network" "management" {
  count = var.create_management_network ? 1 : 0

  name      = "${var.network_name}-mgmt"
  autostart = var.autostart

  # Isolated mode - no external connectivity
  mode = "isolated"

  # Bridge configuration
  bridge = "${var.bridge_name}m"

  # Domain configuration
  domain = "mgmt.${var.network_domain}"

  # IP configuration
  addresses = [var.management_network_cidr]

  # DNS disabled for management network
  dns {
    enabled    = false
    local_only = true
  }

  # DHCP disabled
  dhcp {
    enabled = false
  }

  lifecycle {
    prevent_destroy = false
  }
}
