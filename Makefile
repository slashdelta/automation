# Makefile for Terraform and Ansible operations

.PHONY: help init plan apply destroy clean validate fmt inventory ansible-ping ansible-docker ansible-dynamic find-gpu-ids ansible-gpu discover-gpus proxmox-ping ansible-setup ansible-check ansible-requirements ansible-setup ansible-check ansible-requirements

help:
	@echo "Available targets:"
	@echo "  init          - Initialize Terraform"
	@echo "  validate      - Validate Terraform configuration" 
	@echo "  fmt           - Format Terraform files"
	@echo "  plan          - Show Terraform execution plan"
	@echo "  apply         - Apply Terraform configuration"
	@echo "  destroy       - Destroy Terraform-managed infrastructure"
	@echo "  inventory     - Generate Ansible inventory from Terraform outputs"
	@echo "  ansible-ping  - Test Ansible connectivity to all VMs"
	@echo "  ansible-docker - Run Docker setup playbook"
	@echo "  ansible-gpu   - Install NVIDIA drivers and Docker GPU support"
	@echo "  ansible-dynamic - Test connectivity using dynamic inventory"
	@echo "  ansible-setup - Set up Ansible environment and collections"
	@echo "  ansible-check - Check Ansible configuration"
	@echo "  ansible-requirements - Install Ansible and dependencies"
	@echo "  proxmox-ping  - Test connectivity to Proxmox nodes"
	@echo "  discover-gpus - Automatically discover GPUs on all Proxmox nodes"
	@echo "  find-gpu-ids  - Show script to find GPU PCI IDs on Proxmox nodes"
	@echo "  clean         - Clean Terraform cache and state files"
	@echo "  ansible-setup  - Set up Ansible environment"
	@echo "  ansible-check  - Check Ansible configuration"
	@echo "  ansible-requirements - Install Ansible requirements"

init:
	cd terraform && terraform init

validate:
	cd terraform && terraform validate

fmt:
	cd terraform && terraform fmt -recursive

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

destroy:
	cd terraform && terraform destroy

clean:
	rm -rf terraform/.terraform/
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate*

inventory:
	@echo "Generating Ansible inventory from Terraform outputs..."
	@cd ansible && python3 scripts/generate_inventory.py

ansible-ping:
	@echo "Testing Ansible connectivity to all VMs..."
	cd ansible && ansible all -m ping

ansible-docker:
	@echo "Running Docker setup playbook..."
	cd ansible && ansible-playbook playbooks/docker-setup.yml

ansible-gpu:
	@echo "Installing NVIDIA drivers and Docker GPU support..."
	cd ansible && ansible-playbook playbooks/gpu-setup.yml

ansible-dynamic:
	@echo "Using dynamic inventory..."
	cd ansible && ansible all -i ./scripts/terraform_inventory.py -m ping

find-gpu-ids:
	@echo "Finding GPU PCI IDs on Proxmox nodes..."
	@echo "Run this script on each Proxmox node:"
	@echo "scp scripts/find_gpu_pci_ids.sh root@node-ip:/tmp/"
	@echo "ssh root@node-ip /tmp/find_gpu_pci_ids.sh"
	@cat scripts/find_gpu_pci_ids.sh

# Proxmox GPU discovery targets
discover-gpus:
	@echo "Discovering GPUs on all Proxmox nodes..."
	cd ansible && ansible-playbook -i inventories/proxmox/hosts.ini playbooks/proxmox-gpu-discovery.yml

proxmox-ping:
	@echo "Testing connectivity to Proxmox nodes..."
	cd ansible && ansible all -i inventories/proxmox/hosts.ini -m ping

# Ansible setup and installation targets
ansible-setup:
	@echo "Setting up Ansible environment..."
	cd ansible && ansible-galaxy collection install community.general
	cd ansible && ansible-galaxy collection install ansible.posix
	@echo "Ansible setup complete!"

ansible-check:
	@echo "Checking Ansible configuration..."
	cd ansible && ansible --version
	cd ansible && ansible-config view
	@echo "Checking available inventory..."
	cd ansible && ansible-inventory --list

ansible-requirements:
	@echo "Installing Ansible requirements..."
	sudo apt update
	sudo apt install -y ansible python3-pip sshpass
	pip3 install --user ansible-core
	@echo "Ansible requirements installed!"
