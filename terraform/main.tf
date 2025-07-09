# Main Terraform Configuration
# Integrates with setup.sh script variables for dynamic VM creation

terraform {
  required_version = ">= 1.0"
}

# Provider configuration
provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure = true
  
  # SSH configuration for file uploads
  ssh {
    agent = true
    username = "root"
    # Fallback to explicit key file if agent doesn't work
    private_key = file("~/.ssh/id_ed25519")
  }
}

# Local variables for dynamic configuration
locals {
  # Determine primary node for template creation
  primary_node = length(var.node_names) > 0 ? var.node_names[0] : var.pve_host_ip
  
  # Determine template node
  template_node = var.template_node != "" ? var.template_node : local.primary_node
  
  # Create node list for both clustered and standalone
  node_list = var.pve_clustered ? var.node_names : [local.primary_node]
  
  # Create VM distribution map
  vm_distribution = var.pve_clustered ? var.vm_distribution : {
    (local.primary_node) = var.vm_count
  }
}

# Template detection across all nodes in cluster
data "proxmox_virtual_environment_nodes" "available_nodes" {}

# Try to find the template on each node
data "proxmox_virtual_environment_vms" "template_search" {
  for_each = toset([for node in data.proxmox_virtual_environment_nodes.available_nodes.names : node])
  
  node_name = each.key
  
  # Filter for our specific template ID
  tags = []
}

# Local logic to determine template existence and location
locals {
  # Search through all nodes for the template
  template_found_on_nodes = {
    for node_name, vms in data.proxmox_virtual_environment_vms.template_search :
    node_name => [
      for vm in vms.vms :
      vm if vm.vm_id == var.template_id && vm.template == true
    ]
  }
  
  # Find the node that has our template
  template_node_with_template = [
    for node_name, templates in local.template_found_on_nodes :
    node_name if length(templates) > 0
  ]
  
  # Template exists if we found it on any node
  template_exists = length(local.template_node_with_template) > 0
  
  # Use the node where template exists, or primary node for new template
  actual_template_node = local.template_exists ? local.template_node_with_template[0] : local.template_node
}

# Local logic for image handling
locals {
  ubuntu_image_filename = "ubuntu-${var.ubuntu_version}-cloudimg-amd64.img"
}

# Download Ubuntu cloud image with overwrite capability
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  count = var.create_template && !local.template_exists ? 1 : 0
  
  content_type = "iso"
  datastore_id = var.template_storage_pool
  node_name    = local.template_node
  url          = var.ubuntu_image_url
  file_name    = local.ubuntu_image_filename
  overwrite_unmanaged = true  # Allow overwriting files not managed by Terraform
  
}

# Create Ubuntu cloud template if it doesn't exist
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  count = var.create_template && !local.template_exists ? 1 : 0
  
  name      = var.template_name
  vm_id     = var.template_id
  node_name = local.template_node
  
  # Template configuration
  description = "Ubuntu ${var.ubuntu_version} Cloud Template - Created by Terraform"
  template    = true
  
  # VM Configuration
  cpu {
    cores = 2
    type  = "host"
  }
  
  memory {
    dedicated = 2048
  }
  
  machine = "q35"
  bios    = "ovmf"
  
  # EFI disk for UEFI
  efi_disk {
    datastore_id = var.template_vm_disk_storage
    file_format  = "raw"
  }
  
  # Cloud-init disk
  disk {
    datastore_id = var.template_vm_disk_storage
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image[0].id
    interface    = "scsi0"
    size         = 20
  }
  
  # Network configuration
  network_device {
    bridge = var.vm_network_bridge
    model  = "virtio"
  }
  
  # Enable QEMU guest agent
  agent {
    enabled = true
  }
  
  # VM settings
  started    = false
  protection = true
  
  # Convert to template after creation
  lifecycle {
    create_before_destroy = true
  }
}

# Create VMs using the new proxmox_vm module
module "proxmox_vms" {
  source = "./modules/proxmox_vm"
  
  # Wait for template to be ready
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template]
  
  # Proxmox connection
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_user  = var.proxmox_api_user
  proxmox_api_token = var.proxmox_api_token
  
  # PVE host configuration
  pve_host_ip      = var.pve_host_ip
  pve_clustered    = var.pve_clustered
  pve_cluster_name = var.pve_cluster_name
  
  # Node configuration
  node_names      = local.node_list
  node_ips        = var.node_ips
  vm_distribution = local.vm_distribution
  
  # Template configuration
  template_id   = var.template_id
  template_node = local.template_node
  
  # Storage configuration
  storage_pool = var.storage_pool
  template_storage_pool = var.template_storage_pool
  template_vm_disk_storage = var.template_vm_disk_storage
  
  # VM configuration
  vm_count      = var.vm_count
  vm_cpu_cores  = var.vm_cpu_cores
  vm_cpu_type   = var.vm_cpu_type
  vm_memory     = var.vm_memory
  vm_disk_size  = var.vm_disk_size
  vm_machine_type = var.vm_machine_type
  vm_bios_type  = var.vm_bios_type
  vm_efi_disk   = var.vm_efi_disk
  
  # Network configuration
  vm_network_bridge = var.vm_network_bridge
  vm_network_cidr   = var.vm_network_cidr
  vm_starting_ip    = var.vm_starting_ip
  vm_gateway        = var.vm_gateway
  
  # User configuration
  vm_username        = var.vm_username
  vm_password        = var.vm_password
  vm_hostname_prefix = var.vm_hostname_prefix
  vm_hostname_suffix = var.vm_hostname_suffix
  vm_ssh_keys        = var.vm_ssh_keys
  
  # Advanced configuration
  vm_start_on_boot = var.vm_start_on_boot
  vm_protection    = var.vm_protection
  vm_tags          = var.vm_tags
  vm_description   = var.vm_description
}
