# Outputs for all created VMs
output "docker_vms" {
  description = "Information about all created Docker VMs"
  value = {
    for k, v in module.docker_vms : k => {
      hostname    = v.hostname
      ip_address  = v.ip_address
      mac_address = v.mac_address
      vm_id       = v.vm_id
      node_name   = v.node_name
    }
  }
}

# Individual outputs for easier access
output "docker_vm_hostnames" {
  description = "Hostnames of all Docker VMs"
  value       = { for k, v in module.docker_vms : k => v.hostname }
}

output "docker_vm_ips" {
  description = "IP addresses of all Docker VMs"
  value       = { for k, v in module.docker_vms : k => v.ip_address }
}

output "docker_vm_macs" {
  description = "MAC addresses of all Docker VMs"
  value       = { for k, v in module.docker_vms : k => v.mac_address }
}
