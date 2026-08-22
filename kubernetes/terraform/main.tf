# Main Terraform Configuration
# Orchestrates the complete Kubernetes cluster deployment
#
# Deployment Order:
# 1. TrueNAS VM (optional, for shared storage)
# 2. Talos machine secrets
# 3. Talos VM creation
# 4. Talos configuration application
# 5. Cluster bootstrap
# 6. Cilium CNI installation
# 7. Democratic CSI installation
# 8. ArgoCD installation

# ============================================================================
# Talos Image Factory
# ============================================================================

# Get Talos image URLs from the image factory
data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
}

# Create schematic for Talos image with QEMU guest agent
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/qemu-guest-agent",
        ]
      }
    }
  })
}

# ============================================================================
# Talos Machine Secrets
# ============================================================================

# Generate Talos cluster secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# ============================================================================
# TrueNAS VM (Optional)
# ============================================================================

resource "proxmox_virtual_environment_vm" "truenas" {
  count = var.truenas_enabled ? 1 : 0

  name        = "truenas"
  node_name   = var.proxmox_node
  vm_id       = var.truenas_vmid
  description = "TrueNAS Scale - NFS storage for Kubernetes"

  cpu {
    cores = var.truenas_cpu
    type  = "host"
  }

  memory {
    dedicated = var.truenas_memory
  }

  # OS disk
  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = var.truenas_os_disk_size
    file_format  = "raw"
  }

  # Data disk for ZFS pool
  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi1"
    size         = var.truenas_data_disk_size
    file_format  = "raw"
  }

  cdrom {
    enabled   = true
    file_id   = "${var.proxmox_iso_storage}:iso/${var.truenas_iso}"
    interface = "ide2"
  }

  network_device {
    bridge = var.proxmox_bridge
  }

  operating_system {
    type = "l26"
  }

  on_boot = true

  lifecycle {
    ignore_changes = [
      cdrom,  # Ignore after initial boot
    ]
  }
}

# ============================================================================
# Talos Control Plane VMs
# ============================================================================

resource "proxmox_virtual_environment_vm" "controlplane" {
  for_each = { for node in var.controlplane_nodes : node.name => node }

  name        = each.value.name
  node_name   = var.proxmox_node
  vm_id       = each.value.vmid
  description = "Talos Linux Control Plane Node"

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = each.value.disk
    file_format  = "raw"
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
    interface = "ide2"
  }

  network_device {
    bridge = var.proxmox_bridge
  }

  operating_system {
    type = "l26"
  }

  on_boot = true

  # Boot from ISO initially
  boot_order = ["ide2", "scsi0"]

  lifecycle {
    ignore_changes = [
      cdrom,
      boot_order,
    ]
  }

  depends_on = [
    proxmox_virtual_environment_download_file.talos_iso
  ]
}

# Download Talos ISO to Proxmox
resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.proxmox_iso_storage
  node_name    = var.proxmox_node
  url          = data.talos_image_factory_urls.this.urls.iso
  file_name    = "talos-${var.talos_version}-nocloud-amd64.iso"
}

# ============================================================================
# Talos Worker VMs (Optional)
# ============================================================================

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = { for node in var.worker_nodes : node.name => node }

  name        = each.value.name
  node_name   = var.proxmox_node
  vm_id       = each.value.vmid
  description = "Talos Linux Worker Node"

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = each.value.disk
    file_format  = "raw"
  }

  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
    interface = "ide2"
  }

  network_device {
    bridge = var.proxmox_bridge
  }

  operating_system {
    type = "l26"
  }

  on_boot = true
  boot_order = ["ide2", "scsi0"]

  lifecycle {
    ignore_changes = [
      cdrom,
      boot_order,
    ]
  }

  depends_on = [
    proxmox_virtual_environment_download_file.talos_iso
  ]
}

# ============================================================================
# Talos Machine Configuration
# ============================================================================

# Generate control plane configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  # Config patches applied at talos_machine_configuration_apply level
}

# Generate worker configuration (if workers defined)
data "talos_machine_configuration" "worker" {
  count = length(var.worker_nodes) > 0 ? 1 : 0

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  # Config patches applied at talos_machine_configuration_apply level
}

# ============================================================================
# Apply Talos Configuration to Nodes
# ============================================================================

# Apply configuration to control plane nodes
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = { for node in var.controlplane_nodes : node.name => node }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ip

  config_patches = [
    # Machine configuration: install, network, features
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          hostname = each.value.name
          interfaces = [
            {
              interface = "eth0"
              addresses = ["${each.value.ip}/${var.network_cidr}"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }
              ]
              vip = {
                ip = var.cluster_vip
              }
            }
          ]
          nameservers = var.network_dns
        }
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
      }
    }),
    # Cluster configuration: CNI, proxy, scheduling
    yamlencode({
      cluster = {
        network = {
          podSubnets     = ["10.244.0.0/16"]
          serviceSubnets = ["10.96.0.0/12"]
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
        allowSchedulingOnControlPlanes = true
      }
    })
  ]

  depends_on = [
    proxmox_virtual_environment_vm.controlplane
  ]
}

# Apply configuration to worker nodes
resource "talos_machine_configuration_apply" "worker" {
  for_each = { for node in var.worker_nodes : node.name => node }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[0].machine_configuration
  node                        = each.value.ip

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
        network = {
          hostname = each.value.name
          interfaces = [
            {
              interface = "eth0"
              addresses = ["${each.value.ip}/${var.network_cidr}"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.network_gateway
                }
              ]
            }
          ]
          nameservers = var.network_dns
        }
      }
    })
  ]

  depends_on = [
    proxmox_virtual_environment_vm.worker
  ]
}

# ============================================================================
# Bootstrap Cluster
# ============================================================================

# Bootstrap the first control plane node
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_nodes[0].ip

  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

# ============================================================================
# Cluster Health Check
# ============================================================================

# Wait for cluster to be healthy
data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = [for node in var.controlplane_nodes : node.ip]
  worker_nodes         = [for node in var.worker_nodes : node.ip]
  endpoints            = [for node in var.controlplane_nodes : node.ip]
  timeouts = {
    read = "10m"
  }

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

# ============================================================================
# Retrieve Kubeconfig
# ============================================================================

# Get kubeconfig from cluster
data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_nodes[0].ip

  depends_on = [
    data.talos_cluster_health.this
  ]
}

# Save kubeconfig to file
resource "local_file" "kubeconfig" {
  content         = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = pathexpand(var.kubeconfig_path)
  file_permission = "0600"
}

# Save talosconfig to file
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = pathexpand(var.talosconfig_path)
  file_permission = "0600"
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for node in var.controlplane_nodes : node.ip]
  nodes                = concat(
    [for node in var.controlplane_nodes : node.ip],
    [for node in var.worker_nodes : node.ip]
  )
}

# ============================================================================
# Cilium CNI Installation
# ============================================================================

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  version          = var.cilium_version
  namespace        = "kube-system"
  create_namespace = false

  set = [
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "kubeProxyReplacement"
      value = var.cilium_kube_proxy_replacement ? "true" : "false"
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = "false"
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "k8sServiceHost"
      value = "localhost"
    },
    {
      name  = "k8sServicePort"
      value = "7445"  # KubePrism port
    },
  ]

  depends_on = [
    data.talos_cluster_kubeconfig.this
  ]
}

# ============================================================================
# Democratic CSI Installation (Optional)
# ============================================================================

resource "kubernetes_namespace" "democratic_csi" {
  count = var.democratic_csi_enabled ? 1 : 0

  metadata {
    name = "democratic-csi"
  }

  depends_on = [
    helm_release.cilium
  ]
}

resource "kubernetes_secret" "democratic_csi_driver_config" {
  count = var.democratic_csi_enabled && var.truenas_api_key != "" ? 1 : 0

  metadata {
    name      = "driver-config-secret"
    namespace = kubernetes_namespace.democratic_csi[0].metadata[0].name
  }

  data = {
    "driver-config.yaml" = yamlencode({
      driver = "freenas-nfs"
      httpConnection = {
        protocol = "https"
        host     = var.truenas_ip
        port     = 443
        apiKey   = var.truenas_api_key
        allowInsecure = true
      }
      nfs = {
        shareHost     = var.truenas_ip
        shareAllow    = "*"
        shareMaprootUser = "root"
        shareMaprootGroup = "wheel"
      }
      zfs = {
        datasetParentName       = var.truenas_nfs_dataset
        detachedSnapshots       = false
        datasetEnableQuotas     = true
        datasetEnableReservation = false
        datasetPermissionsMode  = "0777"
      }
    })
  }

  depends_on = [
    kubernetes_namespace.democratic_csi
  ]
}

resource "helm_release" "democratic_csi" {
  count = var.democratic_csi_enabled ? 1 : 0

  name             = "democratic-csi"
  repository       = "https://democratic-csi.github.io/charts/"
  chart            = "democratic-csi"
  version          = var.democratic_csi_version
  namespace        = kubernetes_namespace.democratic_csi[0].metadata[0].name
  create_namespace = false

  set = [
    {
      name  = "driver.config.driver"
      value = "freenas-nfs"
    },
    {
      name  = "driver.existingConfigSecret"
      value = var.truenas_api_key != "" ? kubernetes_secret.democratic_csi_driver_config[0].metadata[0].name : ""
    },
    {
      name  = "storageClasses[0].name"
      value = "truenas-nfs"
    },
    {
      name  = "storageClasses[0].defaultClass"
      value = "true"
    },
    {
      name  = "storageClasses[0].reclaimPolicy"
      value = "Delete"
    },
    {
      name  = "storageClasses[0].volumeBindingMode"
      value = "Immediate"
    },
    {
      name  = "storageClasses[0].allowVolumeExpansion"
      value = "true"
    },
  ]

  depends_on = [
    helm_release.cilium,
    kubernetes_namespace.democratic_csi
  ]
}

# ============================================================================
# ArgoCD Installation (Optional)
# ============================================================================

resource "kubernetes_namespace" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  metadata {
    name = var.argocd_namespace
  }

  depends_on = [
    helm_release.cilium
  ]
}

resource "helm_release" "argocd" {
  count = var.argocd_enabled ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = kubernetes_namespace.argocd[0].metadata[0].name
  create_namespace = false

  set = [
    # Core settings
    {
      name  = "global.domain"
      value = "argocd.local"
    },
    # Disable HA for single-node/small clusters
    {
      name  = "controller.replicas"
      value = "1"
    },
    {
      name  = "server.replicas"
      value = "1"
    },
    {
      name  = "repoServer.replicas"
      value = "1"
    },
    {
      name  = "applicationSet.replicas"
      value = "1"
    },
    # Server configuration
    {
      name  = "server.insecure"
      value = "true"  # TLS termination at ingress
    },
  ]

  depends_on = [
    helm_release.cilium,
    kubernetes_namespace.argocd
  ]
}
