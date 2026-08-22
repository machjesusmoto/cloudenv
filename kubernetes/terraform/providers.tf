# Provider Configurations
# Configures all required providers for the Kubernetes cluster infrastructure

# ============================================================================
# Proxmox Provider
# ============================================================================
# Documentation: https://registry.terraform.io/providers/bpg/proxmox/latest/docs

provider "proxmox" {
  endpoint = var.proxmox_endpoint

  # API token authentication (recommended over password)
  # Format: "user@realm!tokenid=secret"
  api_token = var.proxmox_api_token

  # Skip TLS verification for self-signed certificates
  # Set to true if using proper SSL certificates
  insecure = true

  # SSH configuration for advanced operations
  ssh {
    agent = true
  }
}

# ============================================================================
# Talos Provider
# ============================================================================
# Documentation: https://registry.terraform.io/providers/siderolabs/talos/latest/docs

provider "talos" {
  # No specific configuration needed - uses machine_secrets resource
}

# ============================================================================
# Helm Provider
# ============================================================================
# Documentation: https://registry.terraform.io/providers/hashicorp/helm/latest/docs

provider "helm" {
  kubernetes = {
    # Configuration loaded from talos_cluster_kubeconfig
    host                   = local.kubernetes_host
    cluster_ca_certificate = local.kubernetes_ca_cert
    client_certificate     = local.kubernetes_client_cert
    client_key             = local.kubernetes_client_key
  }
}

# ============================================================================
# Kubernetes Provider
# ============================================================================
# Documentation: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs

provider "kubernetes" {
  host                   = local.kubernetes_host
  cluster_ca_certificate = local.kubernetes_ca_cert
  client_certificate     = local.kubernetes_client_cert
  client_key             = local.kubernetes_client_key
}

# ============================================================================
# Local Values for Provider Configuration
# ============================================================================

locals {
  # These values are populated after Talos cluster bootstrap
  # They depend on the talos_cluster_kubeconfig data source
  kubernetes_host        = try(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.host, "")
  kubernetes_ca_cert     = try(base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate), "")
  kubernetes_client_cert = try(base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate), "")
  kubernetes_client_key  = try(base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key), "")
}
