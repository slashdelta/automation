#!/bin/bash

# Proxmox Setup Script - Modular Version
# This script collects connection details and retrieves information from the Proxmox node.

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
  echo "dialog is not installed. Please install it using 'sudo apt install dialog' and try again."
  exit 1
fi

# Check SSH agent and keys
echo "Checking SSH agent and keys..."

# Auto-detect SSH key type
SSH_KEY_FILE=""
if [ -f ~/.ssh/id_ed25519 ]; then
  SSH_KEY_FILE="~/.ssh/id_ed25519"
elif [ -f ~/.ssh/id_rsa ]; then
  SSH_KEY_FILE="~/.ssh/id_rsa"
elif [ -f ~/.ssh/id_ecdsa ]; then
  SSH_KEY_FILE="~/.ssh/id_ecdsa"
else
  SSH_KEY_FILE="~/.ssh/id_rsa"  # fallback
fi

# Check if SSH_AUTH_SOCK is set and ssh-add works
if [ -z "$SSH_AUTH_SOCK" ]; then
  echo "WARNING: SSH agent not running!"
  echo "The Terraform Proxmox provider requires SSH key authentication."
  echo ""
  echo "Detected SSH key: $SSH_KEY_FILE"
  echo ""
  echo "OPTION 1 - Start SSH agent for this session:"
  echo "  eval \$(ssh-agent)"
  echo "  ssh-add $SSH_KEY_FILE"
  echo "  ./setup.sh"
  echo ""
  echo "OPTION 2 - Start SSH agent and run script in one command:"
  echo "  ssh-agent bash -c 'ssh-add $SSH_KEY_FILE && ./setup.sh'"
  echo ""
  echo "OPTION 3 - Add to your ~/.bashrc for permanent SSH agent:"
  echo "  echo 'eval \$(ssh-agent)' >> ~/.bashrc"
  echo "  echo 'ssh-add $SSH_KEY_FILE 2>/dev/null' >> ~/.bashrc"
  echo ""
  read -p "Do you want to continue anyway? (y/N): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    echo "Exiting. Please configure SSH keys and try again."
    exit 1
  fi
elif ! ssh-add -L &>/dev/null; then
  echo "WARNING: SSH agent running but no keys loaded!"
  echo "The Terraform Proxmox provider requires SSH key authentication."
  echo ""
  echo "Detected SSH key: $SSH_KEY_FILE"
  echo ""
  echo "Please add your SSH key:"
  echo "  ssh-add $SSH_KEY_FILE"
  echo "  ssh-add -L  # to verify keys are loaded"
  echo ""
  read -p "Do you want to continue anyway? (y/N): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    echo "Exiting. Please configure SSH keys and try again."
    exit 1
  fi
else
  echo "SSH keys detected in ssh-agent:"
  ssh-add -L | head -3
  echo ""
fi

# Create setup_files directory if it doesn't exist
mkdir -p setup_files

# Initialize debug log
echo "Proxmox Setup Script started" > setup_files/debug.log
echo "SSH Keys in agent: $(ssh-add -L | wc -l)" >> setup_files/debug.log

# Source function modules
source setup_files/functions.sh
source setup_files/pve_host.sh
source setup_files/terraform_vm.sh

# Make scripts executable
chmod +x setup_files/functions.sh
chmod +x setup_files/pve_host.sh
chmod +x setup_files/terraform_vm.sh

while true; do
  # Set breadcrumb for main menu
  show_breadcrumb "Main"
  
  # Get status indicators for main menu items
  ssh_status=$(get_status_indicator "ssh_configured")
  api_status=$(get_status_indicator "api_configured")
  vm_status=$(get_status_indicator "terraform_configured")
  
  # Get cursor position for main menu
  cursor_pos=$(get_cursor_position "main" "1")
  
  # Main Menu with breadcrumb and status indicators
  dialog --backtitle "Navigation: Main" \
         --cancel-label "Exit" \
         --default-item "$cursor_pos" \
         --menu "Proxmox Setup Menu" 15 70 4 \
  1 "[$ssh_status] PVE Host" \
  2 "[$vm_status] Terraform" \
  3 "[ ] Ansible" \
  4 "Exit" 2>setup_files/menu_choice.txt

  # Handle Cancel/Exit button
  if [ $? -eq 1 ] || [ $? -eq 255 ]; then
    echo "Exiting script" >> setup_files/debug.log
    rm -f setup_files/menu_choice.txt setup_files/submenu_choice.txt setup_files/terraform_choice.txt setup_files/vm_details_choice.txt setup_files/user_settings_choice.txt setup_files/ip_settings_choice.txt setup_files/bios_choice.txt setup_files/temp_input.txt setup_files/temp_config.txt setup_files/current_path.txt setup_files/cursor_*.txt
    exit 0
  fi

  menu_choice=$(cat setup_files/menu_choice.txt)
  save_cursor_position "main" "$menu_choice"
  echo "Menu choice: $menu_choice" >> setup_files/debug.log

  case $menu_choice in
    1)
      # PVE Host submenu
      while true; do
        # Set breadcrumb for PVE Host menu
        show_breadcrumb "Main >> PVE Host"
        
        # Get status indicators for PVE Host menu items
        ssh_status=$(get_status_indicator "ssh_configured")
        details_status=$(get_status_indicator "pve_details_retrieved")
        
        # Get cursor position for PVE Host menu
        cursor_pos=$(get_cursor_position "pve_host" "1")
        
        dialog --backtitle "Navigation: Main >> PVE Host" \
               --cancel-label "Back" \
               --default-item "$cursor_pos" \
               --menu "PVE Host Menu" 20 70 5 \
        1 "[$ssh_status] SSH Settings" \
        2 "[$ssh_status] API Settings" \
        3 "[$details_status] Get Details" \
        4 "[$details_status] View Information" \
        5 "Back to Main Menu" 2>setup_files/submenu_choice.txt

        # Handle Cancel/Back button
        if [ $? -eq 1 ] || [ $? -eq 255 ]; then
          break
        fi

        submenu_choice=$(cat setup_files/submenu_choice.txt)
        save_cursor_position "pve_host" "$submenu_choice"
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
        # Set breadcrumb for Terraform menu
        show_breadcrumb "Main >> Terraform"
        
        # Get status indicators for Terraform menu items
        vm_config_status=$(get_status_indicator "vm_count")
        vm_details_status=$(get_status_indicator "cpu_cores")
        
        # Get cursor position for Terraform menu
        cursor_pos=$(get_cursor_position "terraform" "1")
        
        # Get storage status indicators
        storage_status=$(get_status_indicator "storage_pool")
        template_storage_status=$(get_status_indicator "template_storage_pool")
        
        dialog --backtitle "Navigation: Main >> Terraform" \
               --cancel-label "Back" \
               --default-item "$cursor_pos" \
               --menu "Terraform Menu" 20 70 7 \
        1 "[$vm_config_status] VM Configuration" \
        2 "[$storage_status] Storage Pool (VM Disks)" \
        3 "[$template_storage_status] Template Download/Snippet Storage" \
        4 "[ ] Template VM Disk Storage" \
        5 "[$vm_details_status] VM Details" \
        6 "[ ] Verify SSH Connectivity" \
        7 "Back to Main Menu" 2>setup_files/terraform_choice.txt

        # Handle Cancel/Back button
        if [ $? -eq 1 ] || [ $? -eq 255 ]; then
          break
        fi

        terraform_choice=$(cat setup_files/terraform_choice.txt)
        save_cursor_position "terraform" "$terraform_choice"
        echo "Terraform menu choice: $terraform_choice" >> setup_files/debug.log

        case $terraform_choice in
          1)
            configure_vm_count
            ;;
          2)
            configure_storage_pool
            ;;
          3)
            configure_template_storage_pool
            ;;
          4)
            configure_template_vm_disk_storage
            ;;
          5)
            # VM Details submenu
            while true; do
              # Set breadcrumb for VM Details menu
              show_breadcrumb "Main >> Terraform >> VM Details"
              
              # Get status indicators for VM Details menu items
              cpu_status=$(get_status_indicator "cpu_cores")
              memory_status=$(get_status_indicator "ram_size")
              machine_status=$(get_status_indicator "machine_type")
              storage_status=$(get_status_indicator "storage_pool")
              network_status=$(get_status_indicator "network_bridge")
              user_status=$(get_status_indicator "username")
              ip_status=$(get_status_indicator "cidr")
              tfvars_status=$(get_status_indicator "terraform_variables_generated")
              
              # Get cursor position for VM Details menu
              cursor_pos=$(get_cursor_position "vm_details" "1")
              
              dialog --backtitle "Navigation: Main >> Terraform >> VM Details" \
                     --cancel-label "Back" \
                     --default-item "$cursor_pos" \
                     --menu "VM Details Menu" 25 80 9 \
              1 "[$cpu_status] CPU Settings" \
              2 "[$memory_status] Memory & Disk" \
              3 "[$machine_status] Machine & BIOS" \
              4 "[$network_status] Network Settings" \
              5 "[$user_status] User Settings" \
              6 "[$ip_status] IP Settings" \
              7 "[$tfvars_status] Generate Variables" \
              8 "Back to Terraform Menu" \
              9 "Back to Main Menu" 2>setup_files/vm_details_choice.txt

              # Handle Cancel/Back button
              if [ $? -eq 1 ] || [ $? -eq 255 ]; then
                break
              fi

              vm_details_choice=$(cat setup_files/vm_details_choice.txt)
              save_cursor_position "vm_details" "$vm_details_choice"
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
                  # Check if user wants to go back to main menu
                  if [ $? -eq 1 ]; then
                    break 2  # Exit both VM Details and Terraform loops
                  fi
                  ;;
                6)
                  configure_ip_settings
                  # Check if user wants to go back to main menu
                  if [ $? -eq 1 ]; then
                    break 2  # Exit both VM Details and Terraform loops
                  fi
                  ;;
                7)
                  generate_terraform_variables
                  ;;
                8)
                  # Back to Terraform Menu
                  break
                  ;;
                9)
                  # Back to Main Menu - exit both loops
                  break 2
                  ;;
              esac
            done
            ;;
          6)
            verify_ssh_connectivity
            ;;
          7)
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
