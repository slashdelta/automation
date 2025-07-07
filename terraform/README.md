# Terraform Configuration

This directory contains all Terraform configuration files for deploying Proxmox VMs.

## Files

- `main.tf` - Main Terraform configuration
- `outputs.tf` - Output definitions for VM information
- `versions.tf` - Provider version constraints
- `variables.tf` - Variable definitions (if any)
- `terraform.tfvars.example` - Example variables file
- `modules/` - Local Terraform modules
- `.terraform/` - Terraform working directory (auto-generated)
- `terraform.tfstate*` - Terraform state files

## Quick Start

From the root directory:

```bash
# Initialize
make init

# Plan changes
make plan

# Apply configuration
make apply

# Destroy infrastructure
make destroy
```

## Direct Usage

From this terraform directory:

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply

# View outputs
terraform output

# Destroy infrastructure
terraform destroy
```

## Outputs

This configuration provides the following outputs:
- `docker_vms` - Complete VM information
- `docker_vm_hostnames` - VM hostnames
- `docker_vm_ips` - VM IP addresses
- `docker_vm_macs` - VM MAC addresses

These outputs are used by the Ansible inventory scripts in the `../ansible/` directory.
