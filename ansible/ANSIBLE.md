# Terraform to Ansible Integration

This directory contains scripts and configurations to seamlessly integrate Terraform-managed infrastructure with Ansible automation.

## Quick Start

1. **Deploy infrastructure with Terraform:**
   ```bash
   make apply
   ```

2. **Generate Ansible inventory:**
   ```bash
   make inventory
   ```

3. **Test Ansible connectivity:**
   ```bash
   make ansible-ping
   ```

4. **Run Docker setup playbook:**
   ```bash
   make ansible-docker
   ```

## Files Overview

- `generate_inventory.py` - Generates static Ansible inventory from Terraform outputs
- `terraform_inventory.py` - Dynamic inventory script for Ansible
- `inventory.ini` - Generated static inventory file
- `ansible.cfg` - Ansible configuration
- `docker-setup.yml` - Example playbook to install Docker on VMs

## Usage Methods

### Method 1: Static Inventory (Recommended for CI/CD)

Generate a static inventory file that gets committed to version control:

```bash
# Generate inventory
make inventory

# Use with Ansible
ansible all -m ping
ansible-playbook docker-setup.yml
```

### Method 2: Dynamic Inventory (Recommended for Development)

Use the dynamic inventory script that reads Terraform state in real-time:

```bash
# Test connectivity
ansible all -i ./terraform_inventory.py -m ping

# Run playbook
ansible-playbook -i ./terraform_inventory.py docker-setup.yml
```

## Current VM Information

After running `make inventory`, you'll have access to these VMs:

| VM Name | Hostname | IP Address | VM ID |
|---------|----------|------------|-------|
| red | docker-red | 10.10.0.110 | 1010 |
| green | docker-green | 10.10.0.111 | 1011 |
| blue | docker-blue | 10.10.0.112 | 1012 |

## Ansible Variables Available

Each VM has the following variables available in playbooks:

- `vm_name` - The Terraform module key (red, green, blue)
- `hostname` - The VM hostname
- `ansible_host` - IP address
- `vm_id` - Proxmox VM ID
- `node_name` - Proxmox node name
- `mac_address` - VM MAC address

## Example Playbook Usage

```yaml
- name: Example task using VM variables
  hosts: docker_vms
  tasks:
    - name: Display VM info
      debug:
        msg: "Configuring {{ vm_name }} ({{ hostname }}) at {{ ansible_host }}"
```

## SSH Key Setup

Make sure your SSH key is properly configured:

1. The VMs should have your public key in `~/.ssh/authorized_keys`
2. Your private key should be at `~/.ssh/id_rsa` (or update `ansible.cfg`)
3. Test SSH manually: `ssh ubuntu@10.10.0.110`

## Troubleshooting

- **SSH connection issues**: Check that your SSH key is added to the VMs during cloud-init
- **Permission denied**: Ensure the ubuntu user has sudo privileges
- **Inventory empty**: Run `terraform apply` first to ensure VMs exist
- **Python errors**: Ensure Python 3 is installed and available
