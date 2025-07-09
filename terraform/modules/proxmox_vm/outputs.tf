# Outputs for the Proxmox VM Module

output "vm_info" {
  description = "Information about created VMs"
  value = {
    for k, v in proxmox_virtual_environment_vm.vm : k => {
      name        = v.name
      vmid        = v.vm_id
      target_node = v.node_name
      ip_address  = v.initialization[0].ip_config[0].ipv4[0].address
      cores       = v.cpu[0].cores
      memory      = v.memory[0].dedicated
      disk_size   = var.vm_disk_size
      machine     = v.machine
    }
  }
}

output "vm_names" {
  description = "List of VM names"
  value       = [for vm in proxmox_virtual_environment_vm.vm : vm.name]
}

output "vm_ips" {
  description = "List of VM IP addresses"
  value       = [for vm in proxmox_virtual_environment_vm.vm : split("/", vm.initialization[0].ip_config[0].ipv4[0].address)[0]]
}

output "vm_ids" {
  description = "List of VM IDs"
  value       = [for vm in proxmox_virtual_environment_vm.vm : vm.vm_id]
}

output "vm_nodes" {
  description = "List of target nodes"
  value       = [for vm in proxmox_virtual_environment_vm.vm : vm.node_name]
}

output "vm_count" {
  description = "Total number of VMs created"
  value       = length(proxmox_virtual_environment_vm.vm)
}

output "cluster_info" {
  description = "Cluster configuration information"
  value = {
    clustered    = var.pve_clustered
    cluster_name = var.pve_cluster_name
    nodes        = var.node_names
    distribution = var.vm_distribution
  }
}

output "network_info" {
  description = "Network configuration information"
  value = {
    cidr         = var.vm_network_cidr
    gateway      = var.vm_gateway
    bridge       = var.vm_network_bridge
    starting_ip  = var.vm_starting_ip
  }
}

output "vm_configuration" {
  description = "VM configuration summary"
  value = {
    cpu_cores    = var.vm_cpu_cores
    cpu_type     = var.vm_cpu_type
    memory_gb    = var.vm_memory
    disk_size_gb = var.vm_disk_size
    machine_type = var.vm_machine_type
    bios_type    = var.vm_bios_type
    username     = var.vm_username
    hostname_prefix = var.vm_hostname_prefix
    ssh_keys_count = length(var.vm_ssh_keys)
  }
}
