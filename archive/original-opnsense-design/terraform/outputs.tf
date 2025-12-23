# CloudEnv Terraform Outputs

# Network outputs
output "network_id" {
  description = "ID of the private VM network"
  value       = module.vmnet.network_id
}

output "network_bridge" {
  description = "Bridge interface name"
  value       = module.vmnet.network_bridge
}

# OPNsense outputs
output "opnsense_vm_id" {
  description = "ID of the OPNsense VM"
  value       = module.opnsense.vm_id
}

output "opnsense_lan_ip" {
  description = "OPNsense LAN IP address"
  value       = module.opnsense.lan_ip
}

output "opnsense_webui_url" {
  description = "OPNsense WebUI URL"
  value       = module.opnsense.webui_url
}

output "opnsense_console_access" {
  description = "How to access OPNsense console"
  value       = module.opnsense.console_access
}

# Proxmox outputs
output "proxmox_vm_id" {
  description = "ID of the Proxmox VM"
  value       = module.proxmox.proxmox_id
}

output "proxmox_ip" {
  description = "Proxmox IP address on private network"
  value       = module.proxmox.proxmox_ip
}

output "proxmox_webui_url" {
  description = "Proxmox Web UI URL (accessible via Tailscale only)"
  value       = module.proxmox.proxmox_webui_url
}

output "proxmox_ssh" {
  description = "SSH connection string (via Tailscale)"
  value       = module.proxmox.proxmox_ssh
}

output "proxmox_total_storage_gb" {
  description = "Total storage allocated to Proxmox"
  value       = module.proxmox.total_storage_gb
}
