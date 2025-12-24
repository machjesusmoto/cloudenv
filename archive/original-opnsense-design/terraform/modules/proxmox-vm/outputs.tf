# Proxmox VM Module Outputs
# T052: Management IP output

output "proxmox_id" {
  description = "Libvirt domain ID for Proxmox VM"
  value       = libvirt_domain.proxmox.id
}

output "proxmox_ip" {
  description = "Proxmox VM IP on private network"
  value       = var.proxmox_ip
}

output "proxmox_hostname" {
  description = "Proxmox VM hostname"
  value       = var.hostname
}

output "proxmox_webui_url" {
  description = "Proxmox Web UI URL (accessible via Tailscale only)"
  value       = "https://${var.proxmox_ip}:8006"
}

output "proxmox_ssh" {
  description = "SSH connection string (via Tailscale)"
  value       = "ssh root@${var.proxmox_ip}"
}

output "root_volume_id" {
  description = "Root volume ID"
  value       = libvirt_volume.proxmox_root.id
}

output "data_volume_id" {
  description = "Data volume ID"
  value       = libvirt_volume.proxmox_data.id
}

output "total_storage_gb" {
  description = "Total allocated storage in GB"
  value       = var.root_disk_size + var.data_disk_size
}
