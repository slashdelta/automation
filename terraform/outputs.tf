# Terraform Outputs
# Displays information about created VMs and infrastructure

output "vm_summary" {
  description = "Summary of all created VMs"
  value = {
    total_vms   = module.proxmox_vms.vm_count
    vm_names    = module.proxmox_vms.vm_names
    vm_ips      = module.proxmox_vms.vm_ips
    vm_ids      = module.proxmox_vms.vm_ids
    vm_nodes    = module.proxmox_vms.vm_nodes
  }
}

output "vm_details" {
  description = "Detailed information about each VM"
  value       = module.proxmox_vms.vm_info
}

output "cluster_configuration" {
  description = "Cluster configuration details"
  value       = module.proxmox_vms.cluster_info
}

output "network_configuration" {
  description = "Network configuration details"
  value       = module.proxmox_vms.network_info
}

output "vm_configuration" {
  description = "VM configuration details"
  value       = module.proxmox_vms.vm_configuration
}

output "template_info" {
  description = "Template information"
  value = {
    template_id   = var.template_id
    template_name = var.template_name
    template_node = var.template_node != "" ? var.template_node : (length(var.node_names) > 0 ? var.node_names[0] : var.pve_host_ip)
    ubuntu_version = var.ubuntu_version
    created_template = var.create_template
  }
}

output "connection_info" {
  description = "Connection information for VMs"
  value = {
    ssh_username = var.vm_username
    ssh_command_examples = [
      for ip in module.proxmox_vms.vm_ips : "ssh ${var.vm_username}@${ip}"
    ]
    gateway = var.vm_gateway
  }
  sensitive = false
}

output "infrastructure_summary" {
  description = "Complete infrastructure summary"
  value = {
    deployment_type = var.pve_clustered ? "Clustered" : "Standalone"
    total_nodes     = length(var.node_names)
    total_vms       = module.proxmox_vms.vm_count
    network_cidr    = var.vm_network_cidr
    storage_pool    = var.storage_pool
    vm_specs = {
      cpu_cores  = var.vm_cpu_cores
      cpu_type   = var.vm_cpu_type
      memory_gb  = var.vm_memory
      disk_gb    = var.vm_disk_size
      machine    = var.vm_machine_type
      bios       = var.vm_bios_type
    }
  }
}
