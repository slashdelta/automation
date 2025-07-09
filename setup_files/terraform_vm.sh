#!/bin/bash

# Terraform VM configuration functions

# Function to verify SSH keys and connectivity
verify_ssh_connectivity() {
  # Check if SSH keys are loaded
  if ! ssh-add -L &>/dev/null; then
    dialog --msgbox "ERROR: No SSH keys found in ssh-agent!\n\nThe Terraform Proxmox provider requires SSH key authentication.\n\nPlease run:\n  ssh-agent bash\n  ssh-add ~/.ssh/id_rsa\n  ssh-add -L" 12 70
    return 1
  fi
  
  # Get the number of keys
  key_count=$(ssh-add -L | wc -l)
  
  # Show loaded keys
  ssh_keys_info="SSH Keys loaded in ssh-agent: $key_count\n\n"
  ssh_keys_info="${ssh_keys_info}Key fingerprints:\n"
  ssh_keys_info="${ssh_keys_info}$(ssh-add -l | head -5)\n\n"
  
  # Test connectivity to cluster nodes if available
  if [ -f setup_files/from-setup.tfvars ]; then
    is_clustered=$(grep "pve_clustered" setup_files/from-setup.tfvars | awk '{print $3}')
    if [ "$is_clustered" = "true" ]; then
      ssh_keys_info="${ssh_keys_info}Testing SSH connectivity to cluster nodes...\n"
      node_count=$(grep "node[0-9]*_name" setup_files/from-setup.tfvars | wc -l)
      
      for i in $(seq 1 $node_count); do
        node_name=$(grep "node${i}_name" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
        node_ip=$(grep "node${i}_ip" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
        
        # Test SSH connectivity with timeout
        if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "root@$node_ip" "echo 'SSH OK'" &>/dev/null; then
          ssh_keys_info="${ssh_keys_info}✓ $node_name ($node_ip): SSH OK\n"
        else
          ssh_keys_info="${ssh_keys_info}✗ $node_name ($node_ip): SSH FAILED\n"
        fi
      done
    else
      # Test single host
      pve_host_ip=$(grep "pve_host_ip" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
      if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "root@$pve_host_ip" "echo 'SSH OK'" &>/dev/null; then
        ssh_keys_info="${ssh_keys_info}✓ PVE Host ($pve_host_ip): SSH OK\n"
      else
        ssh_keys_info="${ssh_keys_info}✗ PVE Host ($pve_host_ip): SSH FAILED\n"
      fi
    fi
  fi
  
  ssh_keys_info="${ssh_keys_info}\nSSH connectivity is required for Terraform to create VM templates."
  
  dialog --msgbox "$ssh_keys_info" 20 80
}

# Function to configure VM count and distribution
configure_vm_count() {
  # Check if PVE host info is available
  if [ ! -f setup_files/from-setup.tfvars ]; then
    dialog --msgbox "Please configure PVE Host and run 'Get Details' first" 8 50
    return 1
  fi
  
  # Get number of VMs with validation
  prev_vm_count=$(get_config "vm_count" "1")
  
  get_validated_number "Enter number of VMs to create:" "$prev_vm_count" "1" "100" "vm_count"
  vm_count=$(get_config "vm_count")
  
  # If clustered, show node distribution
  is_clustered=$(grep "pve_clustered" setup_files/from-setup.tfvars | awk '{print $3}')
  if [ "$is_clustered" = "true" ]; then
    # Get node count and names
    node_count=$(grep "node[0-9]*_name" setup_files/from-setup.tfvars | wc -l)
    
    dialog --msgbox "Cluster detected with $node_count nodes.\nYou'll now configure VM distribution across nodes." 8 60
    
    # Create node distribution inputs with validation
    total_assigned=0
    for i in $(seq 1 $node_count); do
      node_name=$(grep "node${i}_name" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
      prev_node_vms=$(get_config "node${i}_vms" "0")
      
      get_validated_number "VMs on node '$node_name':" "$prev_node_vms" "0" "$vm_count" "node${i}_vms"
      node_vms=$(get_config "node${i}_vms")
      total_assigned=$((total_assigned + node_vms))
    done
    
    # Verify total matches
    if [ "$total_assigned" -ne "$vm_count" ]; then
      dialog --msgbox "Warning: Total VMs assigned ($total_assigned) doesn't match total VMs ($vm_count)\n\nPlease adjust the distribution." 10 60
      return 1
    else
      dialog --msgbox "VM distribution configured successfully!\nTotal VMs: $vm_count\nDistributed across $node_count nodes" 8 60
    fi
  else
    dialog --msgbox "Standalone host detected.\nAll $vm_count VMs will be created on the single host." 8 60
  fi
}

# Function to configure CPU settings
configure_cpu_settings() {
  prev_cpu_cores=$(get_config "cpu_cores" "2")
  prev_cpu_type=$(get_config "cpu_type" "host")
  
  get_validated_number "CPU core count:" "$prev_cpu_cores" "1" "64" "cpu_cores"
  
  # CPU type with validation
  while true; do
    dialog --inputbox "CPU type (host/kvm64/qemu64):" 8 40 "$prev_cpu_type" 2>setup_files/temp_input.txt
    cpu_type=$(cat setup_files/temp_input.txt)
    
    if [ -z "$cpu_type" ]; then
      cpu_type="host"
    fi
    
    # Validate CPU type
    case "$cpu_type" in
      host|kvm64|qemu64|x86-64-v2|x86-64-v3|x86-64-v4)
        set_config "cpu_type" "$cpu_type"
        break
        ;;
      *)
        dialog --msgbox "Invalid CPU type. Please enter one of:\nhost, kvm64, qemu64, x86-64-v2, x86-64-v3, x86-64-v4" 10 60
        ;;
    esac
  done
  
  dialog --msgbox "CPU settings configured:\nCores: $(get_config "cpu_cores")\nType: $(get_config "cpu_type")" 8 40
}

# Function to configure memory and disk
configure_memory_disk() {
  prev_ram_size=$(get_config "ram_size" "2")
  prev_disk_size=$(get_config "disk_size" "20")
  
  get_validated_number "RAM size (GB):" "$prev_ram_size" "1" "1024" "ram_size"
  get_validated_number "Disk size (GB):" "$prev_disk_size" "8" "2048" "disk_size"
  
  dialog --msgbox "Memory & Disk configured:\nRAM: $(get_config "ram_size")GB\nDisk: $(get_config "disk_size")GB" 8 40
}

# Function to configure machine and BIOS
configure_machine_bios() {
  prev_machine_type=$(get_config "machine_type" "q35")
  prev_bios_type=$(get_config "bios_type" "UEFI")
  
  # Machine type with validation
  while true; do
    dialog --inputbox "Machine type (q35/i440fx/pc):" 8 40 "$prev_machine_type" 2>setup_files/temp_input.txt
    machine_type=$(cat setup_files/temp_input.txt)
    
    if [ -z "$machine_type" ]; then
      machine_type="q35"
    fi
    
    # Validate machine type
    case "$machine_type" in
      q35|i440fx|pc)
        set_config "machine_type" "$machine_type"
        break
        ;;
      *)
        dialog --msgbox "Invalid machine type. Please enter one of:\nq35 (recommended for modern features)\ni440fx (legacy compatibility)\npc (alias for i440fx)" 10 60
        ;;
    esac
  done
  
  # BIOS type selection
  dialog --menu "Select BIOS Type:" 12 50 2 \
  1 "UEFI (recommended)" \
  2 "Legacy BIOS" 2>setup_files/bios_choice.txt
  
  bios_choice=$(cat setup_files/bios_choice.txt)
  if [ "$bios_choice" = "1" ]; then
    set_config "bios_type" "UEFI"
  else
    set_config "bios_type" "BIOS"
  fi
  
  dialog --msgbox "Machine & BIOS configured:\nMachine: $(get_config "machine_type")\nBIOS: $(get_config "bios_type")" 8 40
}

# Function to configure network settings
configure_network_settings() {
  prev_network_bridge=$(get_config "network_bridge" "vmbr0")
  
  # Network bridge with validation
  while true; do
    dialog --inputbox "Network bridge name:" 8 40 "$prev_network_bridge" 2>setup_files/temp_input.txt
    network_bridge=$(cat setup_files/temp_input.txt)
    
    if [ -z "$network_bridge" ]; then
      network_bridge="vmbr0"
    fi
    
    # Validate bridge name format
    if [[ $network_bridge =~ ^vmbr[0-9]+$ ]]; then
      set_config "network_bridge" "$network_bridge"
      break
    else
      dialog --msgbox "Invalid bridge name. Please use format 'vmbrX' where X is a number (e.g., vmbr0, vmbr10)." 8 60
    fi
  done
  
  dialog --msgbox "Network bridge configured: $(get_config "network_bridge")" 8 40
}

# Function to configure storage pool
configure_storage_pool() {
  # Check if PVE host info is available
  if [ ! -f setup_files/from-setup.tfvars ]; then
    dialog --msgbox "Please configure PVE Host and run 'Get Details' first" 8 50
    return 1
  fi
  
  # Get ALL detected storage pools from PVE info gathering (details.txt)
  storage_pools=()
  storage_display=()
  
  # Look for storage pools in details.txt
  if [ -f setup_files/details.txt ]; then
    # Debug: Show what we're extracting
    echo "DEBUG: Extracting storage from details.txt" >> setup_files/debug.log
    
    # The issue is the sed pattern - it stops at the first ===============================================
    # We need to get the lines AFTER the STORAGE POOLS header and BEFORE the final ===============================================
    
    # Try a different approach - get all lines with exactly 2 pipe characters
    while read -r line; do
      echo "DEBUG: Processing line: '$line'" >> setup_files/debug.log
      # Count pipe characters
      pipe_count=$(echo "$line" | tr -cd '|' | wc -c)
      echo "DEBUG: Pipe count: $pipe_count" >> setup_files/debug.log
      
      if [ "$pipe_count" -eq 2 ]; then
        # Split on pipes
        type=$(echo "$line" | cut -d'|' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
        name=$(echo "$line" | cut -d'|' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
        contents=$(echo "$line" | cut -d'|' -f3 | sed 's/^[ \t]*//;s/[ \t]*$//')
        
        echo "DEBUG: Parsed - Type: '$type', Name: '$name', Contents: '$contents'" >> setup_files/debug.log
        
        # Skip header and separator lines
        if [[ "$type" != "Type" && "$type" != "---"* && -n "$name" && "$name" != "Name" && "$type" != "Node Name" ]]; then
          storage_pools+=("$name")
          storage_display+=("$name" "$type - [$contents]")
          echo "DEBUG: Added storage pool: $name" >> setup_files/debug.log
        else
          echo "DEBUG: Skipped line - header or separator" >> setup_files/debug.log
        fi
      else
        echo "DEBUG: Skipped line - wrong pipe count" >> setup_files/debug.log
      fi
    done < setup_files/details.txt
    
    echo "DEBUG: Final storage_pools array: ${storage_pools[@]}" >> setup_files/debug.log
  fi
  
  # Add fallback options if no storage found
  if [ ${#storage_pools[@]} -eq 0 ]; then
    storage_pools=("local-lvm" "local")
    storage_display=("local-lvm" "LVM-Thin - [images]" "local" "Directory - [iso,snippets]")
  fi
  
  # Get current selection
  prev_storage_pool=$(get_config "storage_pool" "${storage_pools[0]}")
  
  # Create menu options
  menu_options=()
  menu_counter=1
  for i in "${!storage_pools[@]}"; do
    pool_name="${storage_pools[$i]}"
    pool_type="${storage_display[$((i*2+1))]}"
    menu_options+=("$menu_counter")
    menu_options+=("$pool_name ($pool_type)")
    menu_counter=$((menu_counter + 1))
  done
  
  # Add custom entry option
  menu_options+=("$menu_counter")
  menu_options+=("Custom: Enter storage pool name manually")
  
  # Show storage pool selection menu
  dialog --menu "Select Storage Pool for VM Disks:" 20 70 10 \
    "${menu_options[@]}" 2>setup_files/temp_input.txt
  
  if [ $? -eq 0 ]; then
    choice=$(cat setup_files/temp_input.txt)
    
    if [ "$choice" -eq "$menu_counter" ]; then
      # Custom entry
      dialog --inputbox "Enter custom storage pool name:" 8 40 "$prev_storage_pool" 2>setup_files/temp_input.txt
      custom_storage=$(cat setup_files/temp_input.txt)
      
      if [ -n "$custom_storage" ]; then
        set_config "storage_pool" "$custom_storage"
        dialog --msgbox "Custom storage pool configured: $custom_storage" 8 50
      else
        dialog --msgbox "No storage pool selected. Using previous setting: $prev_storage_pool" 8 50
      fi
    else
      # Selected from list
      selected_index=$((choice - 1))
      selected_pool="${storage_pools[$selected_index]}"
      set_config "storage_pool" "$selected_pool"
      dialog --msgbox "Storage pool configured: $selected_pool" 8 40
    fi
  else
    dialog --msgbox "No storage pool selected. Using previous setting: $prev_storage_pool" 8 50
  fi
}

# Function to configure template download/snippet storage pool
configure_template_storage_pool() {
  # Check if PVE host info is available
  if [ ! -f setup_files/from-setup.tfvars ]; then
    dialog --msgbox "Please configure PVE Host and run 'Get Details' first" 8 50
    return 1
  fi
  
  # Get ALL detected storage pools from PVE info gathering (details.txt)
  template_storage_pools=()
  template_storage_display=()
  
  # Look for storage pools in details.txt
  if [ -f setup_files/details.txt ]; then
    # Use the same logic as the VM storage function
    while read -r line; do
      # Count pipe characters
      pipe_count=$(echo "$line" | tr -cd '|' | wc -c)
      
      if [ "$pipe_count" -eq 2 ]; then
        # Split on pipes
        type=$(echo "$line" | cut -d'|' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
        name=$(echo "$line" | cut -d'|' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
        contents=$(echo "$line" | cut -d'|' -f3 | sed 's/^[ \t]*//;s/[ \t]*$//')
        
        # Skip header and separator lines
        if [[ "$type" != "Type" && "$type" != "---"* && -n "$name" && "$name" != "Name" && "$type" != "Node Name" ]]; then
          template_storage_pools+=("$name")
          template_storage_display+=("$name" "$type - [$contents]")
        fi
      fi
    done < setup_files/details.txt
  fi
  
  # Add fallback options if no storage found
  if [ ${#template_storage_pools[@]} -eq 0 ]; then
    template_storage_pools=("local")
    template_storage_display=("local" "Directory - [iso,snippets]")
  fi
  
  # Get current selection
  prev_template_storage=$(get_config "template_storage_pool" "${template_storage_pools[0]}")
  
  # Create menu options
  menu_options=()
  menu_counter=1
  for i in "${!template_storage_pools[@]}"; do
    pool_name="${template_storage_pools[$i]}"
    pool_type="${template_storage_display[$((i*2+1))]}"
    menu_options+=("$menu_counter")
    menu_options+=("$pool_name ($pool_type)")
    menu_counter=$((menu_counter + 1))
  done
  
  # Add custom entry option
  menu_options+=("$menu_counter")
  menu_options+=("Custom: Enter storage pool name manually")
  
  # Show template storage selection menu
  dialog --menu "Select Storage Pool for Template Downloads/Snippets:\n(Must support ISO/snippets - file-based storage)" 20 70 10 \
    "${menu_options[@]}" 2>setup_files/temp_input.txt
  
  if [ $? -eq 0 ]; then
    choice=$(cat setup_files/temp_input.txt)
    
    if [ "$choice" -eq "$menu_counter" ]; then
      # Custom entry
      dialog --inputbox "Enter custom template download/snippet storage pool:" 8 50 "$prev_template_storage" 2>setup_files/temp_input.txt
      custom_storage=$(cat setup_files/temp_input.txt)
      
      if [ -n "$custom_storage" ]; then
        set_config "template_storage_pool" "$custom_storage"
        dialog --msgbox "Template download/snippet storage configured: $custom_storage" 8 60
      else
        dialog --msgbox "No template storage selected. Using previous setting: $prev_template_storage" 8 50
      fi
    else
      # Selected from list
      selected_index=$((choice - 1))
      selected_pool="${template_storage_pools[$selected_index]}"
      set_config "template_storage_pool" "$selected_pool"
      dialog --msgbox "Template download/snippet storage configured: $selected_pool" 8 50
    fi
  else
    dialog --msgbox "No template storage selected. Using previous setting: $prev_template_storage" 8 50
  fi
}

# Function to configure template VM disk storage pool
configure_template_vm_disk_storage() {
  # Check if PVE host info is available
  if [ ! -f setup_files/from-setup.tfvars ]; then
    dialog --msgbox "Please configure PVE Host and run 'Get Details' first" 8 50
    return 1
  fi
  
  # Get current VM disk storage pool setting
  vm_storage_pool=$(get_config "storage_pool" "local-lvm")
  
  # Ask if user wants to use same storage as VM disks
  dialog --yesno "Template VM disks should use the same storage as regular VM disks for consistency.\n\nUse '$vm_storage_pool' for template VM disks?\n\n(This is recommended)" 12 70
  
  if [ $? -eq 0 ]; then
    # Use same as VM storage
    set_config "template_vm_disk_storage" "$vm_storage_pool"
    dialog --msgbox "Template VM disk storage set to: $vm_storage_pool\n\n(Same as VM disk storage)" 8 50
  else
    # Let user choose different storage
    template_vm_storage_pools=()
    template_vm_storage_display=()
    
    # Look for storage pools in details.txt
    if [ -f setup_files/details.txt ]; then
      while read -r line; do
        pipe_count=$(echo "$line" | tr -cd '|' | wc -c)
        
        if [ "$pipe_count" -eq 2 ]; then
          type=$(echo "$line" | cut -d'|' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
          name=$(echo "$line" | cut -d'|' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
          contents=$(echo "$line" | cut -d'|' -f3 | sed 's/^[ \t]*//;s/[ \t]*$//')
          
          if [[ "$type" != "Type" && "$type" != "---"* && -n "$name" && "$name" != "Name" && "$type" != "Node Name" ]]; then
            template_vm_storage_pools+=("$name")
            template_vm_storage_display+=("$name" "$type - [$contents]")
          fi
        fi
      done < setup_files/details.txt
    fi
    
    # Add fallback if no storage found
    if [ ${#template_vm_storage_pools[@]} -eq 0 ]; then
      template_vm_storage_pools=("local-lvm" "local")
      template_vm_storage_display=("local-lvm" "LVM-Thin - [images]" "local" "Directory - [iso,snippets]")
    fi
    
    # Get current selection
    prev_template_vm_storage=$(get_config "template_vm_disk_storage" "$vm_storage_pool")
    
    # Create menu options
    menu_options=()
    menu_counter=1
    for i in "${!template_vm_storage_pools[@]}"; do
      pool_name="${template_vm_storage_pools[$i]}"
      pool_type="${template_vm_storage_display[$((i*2+1))]}"
      menu_options+=("$menu_counter")
      menu_options+=("$pool_name ($pool_type)")
      menu_counter=$((menu_counter + 1))
    done
    
    # Add custom entry option
    menu_options+=("$menu_counter")
    menu_options+=("Custom: Enter storage pool name manually")
    
    # Show storage selection menu
    dialog --menu "Select Storage Pool for Template VM Disks:\n(Should support VM images/disks)" 20 70 10 \
      "${menu_options[@]}" 2>setup_files/temp_input.txt
    
    if [ $? -eq 0 ]; then
      choice=$(cat setup_files/temp_input.txt)
      
      if [ "$choice" -eq "$menu_counter" ]; then
        # Custom entry
        dialog --inputbox "Enter custom template VM disk storage pool:" 8 50 "$prev_template_vm_storage" 2>setup_files/temp_input.txt
        custom_storage=$(cat setup_files/temp_input.txt)
        
        if [ -n "$custom_storage" ]; then
          set_config "template_vm_disk_storage" "$custom_storage"
          dialog --msgbox "Template VM disk storage configured: $custom_storage" 8 50
        fi
      else
        # Selected from list
        selected_index=$((choice - 1))
        selected_pool="${template_vm_storage_pools[$selected_index]}"
        set_config "template_vm_disk_storage" "$selected_pool"
        dialog --msgbox "Template VM disk storage configured: $selected_pool" 8 50
      fi
    fi
  fi
}

# Function to configure user settings
configure_user_settings() {
  while true; do
    # Set breadcrumb for User Settings menu
    show_breadcrumb "Main >> Terraform >> VM Details >> User Settings"
    
    # Get status indicators for User Settings menu items
    username_status=$(get_status_indicator "username")
    password_status=$(get_status_indicator "password")
    hostname_status=$(get_status_indicator "hostname_prefix")
    suffix_status=$(get_status_indicator "hostname_suffix")
    ssh_keys_status=$(get_status_indicator "ssh_keys")
    
    # Get cursor position for User Settings menu
    cursor_pos=$(get_cursor_position "user_settings" "1")
    
    dialog --backtitle "Navigation: Main >> Terraform >> VM Details >> User Settings" \
           --cancel-label "Back" \
           --default-item "$cursor_pos" \
           --menu "User Settings Menu" 20 80 7 \
    1 "[$username_status] Username" \
    2 "[$password_status] Password" \
    3 "[$hostname_status] Hostname" \
    4 "[$suffix_status] Hostname Suffix" \
    5 "[$ssh_keys_status] SSH Keys" \
    6 "Back to VM Details" \
    7 "Back to Main Menu" 2>setup_files/user_settings_choice.txt

    # Handle Cancel/Back button
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then
      break
    fi

    user_settings_choice=$(cat setup_files/user_settings_choice.txt)
    save_cursor_position "user_settings" "$user_settings_choice"
    
    case $user_settings_choice in
      1)
        # Username with validation
        prev_username=$(get_config "username" "ubuntu")
        
        while true; do
          dialog --inputbox "Username:" 8 40 "$prev_username" 2>setup_files/temp_input.txt
          username=$(cat setup_files/temp_input.txt)
          
          if [ -z "$username" ]; then
            username="ubuntu"
          fi
          
          # Validate username format (now allows decimal points)
          if [[ $username =~ ^[a-z][a-z0-9._-]*$ ]]; then
            set_config "username" "$username"
            break
          else
            dialog --msgbox "Invalid username. Must start with lowercase letter and contain only lowercase letters, numbers, decimal points, hyphens, and underscores." 10 70
          fi
        done
        ;;
      2)
        # Password (no default, hidden input)
        prev_password=$(get_config "password" "")
        
        dialog --insecure --passwordbox "Password (leave empty for no password):" 8 40 "$prev_password" 2>setup_files/temp_input.txt
        password=$(cat setup_files/temp_input.txt)
        set_config "password" "$password"
        
        if [ -n "$password" ]; then
          dialog --msgbox "Password set successfully." 8 30
        else
          dialog --msgbox "No password set. VM will use SSH key authentication only." 8 50
        fi
        ;;
      3)
        # Hostname prefix with validation
        prev_hostname_prefix=$(get_config "hostname_prefix" "ubuntu")
        
        while true; do
          dialog --inputbox "Hostname:" 8 40 "$prev_hostname_prefix" 2>setup_files/temp_input.txt
          hostname_prefix=$(cat setup_files/temp_input.txt)
          
          if [ -z "$hostname_prefix" ]; then
            hostname_prefix="ubuntu"
          fi
          
          # Validate hostname format
          if [[ $hostname_prefix =~ ^[a-z][a-z0-9-]*[a-z0-9]$|^[a-z]$ ]]; then
            set_config "hostname_prefix" "$hostname_prefix"
            break
          else
            dialog --msgbox "Invalid hostname. Must start with lowercase letter, end with letter or number, and contain only lowercase letters, numbers, and hyphens." 10 60
          fi
        done
        ;;
      4)
        # Hostname suffix (starting number)
        prev_hostname_suffix=$(get_config "hostname_suffix" "1")
        
        get_validated_number "Hostname suffix (starting number):" "$prev_hostname_suffix" "1" "999" "hostname_suffix"
        ;;
      5)
        # SSH Keys
        prev_ssh_keys=$(get_config "ssh_keys" "")
        
        dialog --inputbox "SSH public keys (comma-separated, or leave empty):" 10 70 "$prev_ssh_keys" 2>setup_files/temp_input.txt
        ssh_keys=$(cat setup_files/temp_input.txt)
        set_config "ssh_keys" "$ssh_keys"
        
        if [ -n "$ssh_keys" ]; then
          key_count=$(echo "$ssh_keys" | tr ',' '\n' | wc -l)
          dialog --msgbox "SSH keys configured: $key_count key(s)" 8 40
        else
          dialog --msgbox "No SSH keys configured." 8 30
        fi
        ;;
      6)
        break
        ;;
      7)
        # Back to Main Menu - exit multiple loops
        return 1
        ;;
    esac
  done
}

# Function to configure IP settings
configure_ip_settings() {
  while true; do
    # Set breadcrumb for IP Settings menu
    show_breadcrumb "Main >> Terraform >> VM Details >> IP Settings"
    
    # Get status indicators for IP Settings menu items
    cidr_status=$(get_status_indicator "cidr")
    starting_ip_status=$(get_status_indicator "starting_ip")
    gateway_status=$(get_status_indicator "gateway")
    
    # Get cursor position for IP Settings menu
    cursor_pos=$(get_cursor_position "ip_settings" "1")
    
    dialog --backtitle "Navigation: Main >> Terraform >> VM Details >> IP Settings" \
           --cancel-label "Back" \
           --default-item "$cursor_pos" \
           --menu "IP Settings Menu" 18 80 5 \
    1 "[$cidr_status] CIDR" \
    2 "[$starting_ip_status] Starting IP" \
    3 "[$gateway_status] Gateway" \
    4 "Back to VM Details" \
    5 "Back to Main Menu" 2>setup_files/ip_settings_choice.txt

    # Handle Cancel/Back button (ESC key)
    if [ $? -eq 1 ] || [ $? -eq 255 ]; then
      break
    fi

    ip_settings_choice=$(cat setup_files/ip_settings_choice.txt)
    save_cursor_position "ip_settings" "$ip_settings_choice"
    
    case $ip_settings_choice in
      1)
        # CIDR with validation
        prev_cidr=$(get_config "cidr" "10.10.0.0/24")
        
        get_validated_cidr "Network CIDR:" "$prev_cidr" "cidr"
        ;;
      2)
        # Starting IP with validation
        prev_starting_ip=$(get_config "starting_ip" "10.10.0.110")
        
        get_validated_ip "Starting IP address:" "$prev_starting_ip" "starting_ip"
        ;;
      3)
        # Gateway with validation
        prev_gateway=$(get_config "gateway" "10.10.0.1")
        
        get_validated_ip "Gateway IP address:" "$prev_gateway" "gateway"
        ;;
      4)
        break
        ;;
      5)
        # Back to Main Menu - exit multiple loops
        return 1
        ;;
    esac
  done
}

# Function to generate all Terraform variables
generate_terraform_variables() {
  dialog --infobox "Generating Terraform variables..." 5 40
  sleep 1
  
  # Collect all configuration values with defaults
  vm_count=$(get_config "vm_count" "1")
  cpu_cores=$(get_config "cpu_cores" "2")
  cpu_type=$(get_config "cpu_type" "host")
  ram_size=$(get_config "ram_size" "2")
  disk_size=$(get_config "disk_size" "20")
  machine_type=$(get_config "machine_type" "q35")
  bios_type=$(get_config "bios_type" "UEFI")
  storage_pool=$(get_config "storage_pool" "local-lvm")
  network_bridge=$(get_config "network_bridge" "vmbr0")
  username=$(get_config "username" "ubuntu")
  password=$(get_config "password" "")
  hostname_prefix=$(get_config "hostname_prefix" "ubuntu")
  hostname_suffix=$(get_config "hostname_suffix" "1")
  ssh_keys=$(get_config "ssh_keys" "")
  cidr=$(get_config "cidr" "10.10.0.0/24")
  starting_ip=$(get_config "starting_ip" "10.10.0.110")
  gateway=$(get_config "gateway" "10.10.0.1")
  
  # Set EFI disk variable based on BIOS type
  if [ "$bios_type" = "UEFI" ]; then
    efi_disk="true"
  else
    efi_disk="false"
  fi
  
  # Read existing from-setup.tfvars to preserve PVE host config
  if [ -f setup_files/from-setup.tfvars ]; then
    # Extract only the PVE host configuration section
    awk '/^# Proxmox Host Configuration/,/^$/ {print}
         /^# Proxmox Nodes/,/^$/ {print}
         /^# Storage Pools/,/^$/ {print}' setup_files/from-setup.tfvars > setup_files/temp_pve_config.txt
  fi
  
  # Generate node distribution variables if clustered
  node_distribution_vars=""
  is_clustered=$(grep "pve_clustered" setup_files/from-setup.tfvars 2>/dev/null | awk '{print $3}')
  if [ "$is_clustered" = "true" ]; then
    node_count=$(grep "node[0-9]*_name" setup_files/from-setup.tfvars | wc -l)
    for i in $(seq 1 $node_count); do
      node_name=$(grep "node${i}_name" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
      node_vms=$(get_config "node${i}_vms" "0")
      node_distribution_vars="${node_distribution_vars}vm_count_${node_name} = $node_vms\n"
    done
  fi
  
  # Write complete variables file
  {
    # Include existing PVE host configuration
    if [ -f setup_files/temp_pve_config.txt ]; then
      cat setup_files/temp_pve_config.txt
      echo ""
    fi
    
    echo "# VM Configuration"
    echo "vm_count = $vm_count"
    
    # Add node distribution if clustered
    if [ -n "$node_distribution_vars" ]; then
      echo ""
      echo "# VM Distribution per Node"
      echo -e "$node_distribution_vars"
    fi
    
    echo ""
    echo "# VM Hardware Configuration"
    echo "vm_cpu_cores = $cpu_cores"
    echo "vm_cpu_type = \"$cpu_type\""
    echo "vm_memory = $ram_size"
    echo "vm_disk_size = $disk_size"
    echo "vm_machine_type = \"$machine_type\""
    echo "vm_bios_type = \"$bios_type\""
    echo "vm_efi_disk = $efi_disk"
    echo ""
    echo "# VM Storage Configuration"
    echo "storage_pool = \"$storage_pool\""
    echo ""
    echo "# VM Network Configuration"
    echo "vm_network_bridge = \"$network_bridge\""
    echo ""
    echo "# VM User Configuration"
    echo "vm_username = \"$username\""
    if [ -n "$password" ]; then
      echo "vm_password = \"$password\""
    else
      echo "vm_password = \"\""
    fi
    echo "vm_hostname_prefix = \"$hostname_prefix\""
    echo "vm_hostname_suffix = $hostname_suffix"
    if [ -n "$ssh_keys" ]; then
      echo "vm_ssh_keys = [\"$(echo "$ssh_keys" | sed 's/,/","/g')\"]"
    else
      echo "vm_ssh_keys = []"
    fi
    echo ""
    echo "# VM Network Settings"
    echo "vm_network_cidr = \"$cidr\""
    echo "vm_starting_ip = \"$starting_ip\""
    echo "vm_gateway = \"$gateway\""
  } > setup_files/from-setup.tfvars
  
  # Generate Terraform variables file
  generate_terraform_tfvars
  
  # Clean up temp file
  rm -f setup_files/temp_pve_config.txt
  
  # Set status for terraform configuration completion
  set_config "terraform_variables_generated" "true"
  
  # Create comprehensive configuration summary
  summary="Terraform variables generated successfully!\n\n"
  summary="${summary}COMPLETE CONFIGURATION SUMMARY:\n"
  summary="${summary}=====================================\n"
  summary="${summary}VMs: $vm_count\n"
  summary="${summary}CPU: ${cpu_cores} cores ($cpu_type)\n"
  summary="${summary}RAM: ${ram_size}GB\n"
  summary="${summary}Disk: ${disk_size}GB\n"
  summary="${summary}Machine: $machine_type\n"
  summary="${summary}BIOS: $bios_type\n"
  summary="${summary}Storage Pool: $storage_pool\n"
  summary="${summary}Network Bridge: $network_bridge\n"
  summary="${summary}Username: $username\n"
  summary="${summary}Hostname: ${hostname_prefix}${hostname_suffix}\n"
  summary="${summary}Network CIDR: $cidr\n"
  summary="${summary}Starting IP: $starting_ip\n"
  summary="${summary}Gateway: $gateway\n"
  
  if [ -n "$ssh_keys" ]; then
    key_count=$(echo "$ssh_keys" | tr ',' '\n' | wc -l)
    summary="${summary}SSH Keys: $key_count configured\n"
  else
    summary="${summary}SSH Keys: None\n"
  fi
  
  if [ -n "$password" ]; then
    summary="${summary}Password: Set\n"
  else
    summary="${summary}Password: Not set\n"
  fi
  
  summary="${summary}=====================================\n"
  summary="${summary}Saved to: setup_files/from-setup.tfvars"
  
  dialog --msgbox "$summary" 25 70
}

# Function to generate terraform.tfvars file for actual Terraform execution
generate_terraform_tfvars() {
  dialog --infobox "Generating terraform.tfvars file..." 5 40
  sleep 1
  
  # Collect all configuration values with defaults
  vm_count=$(get_config "vm_count" "1")
  cpu_cores=$(get_config "cpu_cores" "2")
  cpu_type=$(get_config "cpu_type" "host")
  ram_size=$(get_config "ram_size" "2")
  disk_size=$(get_config "disk_size" "20")
  machine_type=$(get_config "machine_type" "q35")
  bios_type=$(get_config "bios_type" "UEFI")
  storage_pool_config=$(get_config "storage_pool" "local-lvm")
  network_bridge=$(get_config "network_bridge" "vmbr0")
  username=$(get_config "username" "ubuntu")
  password=$(get_config "password" "")
  hostname_prefix=$(get_config "hostname_prefix" "ubuntu")
  hostname_suffix=$(get_config "hostname_suffix" "1")
  ssh_keys=$(get_config "ssh_keys" "")
  cidr=$(get_config "cidr" "10.10.0.0/24")
  starting_ip=$(get_config "starting_ip" "10.10.0.110")
  gateway=$(get_config "gateway" "10.10.0.1")
  
  # Set EFI disk variable based on BIOS type
  if [ "$bios_type" = "UEFI" ]; then
    efi_disk="true"
  else
    efi_disk="false"
  fi
  
  # Read PVE host configuration from from-setup.tfvars
  if [ -f setup_files/from-setup.tfvars ]; then
    # Extract PVE configuration
    pve_host_ip=$(grep "pve_host_ip" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
    pve_clustered=$(grep "pve_clustered" setup_files/from-setup.tfvars | awk '{print $3}')
    pve_cluster_name=$(grep "pve_cluster_name" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
    proxmox_api_url=$(grep "proxmox_api_url" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
    proxmox_api_user=$(grep "proxmox_api_user" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
    proxmox_api_token=$(grep "proxmox_api_token" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
    storage_pool=$(grep "storage_pool" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
    
    # If API variables are empty, try to read from config.txt as fallback
    if [ -z "$proxmox_api_url" ] && [ -f setup_files/config.txt ]; then
      api_host=$(grep "^api_host=" setup_files/config.txt | cut -d'=' -f2)
      api_token_id=$(grep "^api_token_id=" setup_files/config.txt | cut -d'=' -f2)
      api_token_secret=$(grep "^api_token_secret=" setup_files/config.txt | cut -d'=' -f2)
      
      if [ -n "$api_host" ]; then
        proxmox_api_url="https://$api_host:8006/api2/json"
      fi
      if [ -n "$api_token_id" ]; then
        proxmox_api_user="$api_token_id"
      fi
      if [ -n "$api_token_id" ] && [ -n "$api_token_secret" ]; then
        proxmox_api_token="$api_token_id=$api_token_secret"
      fi
    fi
  else
    # Default values if from-setup.tfvars doesn't exist
    pve_host_ip="10.10.0.10"
    pve_clustered="false"
    pve_cluster_name=""
    proxmox_api_url="https://10.10.0.10:8006/api2/json"
    proxmox_api_user="terraform@pve"
    proxmox_api_token="your-api-token-here"
    storage_pool="local-lvm"
  fi
  
  # Build node configuration arrays
  node_names_array="["
  node_ips_array="["
  vm_distribution_map="{"
  
  if [ "$pve_clustered" = "true" ]; then
    # Get node information for clustered setup
    node_count=$(grep "node[0-9]*_name" setup_files/from-setup.tfvars | wc -l)
    for i in $(seq 1 $node_count); do
      node_name=$(grep "node${i}_name" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
      node_ip=$(grep "node${i}_ip" setup_files/from-setup.tfvars | awk -F'"' '{print $2}')
      node_vms=$(get_config "node${i}_vms" "0")
      
      if [ $i -gt 1 ]; then
        node_names_array="${node_names_array}, "
        node_ips_array="${node_ips_array}, "
        vm_distribution_map="${vm_distribution_map}, "
      fi
      
      node_names_array="${node_names_array}\"${node_name}\""
      node_ips_array="${node_ips_array}\"${node_ip}\""
      vm_distribution_map="${vm_distribution_map}\"${node_name}\" = ${node_vms}"
    done
  else
    # Standalone setup
    node_names_array="${node_names_array}\"${pve_host_ip}\""
    node_ips_array="${node_ips_array}\"${pve_host_ip}\""
  fi
  
  node_names_array="${node_names_array}]"
  node_ips_array="${node_ips_array}]"
  vm_distribution_map="${vm_distribution_map}}"
  
  # Write terraform.tfvars file
  {
    echo "# Terraform Variables File"
    echo "# Generated by setup.sh script on $(date)"
    echo ""
    echo "# Proxmox Connection"
    echo "proxmox_api_url = \"$proxmox_api_url\""
    echo "proxmox_api_user = \"$proxmox_api_user\""
    echo "proxmox_api_token = \"$proxmox_api_token\""
    echo ""
    echo "# PVE Host Configuration"
    echo "pve_host_ip = \"$pve_host_ip\""
    echo "pve_clustered = $pve_clustered"
    echo "pve_cluster_name = \"$pve_cluster_name\""
    echo ""
    echo "# Node Configuration"
    echo "node_names = $node_names_array"
    echo "node_ips = $node_ips_array"
    echo ""
    if [ "$pve_clustered" = "true" ]; then
      echo "# VM Distribution (Clustered)"
      echo "vm_distribution = $vm_distribution_map"
    else
      echo "# VM Distribution (Standalone)"
      echo "vm_distribution = {}"
    fi
    echo ""
    echo "# Template Configuration"
    echo "template_id = 9000"
    echo "template_node = \"$(echo "$node_names_array" | cut -d'"' -f2)\""
    echo "create_template = true"
    echo "template_name = \"ubuntu-cloud-template\""
    echo "ubuntu_version = \"noble\""
    echo "ubuntu_image_url = \"https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img\""
    echo ""
    echo "# Storage Configuration"
    echo "storage_pool = \"$storage_pool_config\""
    echo "template_storage_pool = \"$(get_config "template_storage_pool" "local")\""
    echo "template_vm_disk_storage = \"$(get_config "template_vm_disk_storage" "$storage_pool_config")\""
    echo ""
    echo "# VM Configuration"
    echo "vm_count = $vm_count"
    echo ""
    echo "# VM Hardware Configuration"
    echo "vm_cpu_cores = $cpu_cores"
    echo "vm_cpu_type = \"$cpu_type\""
    echo "vm_memory = $ram_size"
    echo "vm_disk_size = $disk_size"
    echo "vm_machine_type = \"$machine_type\""
    echo "vm_bios_type = \"$bios_type\""
    echo "vm_efi_disk = $efi_disk"
    echo ""
    echo "# VM Network Configuration"
    echo "vm_network_bridge = \"$network_bridge\""
    echo ""
    echo "# VM User Configuration"
    echo "vm_username = \"$username\""
    if [ -n "$password" ]; then
      echo "vm_password = \"$password\""
    else
      echo "vm_password = \"\""
    fi
    echo "vm_hostname_prefix = \"$hostname_prefix\""
    echo "vm_hostname_suffix = $hostname_suffix"
    if [ -n "$ssh_keys" ]; then
      echo "vm_ssh_keys = [\"$(echo "$ssh_keys" | sed 's/,/","/g')\"]"
    else
      echo "vm_ssh_keys = []"
    fi
    echo ""
    echo "# VM Network Settings"
    echo "vm_network_cidr = \"$cidr\""
    echo "vm_starting_ip = \"$starting_ip\""
    echo "vm_gateway = \"$gateway\""
    echo ""
    echo "# Advanced Configuration"
    echo "vm_start_on_boot = true"
    echo "vm_protection = false"
    echo "vm_tags = \"terraform,setup-script\""
    echo "vm_description = \"Created by Terraform via setup.sh\""
  } > terraform/terraform.tfvars
  
  dialog --msgbox "Terraform variables file generated successfully!\n\nFile: terraform/terraform.tfvars\nReady for 'terraform apply'" 8 60
}
