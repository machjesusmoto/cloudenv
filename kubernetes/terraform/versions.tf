# Terraform Version Constraints and Required Providers
# Kubernetes Cluster with Talos Linux - Infrastructure as Code

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Proxmox VE provider for VM management
    # https://registry.terraform.io/providers/bpg/proxmox/latest
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.90.0"
    }

    # Talos Linux provider for cluster management
    # https://registry.terraform.io/providers/siderolabs/talos/latest
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10.0"
    }

    # Helm provider for chart installations
    # https://registry.terraform.io/providers/hashicorp/helm/latest
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }

    # Kubernetes provider for manifest management
    # https://registry.terraform.io/providers/hashicorp/kubernetes/latest
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.0"
    }

    # Local provider for file operations
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }

    # Null provider for provisioners
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}
