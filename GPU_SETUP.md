# GPU Passthrough Configuration

This guide explains how to configure NVIDIA GPU passthrough for your Proxmox VMs.

## Prerequisites

### 1. Proxmox Host Configuration

#### Enable IOMMU in GRUB
Edit `/etc/default/grub` on each Proxmox node:

```bash
# For Intel CPUs
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# For AMD CPUs  
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Then update GRUB and reboot:
```bash
update-grub
reboot
```

#### Enable VFIO modules
Add to `/etc/modules`:
```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

#### Blacklist GPU drivers on host
Create `/etc/modprobe.d/blacklist-nvidia.conf`:
```
blacklist nvidia
blacklist nouveau
```

#### Bind GPU to VFIO driver
Find your GPU PCI IDs:
```bash
lspci | grep -i nvidia
```

Add to `/etc/modprobe.d/vfio.conf`:
```
options vfio-pci ids=10de:1b80,10de:10f0
```
(Replace with your actual GPU vendor:device IDs)

### 2. Find GPU PCI Addresses

Run this script on each Proxmox node to find the PCI addresses:

```bash
# Copy the script to each node
scp scripts/find_gpu_pci_ids.sh root@node-ip:/tmp/

# Run on each node
ssh root@node-ip /tmp/find_gpu_pci_ids.sh
```

Or use the Makefile:
```bash
make find-gpu-ids
```

### 3. Update Terraform Configuration

Edit `terraform/main.tf` and update the GPU PCI IDs in the `gpu_config` section:

```hcl
gpu_config = {
  red = {
    gpu_passthrough = true
    gpu_pci_ids     = ["0000:01:00.0", "0000:01:00.1"]  # Your actual GPU PCI IDs
  }
  green = {
    gpu_passthrough = true
    gpu_pci_ids     = ["0000:02:00.0", "0000:02:00.1"]  # Your actual GPU PCI IDs
  }
  blue = {
    gpu_passthrough = true
    gpu_pci_ids     = ["0000:03:00.0", "0000:03:00.1"]  # Your actual GPU PCI IDs
  }
}
```

## Deployment Steps

### 1. Apply Terraform Configuration

```bash
# Plan the changes
make plan

# Apply the configuration
make apply
```

### 2. Install NVIDIA Drivers on VMs

```bash
# Generate inventory
make inventory

# Install NVIDIA drivers and Docker GPU support
make ansible-gpu
```

### 3. Manual Reboot (if required)

The GPU setup playbook will notify if a reboot is required:

```bash
# Reboot VMs manually
cd ansible
ansible all -m reboot -b
```

## Verification

### 1. Check GPU on VMs

```bash
# SSH to a VM
ssh ubuntu@10.10.0.110

# Check GPU
nvidia-smi

# Test Docker GPU access
docker run --rm nvidia/cuda:11.0-base nvidia-smi
```

### 2. Test GPU Workload

```bash
# Run a simple GPU test
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Configuration Files

- `terraform/main.tf` - Main Terraform configuration with GPU settings
- `terraform/modules/docker_vm/main.tf` - VM module with GPU passthrough
- `ansible/gpu-setup.yml` - Ansible playbook for GPU drivers
- `scripts/find_gpu_pci_ids.sh` - Script to find GPU PCI IDs

## Common Issues

### 1. "No devices available" error
- Ensure IOMMU is enabled in BIOS and kernel parameters
- Check that GPU is bound to vfio-pci driver on host
- Verify PCI IDs are correct

### 2. Driver conflicts
- Blacklist GPU drivers on Proxmox host
- Ensure vfio-pci is loaded before GPU drivers

### 3. Performance issues
- Enable PCIe passthrough in VM configuration
- Use `host` CPU type for better performance
- Ensure adequate RAM allocation

## Makefile Commands

- `make find-gpu-ids` - Show script to find GPU PCI IDs
- `make ansible-gpu` - Install NVIDIA drivers on VMs
- `make plan` - Show Terraform changes
- `make apply` - Apply GPU passthrough configuration

## Notes

- Each VM can have multiple GPUs passed through
- GPU passthrough requires dedicated GPUs (can't share with host)
- VMs will need to be recreated to apply GPU passthrough changes
- Consider using GPU scheduling/sharing if you need to share GPUs between VMs
