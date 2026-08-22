# Terraform Outputs
# Exposes important values after infrastructure deployment

# ============================================================================
# Cluster Information
# ============================================================================

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = var.cluster_endpoint
}

output "cluster_vip" {
  description = "Talos VIP for control plane HA"
  value       = var.cluster_vip
}

output "talos_version" {
  description = "Deployed Talos version"
  value       = var.talos_version
}

output "kubernetes_version" {
  description = "Deployed Kubernetes version"
  value       = var.kubernetes_version
}

# ============================================================================
# Node Information
# ============================================================================

output "controlplane_nodes" {
  description = "Control plane node details"
  value = {
    for node in var.controlplane_nodes : node.name => {
      ip   = node.ip
      vmid = node.vmid
    }
  }
}

output "worker_nodes" {
  description = "Worker node details"
  value = {
    for node in var.worker_nodes : node.name => {
      ip   = node.ip
      vmid = node.vmid
    }
  }
}

# ============================================================================
# TrueNAS Information
# ============================================================================

output "truenas_ip" {
  description = "TrueNAS IP address"
  value       = var.truenas_enabled ? var.truenas_ip : null
}

output "truenas_vmid" {
  description = "TrueNAS VM ID"
  value       = var.truenas_enabled ? var.truenas_vmid : null
}

# ============================================================================
# Configuration Files
# ============================================================================

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = pathexpand(var.kubeconfig_path)
}

output "talosconfig_path" {
  description = "Path to talosconfig file"
  value       = pathexpand(var.talosconfig_path)
}

# ============================================================================
# Talos Secrets (Sensitive)
# ============================================================================

output "talos_machine_secrets" {
  description = "Talos machine secrets (for backup)"
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Talos client configuration"
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}

# ============================================================================
# Kubeconfig (Sensitive)
# ============================================================================

output "kubeconfig" {
  description = "Kubernetes configuration"
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

# ============================================================================
# Installed Components
# ============================================================================

output "cilium_version" {
  description = "Installed Cilium version"
  value       = var.cilium_version
}

output "democratic_csi_enabled" {
  description = "Whether Democratic CSI is enabled"
  value       = var.democratic_csi_enabled
}

output "argocd_enabled" {
  description = "Whether ArgoCD is enabled"
  value       = var.argocd_enabled
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = var.argocd_enabled ? var.argocd_namespace : null
}

# ============================================================================
# Access Instructions
# ============================================================================

output "access_instructions" {
  description = "Instructions for accessing the cluster"
  value       = <<-EOT
    ═══════════════════════════════════════════════════════════════════════════════
    Kubernetes Cluster Access Instructions
    ═══════════════════════════════════════════════════════════════════════════════

    1. Kubeconfig saved to: ${pathexpand(var.kubeconfig_path)}
       $ export KUBECONFIG=${pathexpand(var.kubeconfig_path)}
       $ kubectl get nodes

    2. Talosconfig saved to: ${pathexpand(var.talosconfig_path)}
       $ talosctl --talosconfig ${pathexpand(var.talosconfig_path)} health

    3. Cluster VIP: ${var.cluster_vip}
       API Endpoint: ${var.cluster_endpoint}

    4. Control Plane Nodes:
    ${join("\n", [for node in var.controlplane_nodes : "       - ${node.name}: ${node.ip}"])}

    ${var.argocd_enabled ? <<-ARGOCD
    5. ArgoCD Access:
       $ kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:443
       $ kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
       Access: https://localhost:8080
    ARGOCD
    : "5. ArgoCD not installed"}
    ═══════════════════════════════════════════════════════════════════════════════
  EOT
}
