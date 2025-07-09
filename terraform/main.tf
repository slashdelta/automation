# Main Terraform configuration file

# Provider configuration
provider "proxmox" {
  endpoint  = var.proxmox_api_url
  username  = var.proxmox_api_user
  api_token = var.proxmox_api_token

  # Skip TLS verification if using self-signed certificates
  insecure = true

  # SSH configuration for file uploads
  ssh {
    agent    = true
    username = "root"
  }
}

# Local variables for VM configuration
locals {
  nodes = {
    red = {
      name        = "red"
      ip          = "10.10.0.110"
      vm_id_start = 1010
    }
    green = {
      name        = "green"
      ip          = "10.10.0.111"
      vm_id_start = 1011
    }
    blue = {
      name        = "blue"
      ip          = "10.10.0.112"
      vm_id_start = 1012
    }
  }

  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB5R9lvNg5kr//TP6c2X8XprZ/+rhF22P7QF6hiePMrA slash.admin@xps"

}

# Create Docker VMs using the module
module "docker_vms" {
  for_each = local.nodes

  source = "./modules/docker_vm"

  name              = "docker-${each.value.name}"
  vmid              = each.value.vm_id_start
  target_node       = each.value.name
  template_node     = "red"
  ubuntu_template   = 9000
  vm_ssh_public_key = local.ssh_public_key
  ip                = each.value.ip
}
