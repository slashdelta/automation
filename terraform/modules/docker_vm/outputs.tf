# Output values for the docker_vm module
output "hostname" {
  description = "Hostname of the created VM"
  value       = proxmox_virtual_environment_vm.docker_vm.name
}

output "ip_address" {
  description = "IP address of the created VM"
  value       = var.ip
}

output "mac_address" {
  description = "MAC address of the VM's network interface"
  value       = proxmox_virtual_environment_vm.docker_vm.network_device[0].mac_address
}

output "vm_id" {
  description = "VM ID of the created VM"
  value       = proxmox_virtual_environment_vm.docker_vm.vm_id
}

output "node_name" {
  description = "Proxmox node where the VM is deployed"
  value       = proxmox_virtual_environment_vm.docker_vm.node_name
}
