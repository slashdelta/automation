# Main Terraform configuration file

# Provider configuration
provider "proxmox" {
  endpoint = "https://10.10.0.10:8006/"
  username = "terraform@pve"
  api_token = "terraform@pve!terraform=1cb7dead-8e4c-44ab-a413-06e0e12af3cb"
  
  # Skip TLS verification if using self-signed certificates
  insecure = true
  
  # SSH configuration for file uploads
  ssh {
    agent = true
    username = "root"
  }
}

# Local variables for VM configuration
locals {
  nodes = {
    red = {
      name         = "red"
      ip           = "10.10.0.110"
      vm_id_start  = 1010
    }
    green = {
      name         = "green"
      ip           = "10.10.0.111"
      vm_id_start  = 1011
    }
    blue = {
      name         = "blue"
      ip           = "10.10.0.112"
      vm_id_start  = 1012
    }
  }
  
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB5R9lvNg5kr//TP6c2X8XprZ/+rhF22P7QF6hiePMrA"
  
  # GPU configuration - you'll need to update these with your actual GPU PCI IDs
  gpu_config = {
    red = {
      gpu_passthrough = true
      gpu_pci_ids     = ["0000:01:00.0", "0000:01:00.1"]  # Update with your GPU PCI IDs
    }
    green = {
      gpu_passthrough = true
      gpu_pci_ids     = ["0000:02:00.0", "0000:02:00.1"]  # Update with your GPU PCI IDs
    }
    blue = {
      gpu_passthrough = true
      gpu_pci_ids     = ["0000:03:00.0", "0000:03:00.1"]  # Update with your GPU PCI IDs
    }
  }
}

# Create Docker VMs using the module
module "docker_vms" {
  for_each = local.nodes
  
  source = "./modules/docker_vm"
  
  name               = "docker-${each.value.name}"
  vmid               = each.value.vm_id_start
  target_node        = each.value.name
  template_node      = "red"
  ubuntu_template    = 9000
  vm_ssh_public_key  = local.ssh_public_key
  ip                 = each.value.ip
  
  # GPU passthrough configuration
  gpu_passthrough    = local.gpu_config[each.key].gpu_passthrough
  gpu_pci_ids        = local.gpu_config[each.key].gpu_pci_ids
}
