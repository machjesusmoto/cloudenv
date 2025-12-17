# OPNsense VM Module - Outputs

output "vm_id" {
  description = "ID of the OPNsense VM"
  value       = libvirt_domain.opnsense.id
}

output "vm_name" {
  description = "Name of the OPNsense VM"
  value       = libvirt_domain.opnsense.name
}

output "lan_ip" {
  description = "LAN interface IP address"
  value       = var.lan_ip
}

output "lan_netmask" {
  description = "LAN interface netmask"
  value       = var.lan_netmask
}

output "wan_interface" {
  description = "WAN physical interface name"
  value       = var.wan_interface
}

output "console_access" {
  description = "VNC console access instructions"
  value       = "Use 'virsh console ${var.vm_name}' or connect via VNC to localhost:${libvirt_domain.opnsense.graphics[0].port}"
}

output "volume_id" {
  description = "ID of the root volume"
  value       = libvirt_volume.opnsense_root.id
}

output "webui_url" {
  description = "OPNsense WebUI URL (LAN access only)"
  value       = "https://${var.lan_ip}"
}
