#!/usr/bin/env python3
"""
Generate Ansible inventory from Terraform outputs
This script can be run from any directory and will look for Terraform in the terraform/ subdirectory
"""
import json
import subprocess
import sys
import os

def get_terraform_outputs():
    """Get Terraform outputs as JSON"""
    # Determine the terraform directory path
    script_dir = os.path.dirname(os.path.abspath(__file__))
    terraform_dir = os.path.join(script_dir, '..', '..', 'terraform')
    
    try:
        result = subprocess.run(['terraform', 'output', '-json'], 
                              cwd=terraform_dir,
                              capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error getting Terraform outputs: {e}", file=sys.stderr)
        print(f"Make sure Terraform is initialized and applied in {terraform_dir}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing Terraform outputs: {e}", file=sys.stderr)
        sys.exit(1)

def generate_inventory(outputs):
    """Generate Ansible inventory from Terraform outputs"""
    inventory_lines = ["[docker_vms]"]
    
    if 'docker_vms' in outputs:
        vms = outputs['docker_vms']['value']
        for vm_name, vm_info in vms.items():
            line = f"{vm_info['ip_address']} ansible_host={vm_info['ip_address']} hostname={vm_info['hostname']} vm_id={vm_info['vm_id']} node_name={vm_info['node_name']} vm_name={vm_name}"
            inventory_lines.append(line)
    
    inventory_lines.append("")  # Empty line at end
    inventory_lines.append("[docker_vms:vars]")
    inventory_lines.append("ansible_user=ubuntu")
    inventory_lines.append("ansible_ssh_private_key_file=~/.ssh/id_rsa")
    
    return "\n".join(inventory_lines)

def main():
    outputs = get_terraform_outputs()
    inventory = generate_inventory(outputs)
    
    # Write to file in the ansible directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    inventory_path = os.path.join(script_dir, '..', 'inventories', 'production', 'hosts.ini')
    
    with open(inventory_path, 'w') as f:
        f.write(inventory)
    
    print(f"Ansible inventory generated in {inventory_path}:")
    print(inventory)

if __name__ == "__main__":
    main()
