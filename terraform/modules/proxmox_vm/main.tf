# Proxmox VM Module Main Configuration
# This module creates VMs based on setup.sh script variables

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Local variables for dynamic configuration
locals {
  # Convert memory from GB to MB
  vm_memory_mb = var.vm_memory * 1024
  
  # Calculate VM IDs starting from a base
  vm_id_base = 1000
  
  # Parse starting IP to calculate IP addresses
  ip_parts = split(".", var.vm_starting_ip)
  ip_base = "${local.ip_parts[0]}.${local.ip_parts[1]}.${local.ip_parts[2]}"
  ip_start = tonumber(local.ip_parts[3])
  
  # Generate VM configurations
  vm_configs = var.pve_clustered ? local.clustered_vm_configs : local.standalone_vm_configs
  
  # Standalone configuration
  standalone_vm_configs = {
    for i in range(var.vm_count) : "vm-${i + 1}" => {
      name        = length(var.node_names) > 0 ? "${var.node_names[0]}-${var.vm_hostname_prefix}${var.vm_hostname_suffix + i}" : "${var.vm_hostname_prefix}${var.vm_hostname_suffix + i}"
      vmid        = local.vm_id_base + i + 1
      target_node = var.template_node != "" ? var.template_node : var.node_names[0]
      ip_address  = "${local.ip_base}.${local.ip_start + i}"
      index       = i
    }
  }
  
  # Calculate VM offset for each node (cumulative VM count)
  node_vm_offsets = {
    for i, node_name in keys(var.vm_distribution) : node_name => i == 0 ? 0 : sum([
      for j in range(i) : var.vm_distribution[keys(var.vm_distribution)[j]]
    ])
  }

  # Clustered configuration - with proper global indexing
  clustered_vm_list = flatten([
    for node_name, vm_count in var.vm_distribution : [
      for vm_idx in range(vm_count) : {
        key         = "${node_name}-vm-${vm_idx + 1}"
        name        = "${node_name}-${var.vm_hostname_prefix}${var.vm_hostname_suffix + vm_idx}"
        vmid        = local.vm_id_base + local.node_vm_offsets[node_name] + vm_idx + 1
        target_node = node_name
        ip_address  = "${local.ip_base}.${local.ip_start + local.node_vm_offsets[node_name] + vm_idx}"
        index       = vm_idx
      }
    ]
  ])
  
  clustered_vm_configs = {
    for vm in local.clustered_vm_list : vm.key => vm
  }
  
  # Cloud-init user data as string
  cloud_init_user_data = <<-EOT
#cloud-config
hostname: HOSTNAME_PLACEHOLDER
fqdn: HOSTNAME_PLACEHOLDER.local

users:
  - name: ${var.vm_username}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo]
    shell: /bin/bash
    lock_passwd: false

timezone: UTC
locale: en_US.UTF-8

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - qemu-guest-agent
  - openssh-server

manage_resolv_conf: true
resolv_conf:
  nameservers: [8.8.8.8, 8.8.4.4]
  searchdomains: [local]

ssh_pwauth: true
disable_root: false

runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - systemctl start qemu-guest-agent
  - echo "Cloud-init completed for HOSTNAME_PLACEHOLDER" >> /var/log/cloud-init-custom.log

final_message: "Cloud-init setup completed for HOSTNAME_PLACEHOLDER"
EOT
}

# Create VMs
resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vm_configs
  
  name        = each.value.name
  vm_id       = each.value.vmid
  node_name   = each.value.target_node
  
  # Clone from template (specify source node for cluster)
  clone {
    vm_id     = var.template_id
    node_name = var.template_node != "" ? var.template_node : var.node_names[0]  # Clone from template node
    full      = true
  }
  
  # VM Configuration
  cpu {
    cores = var.vm_cpu_cores
    type  = var.vm_cpu_type
  }
  
  memory {
    dedicated = local.vm_memory_mb
  }
  
  machine = var.vm_machine_type
  bios    = var.vm_bios_type == "UEFI" ? "ovmf" : "seabios"
  
  # EFI disk for UEFI
  dynamic "efi_disk" {
    for_each = var.vm_efi_disk ? [1] : []
    content {
      datastore_id = var.storage_pool
      file_format  = "raw"
    }
  }
  
  # Disk configuration
  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = var.vm_disk_size
  }
  
  # Network configuration
  network_device {
    bridge = var.vm_network_bridge
    model  = "virtio"
  }
  
  # Cloud-init configuration
  initialization {
    datastore_id = var.storage_pool
    
    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/${split("/", var.vm_network_cidr)[1]}"
        gateway = var.vm_gateway
      }
    }
    
    user_account {
      username = var.vm_username
      password = var.vm_password
      keys     = var.vm_ssh_keys
    }
    
    user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id
  }
  
  # VM settings
  started    = var.vm_start_on_boot
  protection = var.vm_protection
  tags       = var.vm_tags != "" ? split(",", var.vm_tags) : []
  
  description = "${var.vm_description} - ${each.value.name}"
  
  # Lifecycle settings
  lifecycle {
    ignore_changes = [
      initialization[0].user_data_file_id,
    ]
  }
}

# Create cloud-init user data snippets
resource "proxmox_virtual_environment_file" "cloud_init" {
  for_each = local.vm_configs
  
  content_type = "snippets"
  datastore_id = var.template_storage_pool  # Use template storage pool which supports snippets
  node_name    = each.value.target_node
  
  source_raw {
    data      = replace(local.cloud_init_user_data, "HOSTNAME_PLACEHOLDER", each.value.name)
    file_name = "${each.value.name}-user-data.yml"
  }
}
