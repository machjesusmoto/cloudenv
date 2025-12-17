# Libvirt Network Module - Outputs

output "network_id" {
  description = "ID of the created network"
  value       = libvirt_network.vmnet.id
}

output "network_name" {
  description = "Name of the created network"
  value       = libvirt_network.vmnet.name
}

output "network_bridge" {
  description = "Bridge interface name"
  value       = libvirt_network.vmnet.bridge
}

output "network_addresses" {
  description = "Network addresses (CIDR blocks)"
  value       = libvirt_network.vmnet.addresses
}

output "management_network_id" {
  description = "ID of the management network (if created)"
  value       = var.create_management_network ? libvirt_network.management[0].id : null
}

output "management_network_bridge" {
  description = "Management network bridge interface (if created)"
  value       = var.create_management_network ? libvirt_network.management[0].bridge : null
}
