# OPNsense VM Module
# Constitution I: Security-First - Secure network perimeter
# Constitution III: Infrastructure as Code

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"  # Pin to 0.7.x - v0.8+ has breaking schema changes
    }
  }
}

# Download OPNsense ISO if not present
resource "null_resource" "download_opnsense_iso" {
  count = var.download_iso ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f "${var.iso_path}" ]; then
        echo "Downloading OPNsense ISO..."
        curl -L -o "${var.iso_path}" "${var.iso_url}"
      fi
    EOT
  }
}

# OPNsense base volume from ISO
resource "libvirt_volume" "opnsense_root" {
  name   = "${var.vm_name}-root.qcow2"
  pool   = var.storage_pool
  size   = var.disk_size
  format = "qcow2"
}

# Cloud-init disk for initial configuration
resource "libvirt_cloudinit_disk" "opnsense_init" {
  count = var.use_cloudinit ? 1 : 0

  name      = "${var.vm_name}-cloudinit.iso"
  pool      = var.storage_pool
  user_data = var.cloudinit_user_data
}

# OPNsense VM definition
resource "libvirt_domain" "opnsense" {
  name   = var.vm_name
  memory = var.memory
  vcpu   = var.vcpu

  cpu {
    mode = "host-passthrough"
  }

  # Boot from ISO for initial install, then from disk
  boot_device {
    dev = var.boot_from_iso ? ["cdrom", "hd"] : ["hd"]
  }

  # Root disk
  disk {
    volume_id = libvirt_volume.opnsense_root.id
    scsi      = true
  }

  # Installation ISO (if booting from ISO)
  dynamic "disk" {
    for_each = var.boot_from_iso ? [1] : []
    content {
      file = var.iso_path
    }
  }

  # WAN interface - macvtap to physical NIC (gets public IP via DHCP)
  network_interface {
    macvtap        = var.wan_interface
    mac            = var.wan_mac_address
    wait_for_lease = false
  }

  # LAN interface - connected to private libvirt network
  network_interface {
    network_id     = var.lan_network_id
    mac            = var.lan_mac_address
    wait_for_lease = false
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    listen_address = "127.0.0.1"
    autoport    = true
  }

  # UEFI firmware for modern boot
  firmware = var.use_uefi ? "/usr/share/OVMF/OVMF_CODE.fd" : null

  lifecycle {
    ignore_changes = [
      disk[0].wwn,
    ]
  }

  depends_on = [
    null_resource.download_opnsense_iso
  ]
}
