#!/bin/bash

# Proxmox Setup Script - Modular Version
# This script collects connection details and retrieves information from the Proxmox node.

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
  echo "dialog is not installed. Please install it using 'sudo apt install dialog' and try again."
  exit 1
fi

# Create setup_files directory if it doesn't exist
mkdir -p setup_files

# Initialize debug log
echo "Proxmox Setup Script started" > setup_files/debug.log

# Source function modules
source setup_files/functions.sh
source setup_files/pve_host.sh
source setup_files/terraform_vm.sh

# Make scripts executable
chmod +x setup_files/functions.sh
chmod +x setup_files/pve_host.sh
chmod +x setup_files/terraform_vm.sh

while true; do
  # Main Menu
  dialog --menu "Proxmox Setup Menu" 15 50 4 \
  1 "PVE Host" \
  2 "Terraform" \
  3 "Ansible" \
  4 "Exit" 2>setup_files/menu_choice.txt

  menu_choice=$(cat setup_files/menu_choice.txt)
  echo "Menu choice: $menu_choice" >> setup_files/debug.log

  case $menu_choice in
    1)
      # PVE Host submenu
      while true; do
        dialog --menu "PVE Host Menu" 15 50 4 \
        1 "SSH Settings" \
        2 "API Settings" \
        3 "Get Details" \
        4 "View Information" \
        5 "Back to Main Menu" 2>setup_files/submenu_choice.txt

        submenu_choice=$(cat setup_files/submenu_choice.txt)
        echo "PVE Host submenu choice: $submenu_choice" >> setup_files/debug.log

        case $submenu_choice in
          1)
            configure_ssh_settings
            ;;
          2)
            configure_api_settings
            ;;
          3)
            get_pve_details
            ;;
          4)
            view_pve_information
            ;;
          5)
            # Back to Main Menu
            break
            ;;
          *)
            echo "Invalid PVE Host submenu choice" >> setup_files/debug.log
            ;;
        esac
      done
      ;;
    2)
      # Terraform menu
      while true; do
        dialog --menu "Terraform Menu" 15 50 4 \
        1 "VM Configuration" \
        2 "VM Details" \
        3 "Back to Main Menu" 2>setup_files/terraform_choice.txt

        terraform_choice=$(cat setup_files/terraform_choice.txt)
        echo "Terraform menu choice: $terraform_choice" >> setup_files/debug.log

        case $terraform_choice in
          1)
            configure_vm_count
            ;;
          2)
            # VM Details submenu
            while true; do
              dialog --menu "VM Details Menu" 20 60 10 \
              1 "CPU Settings" \
              2 "Memory & Disk" \
              3 "Machine & BIOS" \
              4 "Network Settings" \
              5 "User Settings" \
              6 "IP Settings" \
              7 "Generate Variables" \
              8 "Back to Terraform Menu" 2>setup_files/vm_details_choice.txt

              vm_details_choice=$(cat setup_files/vm_details_choice.txt)
              echo "VM Details menu choice: $vm_details_choice" >> setup_files/debug.log

              case $vm_details_choice in
                1)
                  configure_cpu_settings
                  ;;
                2)
                  configure_memory_disk
                  ;;
                3)
                  configure_machine_bios
                  ;;
                4)
                  configure_network_settings
                  ;;
                5)
                  configure_user_settings
                  ;;
                6)
                  configure_ip_settings
                  ;;
                7)
                  generate_terraform_variables
                  ;;
                8)
                  # Back to Terraform Menu
                  break
                  ;;
              esac
            done
            ;;
          3)
            # Back to Main Menu
            break
            ;;
        esac
      done
      ;;
    3)
      # Ansible placeholder
      dialog --msgbox "Ansible functionality coming soon..." 8 50
      ;;
    4)
      # Exit
      echo "Exiting script" >> setup_files/debug.log
      rm -f setup_files/menu_choice.txt setup_files/submenu_choice.txt setup_files/terraform_choice.txt setup_files/vm_details_choice.txt setup_files/user_settings_choice.txt setup_files/ip_settings_choice.txt setup_files/bios_choice.txt setup_files/temp_input.txt setup_files/temp_config.txt
      exit 0
      ;;
    *)
      echo "Invalid choice" >> setup_files/debug.log
      ;;
  esac
done
