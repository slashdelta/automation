terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# Main VM resource configuration
resource "proxmox_virtual_environment_vm" "docker_vm" {
  name      = var.name
  vm_id     = var.vmid
  node_name = var.target_node
  machine   = var.machine

  # Clone from Ubuntu template on the template node
  clone {
    vm_id     = var.ubuntu_template
    node_name = var.template_node
    full      = true
  }

  # CPU configuration
  cpu {
    cores = var.cores
    type  = "host"
  }

  # Memory configuration
  memory {
    dedicated = var.memory
  }

  # Disk configuration
  disk {
    datastore_id = var.storage
    interface    = "scsi0"
    size         = var.disk_size
  }

  # Network configuration
  network_device {
    bridge = "vmbr10"
    model  = "virtio"
  }

  # Cloud-init configuration
  initialization {
    datastore_id = var.storage

    user_account {
      username = "ubuntu"
      password = "ThisIsAPassword!23"
      keys     = [var.vm_ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = "10.10.0.1"
      }
    }


    dns {
      servers = ["8.8.8.8", "8.8.4.4"]
    }
  }

  # Enable qemu-guest-agent but don't wait for it during creation
  agent {
    enabled = true
    timeout = "100s"
  }

  # Operating system configuration
  operating_system {
    type = "l26"
  }


  # Serial device for console access
  serial_device {}

  # Start VM after creation
  started = true

  # Prevent destruction
  lifecycle {
    prevent_destroy = false
  }
}
