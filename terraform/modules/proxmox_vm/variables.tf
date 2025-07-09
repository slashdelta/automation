# Proxmox VM Module Variables
# This module integrates with the setup.sh script variables

# Proxmox Connection Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_user" {
  description = "Proxmox API user"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

# PVE Host Configuration
variable "pve_host_ip" {
  description = "PVE host IP address"
  type        = string
}

variable "pve_clustered" {
  description = "Whether PVE is clustered"
  type        = bool
  default     = false
}

variable "pve_cluster_name" {
  description = "PVE cluster name"
  type        = string
  default     = ""
}

# Node Configuration (for clustered setups)
variable "node_names" {
  description = "List of node names in the cluster"
  type        = list(string)
  default     = []
}

variable "node_ips" {
  description = "List of node IP addresses"
  type        = list(string)
  default     = []
}

# VM Distribution per Node (for clustered setups)
variable "vm_distribution" {
  description = "Map of node names to VM counts"
  type        = map(number)
  default     = {}
}

# Template Configuration
variable "template_id" {
  description = "Template VM ID to clone from"
  type        = number
  default     = 9000
}

variable "template_node" {
  description = "Node where the template is located"
  type        = string
  default     = ""
}

# Storage Configuration
variable "storage_pool" {
  description = "Storage pool name"
  type        = string
  default     = "ceph-vm"
}

variable "template_storage_pool" {
  description = "Storage pool for templates and snippets"
  type        = string
  default     = "truenas"
}

variable "template_vm_disk_storage" {
  description = "Storage pool for template VM disks"
  type        = string
  default     = "ceph-vm"
}

# VM Configuration
variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 2
}

variable "vm_cpu_type" {
  description = "CPU type (host, kvm64, qemu64, etc.)"
  type        = string
  default     = "host"
}

variable "vm_memory" {
  description = "RAM size in GB"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "vm_machine_type" {
  description = "Machine type (q35, i440fx, pc)"
  type        = string
  default     = "q35"
}

variable "vm_bios_type" {
  description = "BIOS type (UEFI, BIOS)"
  type        = string
  default     = "UEFI"
}

variable "vm_efi_disk" {
  description = "Enable EFI disk (for UEFI)"
  type        = bool
  default     = true
}

# Network Configuration
variable "vm_network_bridge" {
  description = "Network bridge name"
  type        = string
  default     = "vmbr0"
}

variable "vm_network_cidr" {
  description = "Network CIDR"
  type        = string
  default     = "10.10.0.0/24"
}

variable "vm_starting_ip" {
  description = "Starting IP address for VMs"
  type        = string
  default     = "10.10.0.110"
}

variable "vm_gateway" {
  description = "Gateway IP address"
  type        = string
  default     = "10.10.0.1"
}

# User Configuration
variable "vm_username" {
  description = "Username for VM user"
  type        = string
  default     = "ubuntu"
}

variable "vm_password" {
  description = "Password for VM user (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vm_hostname_prefix" {
  description = "Hostname prefix for VMs"
  type        = string
  default     = "ubuntu"
}

variable "vm_hostname_suffix" {
  description = "Starting number for hostname suffix"
  type        = number
  default     = 1
}

variable "vm_ssh_keys" {
  description = "List of SSH public keys"
  type        = list(string)
  default     = []
}

# Advanced Configuration
variable "vm_start_on_boot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "vm_protection" {
  description = "Enable VM protection"
  type        = bool
  default     = false
}

variable "vm_tags" {
  description = "VM tags"
  type        = string
  default     = ""
}

variable "vm_description" {
  description = "VM description"
  type        = string
  default     = "Created by Terraform"
}
