# CloudEnv Main Terraform Configuration
# Constitution III: Infrastructure as Code

# Private network for VMs
module "vmnet" {
  source = "./modules/libvirt-network"

  network_name  = var.network_name
  network_mode  = "route"
  network_cidr  = var.network_cidr
  network_domain = var.network_domain
  bridge_name   = var.bridge_name
  autostart     = true
}

# OPNsense Firewall VM
module "opnsense" {
  source = "./modules/opnsense-vm"

  vm_name       = var.opnsense_vm_name
  memory        = var.opnsense_memory
  vcpu          = var.opnsense_vcpu
  disk_size     = var.opnsense_disk_size
  storage_pool  = var.storage_pool

  # Network interfaces
  wan_interface  = var.wan_interface
  lan_network_id = module.vmnet.network_id

  # Installation settings
  iso_path      = var.opnsense_iso_path
  boot_from_iso = var.opnsense_boot_from_iso
  download_iso  = var.opnsense_download_iso

  # LAN configuration
  lan_ip      = var.opnsense_lan_ip
  lan_netmask = var.opnsense_lan_netmask

  depends_on = [module.vmnet]
}

# T054: Proxmox VM - accessible only via Tailscale VPN (Constitution I: Security-First)
module "proxmox" {
  source = "./modules/proxmox-vm"

  hostname             = var.proxmox_name
  vcpus                = var.proxmox_vcpus
  memory               = var.proxmox_memory_mb
  root_disk_size       = var.proxmox_root_disk_gb
  data_disk_size       = var.proxmox_data_disk_gb
  storage_pool         = var.storage_pool_name
  private_network_name = var.private_network_name

  # Network configuration
  proxmox_ip  = var.proxmox_ip
  gateway_ip  = var.opnsense_lan_ip
  dns_servers = [var.opnsense_lan_ip, "1.1.1.1"]

  # Authentication
  ssh_public_key = var.ssh_public_key
  root_password  = var.proxmox_root_password

  # Debian image for base system
  debian_iso_url = var.debian_cloud_image_url

  depends_on = [module.opnsense]
}
