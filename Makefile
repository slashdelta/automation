# Makefile for Terraform and Ansible operations

.PHONY: help init plan apply destroy clean validate fmt inventory ansible-ping ansible-docker ansible-dynamic

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
	@echo "  ansible-dynamic - Test connectivity using dynamic inventory"
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

ansible-dynamic:
	@echo "Using dynamic inventory..."
	cd ansible && ansible all -i ./terraform_inventory.py -m ping
