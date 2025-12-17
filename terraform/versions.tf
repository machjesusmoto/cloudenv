# Terraform Provider Versions
# Core Infrastructure Setup

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }
}

# Libvirt provider configuration
# Connects to local libvirt daemon via QEMU system socket
provider "libvirt" {
  uri = var.libvirt_uri
}
