# Ansible Configuration

This directory contains all Ansible-related files for managing the infrastructure deployed by Terraform.

## Files

- `ansible.cfg` - Ansible configuration file
- `docker-setup.yml` - Playbook to install Docker on all VMs
- `generate_inventory.py` - Script to generate static inventory from Terraform outputs
- `terraform_inventory.py` - Dynamic inventory script for real-time Terraform integration
- `inventory.ini` - Generated static inventory file (created by generate_inventory.py)
- `ANSIBLE.md` - Detailed documentation

## Quick Start

From the root directory:

```bash
# Generate inventory
make inventory

# Test connectivity
make ansible-ping

# Install Docker on all VMs
make ansible-docker
```

## Direct Usage

From this ansible directory:

```bash
# Test connectivity
ansible all -m ping

# Run playbook
ansible-playbook docker-setup.yml

# Use dynamic inventory
ansible all -i ./terraform_inventory.py -m ping
```

## Current VMs

The inventory includes these VMs (after Terraform deployment):
- red (docker-red): 10.10.0.110
- green (docker-green): 10.10.0.111  
- blue (docker-blue): 10.10.0.112
