# Terraform and provider version constraints
terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}
