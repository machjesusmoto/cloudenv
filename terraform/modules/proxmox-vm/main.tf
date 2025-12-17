# Proxmox VM Terraform Module
# Constitution I: Security-First - VM on private network only (no public exposure)
# Constitution II: Reliability Through Simplicity - Single VM, clear resource allocation

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.0"
    }
  }
}

# T050: Proxmox VM resource (8 vCPU, 49152MB RAM)

# Debian 12 base image for Proxmox installation
resource "libvirt_volume" "proxmox_base" {
  name   = "proxmox-base.qcow2"
  pool   = var.storage_pool
  source = var.debian_iso_url
  format = "qcow2"
}

# Root volume - cloned from base
resource "libvirt_volume" "proxmox_root" {
  name           = "proxmox-root.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.proxmox_base.id
  size           = var.root_disk_size * 1024 * 1024 * 1024  # Convert GB to bytes
  format         = "qcow2"
}

# Data volume for VM storage
resource "libvirt_volume" "proxmox_data" {
  name   = "proxmox-data.qcow2"
  pool   = var.storage_pool
  size   = var.data_disk_size * 1024 * 1024 * 1024  # Convert GB to bytes
  format = "qcow2"
}

# Cloud-init disk for initial configuration
resource "libvirt_cloudinit_disk" "proxmox_init" {
  name = "proxmox-cloudinit.iso"
  pool = var.storage_pool

  user_data = templatefile("${path.module}/cloud-init.cfg", {
    hostname       = var.hostname
    ssh_public_key = var.ssh_public_key
    root_password  = var.root_password
    proxmox_ip     = var.proxmox_ip
    gateway_ip     = var.gateway_ip
    dns_servers    = var.dns_servers
  })

  network_config = templatefile("${path.module}/network-config.cfg", {
    proxmox_ip = var.proxmox_ip
    gateway_ip = var.gateway_ip
    dns_servers = var.dns_servers
  })
}

# Proxmox VM - on private network only
resource "libvirt_domain" "proxmox" {
  name   = var.hostname
  memory = var.memory
  vcpu   = var.vcpus

  # Enable KVM acceleration
  cpu {
    mode = "host-passthrough"
  }

  # Boot from cloud-init then root disk
  boot_device {
    dev = ["hd"]
  }

  # Root disk
  disk {
    volume_id = libvirt_volume.proxmox_root.id
    scsi      = true
  }

  # Data disk
  disk {
    volume_id = libvirt_volume.proxmox_data.id
    scsi      = true
  }

  # Cloud-init disk
  cloudinit = libvirt_cloudinit_disk.proxmox_init.id

  # Private network interface only (Constitution I: Security-First)
  # Proxmox is only accessible via Tailscale VPN through OPNsense
  network_interface {
    network_name   = var.private_network_name
    wait_for_lease = true
  }

  # Console for debugging
  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    listen_address = "127.0.0.1"
  }

  # Qemu agent for better integration
  qemu_agent = true

  lifecycle {
    ignore_changes = [
      disk[0].wwn,
      disk[1].wwn,
    ]
  }
}
