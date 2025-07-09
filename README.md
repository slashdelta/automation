# 🚀 Proxmox Automation Infrastructure
***README.md AI Created***
> **Automated Proxmox VM deployment and configuration using Terraform and Ansible**

[![Terraform](https://img.shields.io/badge/Terraform-1.0%2B-623CE4?style=flat&logo=terraform)](https://terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.9%2B-EE0000?style=flat&logo=ansible)](https://ansible.com/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE-E57000?style=flat&logo=proxmox)](https://proxmox.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-E95420?style=flat&logo=ubuntu)](https://ubuntu.com/)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Usage](#usage)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Overview

This repository provides a complete automation solution for deploying and managing virtual machines on Proxmox VE infrastructure. It combines the power of Terraform for infrastructure provisioning and Ansible for configuration management, all orchestrated through an intelligent setup script.

### What This Automation Does

- 🔧 **Automated VM Provisioning**: Deploy Ubuntu VMs with UEFI support
- 🌐 **Template Management**: Create and manage Ubuntu cloud templates
- 🔒 **Security Configuration**: Automated user setup with SSH key management
- 📦 **Container Ready**: Pre-configured for Docker deployment scenarios
- 🎛️ **Cluster Aware**: Supports both standalone and clustered Proxmox environments

## ✨ Features

### 🎪 Intelligent Setup Script (`setup.sh`)
- **Interactive Configuration**: Guided setup with validation
- **Environment Detection**: Automatically detects standalone vs. clustered Proxmox
- **Template Creation**: Downloads and configures Ubuntu cloud templates
- **Security Best Practices**: Generates secure API tokens and SSH configurations

### 🏗️ Infrastructure as Code
- **Terraform Integration**: Declarative VM provisioning
- **Modular Architecture**: Reusable Terraform modules
- **State Management**: Proper Terraform state handling
- **UEFI Support**: Modern boot configuration for better compatibility

### 🔧 Configuration Management
- **Ansible Playbooks**: Automated post-deployment configuration
- **Docker Setup**: Container runtime installation and configuration
- **GPU Support**: Automated GPU passthrough configuration (optional)
- **Service Management**: Systemd service configuration

## 📋 Prerequisites

### System Requirements
- **Proxmox VE**: 7.0 or later
- **Operating System**: Linux (tested on Ubuntu 22.04+)
- **Network Access**: Internet connectivity for package downloads
- **Storage**: Ceph or local storage pools configured

### Required Tools
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y curl wget unzip git

# The setup script will install:
# - Terraform (latest)
# - Ansible (via pip)
# - Required Python dependencies
```

### Proxmox Configuration
- API user with appropriate permissions
- Storage pools configured (e.g., `ceph-vm`, `truenas`)
- Network bridges configured (e.g., `vmbr0`, `vmbr10`)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/slashdelta/automation.git
cd automation
```

### 2. Run the Setup Script
```bash
./setup.sh
```

The setup script will guide you through:
- 🔍 **Environment Detection**: Standalone vs. clustered Proxmox
- 🔐 **API Configuration**: User creation and token generation
- 📝 **VM Configuration**: CPU, memory, network, and storage settings
- 🎯 **Template Setup**: Ubuntu cloud template download and configuration

### 3. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Configure VMs (Optional)
```bash
cd ../ansible
ansible-playbook playbooks/docker-setup.yml
```

## 🏛️ Architecture

```
automation/
├── 🎪 setup.sh              # Main setup orchestrator
├── 🏗️ terraform/           # Infrastructure provisioning
│   ├── main.tf              # Primary Terraform configuration
│   ├── variables.tf         # Variable definitions
│   ├── modules/             # Reusable Terraform modules
│   │   └── proxmox_vm/      # VM provisioning module
│   └── destroy-preserve-image.sh  # Bandwidth-saving utility
├── 🔧 ansible/             # Configuration management
│   ├── playbooks/          # Ansible playbooks
│   ├── inventories/        # Dynamic inventory management
│   └── scripts/            # Helper scripts
└── 📁 setup_files/         # Generated configuration files
```

## 📖 Usage

### Basic VM Deployment

1. **Configure Your Environment**:
   ```bash
   ./setup.sh
   ```

2. **Review Generated Configuration**:
   ```bash
   cat terraform/terraform.tfvars
   ```

3. **Deploy Infrastructure**:
   ```bash
   cd terraform
   terraform apply
   ```

### Advanced Scenarios

#### Multi-Node Cluster Deployment
```bash
# The setup script automatically detects clustered environments
# and configures VM distribution across nodes
./setup.sh
# Follow prompts for cluster-specific configuration
```

#### Custom Storage Configuration
```bash
# Edit terraform/terraform.tfvars after setup
storage_pool = "your-storage-pool"
template_storage_pool = "your-template-storage"
```

#### Preserve Bandwidth During Teardown
```bash
# Use the bandwidth-saving destroy script
cd terraform
./destroy-preserve-image.sh
```

## ⚙️ Advanced Configuration

### Environment Variables
```bash
export PROXMOX_VE_ENDPOINT="https://your-proxmox:8006/api2/json"
export PROXMOX_VE_USERNAME="terraform@pve"
export PROXMOX_VE_PASSWORD="your-secure-password"
```

### Custom VM Specifications
Edit `terraform/terraform.tfvars`:
```hcl
vm_cpu_cores = 4
vm_memory = 8
vm_disk_size = 100
vm_count = 5
```

### Network Configuration
```hcl
vm_network_bridge = "vmbr10"
vm_network_cidr = "192.168.1.0/24"
vm_starting_ip = "192.168.1.100"
vm_gateway = "192.168.1.1"
```

## 🔧 Troubleshooting

### Common Issues

#### Storage Pool Not Found
```bash
# Check available storage pools
pvesm status

# Update terraform.tfvars with correct storage pool names
storage_pool = "your-actual-storage-pool"
```

#### UEFI Boot Issues
```bash
# Ensure EFI disk is enabled
vm_efi_disk = true
vm_bios_type = "UEFI"
```

#### Network Connectivity
```bash
# Verify bridge configuration
ip link show
# Check Proxmox network configuration
cat /etc/network/interfaces
```

### Debug Mode
```bash
# Enable Terraform debug logging
export TF_LOG=DEBUG
terraform apply

# Enable Ansible verbose output
ansible-playbook -vvv playbooks/docker-setup.yml
```

## 📚 Documentation

- **[Terraform Documentation](terraform/README.md)**: Detailed Terraform module documentation
- **[Ansible Documentation](ansible/README.md)**: Ansible playbook and role documentation
- **[API Reference](docs/api.md)**: Proxmox API integration details

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
```bash
git clone https://github.com/slashdelta/automation.git
cd automation
./setup.sh --dev-mode
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Proxmox VE](https://proxmox.com/) for the excellent virtualization platform
- [Terraform Proxmox Provider](https://github.com/bpg/terraform-provider-proxmox) for the robust provider
- [Ansible](https://ansible.com/) for configuration management capabilities

---

<div align="center">

**[⬆ Back to Top](#-proxmox-automation-infrastructure)**

Made with ❤️ for the Proxmox community

</div>
