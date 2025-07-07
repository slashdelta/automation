#!/usr/bin/env python3
"""
Dynamic Ansible inventory script that reads from Terraform outputs
Usage: 
  ./terraform_inventory.py --list
  ./terraform_inventory.py --host <hostname>
  
This script can be run from any directory and will look for Terraform in the terraform/ subdirectory
"""
import json
import subprocess
import sys
import argparse
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
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing Terraform outputs: {e}", file=sys.stderr)
        return {}

def list_inventory():
    """Return the full inventory"""
    outputs = get_terraform_outputs()
    inventory = {
        '_meta': {
            'hostvars': {}
        },
        'docker_vms': {
            'hosts': [],
            'vars': {
                'ansible_user': 'ubuntu',
                'ansible_ssh_private_key_file': '~/.ssh/id_rsa'
            }
        }
    }
    
    if 'docker_vms' in outputs:
        vms = outputs['docker_vms']['value']
        for vm_name, vm_info in vms.items():
            ip = vm_info['ip_address']
            inventory['docker_vms']['hosts'].append(ip)
            inventory['_meta']['hostvars'][ip] = {
                'ansible_host': ip,
                'hostname': vm_info['hostname'],
                'vm_id': vm_info['vm_id'],
                'node_name': vm_info['node_name'],
                'vm_name': vm_name,
                'mac_address': vm_info.get('mac_address', '')
            }
    
    return inventory

def host_inventory(hostname):
    """Return inventory for a specific host"""
    inventory = list_inventory()
    if hostname in inventory['_meta']['hostvars']:
        return inventory['_meta']['hostvars'][hostname]
    return {}

def main():
    parser = argparse.ArgumentParser(description='Terraform dynamic inventory')
    parser.add_argument('--list', action='store_true', help='List all hosts')
    parser.add_argument('--host', help='Get variables for specific host')
    
    args = parser.parse_args()
    
    if args.list:
        print(json.dumps(list_inventory(), indent=2))
    elif args.host:
        print(json.dumps(host_inventory(args.host), indent=2))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
