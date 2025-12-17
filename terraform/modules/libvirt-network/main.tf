# Libvirt Network Module
# Constitution III: Infrastructure as Code
# Creates isolated network for VM communication

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.0"
    }
  }
}

# Private network for VMs (no DHCP - static IPs managed by OPNsense)
resource "libvirt_network" "vmnet" {
  name      = var.network_name
  mode      = var.network_mode
  domain    = var.network_domain
  autostart = var.autostart

  addresses = [var.network_cidr]

  bridge = var.bridge_name

  # DNS configuration
  dns {
    enabled    = var.dns_enabled
    local_only = var.dns_local_only
  }

  # No DHCP - OPNsense will handle DHCP if needed
  # Static IPs are preferred for infrastructure VMs

  lifecycle {
    prevent_destroy = false
  }
}

# Optional: Create additional isolated network for management
resource "libvirt_network" "management" {
  count = var.create_management_network ? 1 : 0

  name      = "${var.network_name}-mgmt"
  mode      = "isolated"
  domain    = "mgmt.${var.network_domain}"
  autostart = var.autostart

  addresses = [var.management_network_cidr]

  bridge = "${var.bridge_name}-mgmt"

  dns {
    enabled    = false
    local_only = true
  }

  lifecycle {
    prevent_destroy = false
  }
}
