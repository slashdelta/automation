# Variable definitions for the docker_vm module
variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "vmid" {
  description = "VM ID"
  type        = number
}

variable "target_node" {
  description = "Target Proxmox node where the VM should be created"
  type        = string
}

variable "template_node" {
  description = "Proxmox node where the template VM is located"
  type        = string
  default     = "red"
}

variable "ubuntu_template" {
  description = "Ubuntu template VM ID to clone from"
  type        = number
  default     = 9000
}

variable "vm_ssh_public_key" {
  description = "SSH public key for the VM"
  type        = string
}

variable "use_dhcp" {
  description = "Use DHCP for network configuration"
  type        = bool
  default     = true
}

variable "ip" {
  description = "IP address for the VM (only used if use_dhcp is false)"
  type        = string
  default     = ""
}

variable "storage" {
  description = "Storage pool name"
  type        = string
  default     = "ceph-vm"
}

variable "memory" {
  description = "Memory allocation in MB"
  type        = number
  default     = 2048
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "machine" {
  description = "The machine type"
  type        = string
  default     = "q35"
}

variable "mapped_devices" {
  description = "List of mapped devices to pass through to the VM"
  type        = list(string)
  default     = []
}
