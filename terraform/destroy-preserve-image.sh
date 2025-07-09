#!/bin/bash
# Script to destroy Terraform resources while preserving the Ubuntu cloud image

echo "Destroying VMs and template while preserving Ubuntu cloud image..."

terraform destroy \
  -target="proxmox_virtual_environment_vm.ubuntu_template[0]" \
  -target="module.proxmox_vms" \
  "$@"

echo "Ubuntu cloud image preserved for future deployments!"
