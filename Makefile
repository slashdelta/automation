# Makefile for Terraform and Ansible operations

.PHONY: help init plan apply destroy clean validate fmt inventory ansible-ping ansible-docker ansible-dynamic find-gpu-ids ansible-gpu

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
	@echo "  find-gpu-ids  - Show script to find GPU PCI IDs on Proxmox nodes"
	@echo "  clean         - Clean Terraform cache and state files"

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
	@cd ansible && python3 generate_inventory.py

ansible-ping:
	@echo "Testing Ansible connectivity to all VMs..."
	cd ansible && ansible all -m ping

ansible-docker:
	@echo "Running Docker setup playbook..."
	cd ansible && ansible-playbook docker-setup.yml

ansible-gpu:
	@echo "Installing NVIDIA drivers and Docker GPU support..."
	cd ansible && ansible-playbook gpu-setup.yml

ansible-dynamic:
	@echo "Using dynamic inventory..."
	cd ansible && ansible all -i ./terraform_inventory.py -m ping

find-gpu-ids:
	@echo "Finding GPU PCI IDs on Proxmox nodes..."
	@echo "Run this script on each Proxmox node:"
	@echo "scp scripts/find_gpu_pci_ids.sh root@node-ip:/tmp/"
	@echo "ssh root@node-ip /tmp/find_gpu_pci_ids.sh"
	@cat scripts/find_gpu_pci_ids.sh
