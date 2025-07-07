#!/bin/bash

# Script to find GPU PCI IDs for passthrough configuration
# Run this on each Proxmox node to find the GPU PCI addresses

echo "=== GPU PCI Device Information ==="
echo

echo "1. All NVIDIA GPUs:"
lspci | grep -i nvidia

echo
echo "2. Detailed GPU information:"
lspci -v | grep -A 10 -B 5 -i nvidia

echo
echo "3. GPU PCI IDs for IOMMU groups:"
for d in /sys/kernel/iommu_groups/*/devices/*; do
    if [[ -e "$d" ]]; then
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        device_info=$(lspci -nns ${d##*/})
        if echo "$device_info" | grep -qi nvidia; then
            echo "IOMMU Group $n: ${d##*/} $device_info"
        fi
    fi
done

echo
echo "4. Current VFIO driver bindings:"
ls -la /sys/bus/pci/drivers/vfio-pci/ | grep -E "^l"

echo
echo "5. Instructions:"
echo "- Copy the PCI IDs (format: 0000:xx:xx.x) from section 3"
echo "- Update the terraform/main.tf file with these IDs"
echo "- Ensure IOMMU and VT-d/AMD-Vi are enabled in BIOS"
echo "- Verify GPU drivers are bound to vfio-pci"
