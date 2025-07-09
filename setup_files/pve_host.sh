#!/bin/bash

# PVE Host management functions

# Function to configure SSH settings with validation and testing
configure_ssh_settings() {
  while true; do
    prev_ssh_user=""
    prev_ssh_host=""
    if [ -f setup_files/config.txt ]; then
      prev_ssh_user=$(grep "^ssh_user=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
      prev_ssh_host=$(grep "^ssh_host=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
    fi
    
    # Get SSH username
    while true; do
      dialog --inputbox "Enter SSH username:" 8 40 "$prev_ssh_user" 2>setup_files/temp_input.txt
      ssh_user=$(cat setup_files/temp_input.txt)
      
      if [ -z "$ssh_user" ]; then
        dialog --msgbox "Username cannot be empty. Please try again." 8 40
        continue
      fi
      break
    done
    
    # Get SSH hostname/IP with validation
    while true; do
      dialog --inputbox "Enter SSH hostname/IP:" 8 40 "$prev_ssh_host" 2>setup_files/temp_input.txt
      ssh_host=$(cat setup_files/temp_input.txt)
      
      if [ -z "$ssh_host" ]; then
        dialog --msgbox "Hostname/IP cannot be empty. Please try again." 8 40
        continue
      fi
      
      # Validate IP if it looks like an IP address
      if [[ $ssh_host =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if ! validate_ip "$ssh_host"; then
          dialog --msgbox "Invalid IP address format. Please try again." 8 40
          continue
        fi
      fi
      break
    done
    
    # Test SSH connection
    dialog --infobox "Testing SSH connection to $ssh_host..." 5 50
    if test_ssh_connection "$ssh_user" "$ssh_host"; then
      dialog --msgbox "SSH connection test successful!" 8 40
      
      # Update config file
      if [ -f setup_files/config.txt ]; then
        grep -v "^ssh_user=" setup_files/config.txt | grep -v "^ssh_host=" > setup_files/temp_config.txt
        mv setup_files/temp_config.txt setup_files/config.txt
      fi
      echo "ssh_user=$ssh_user" >> setup_files/config.txt
      echo "ssh_host=$ssh_host" >> setup_files/config.txt
      
      echo "SSH username: $ssh_user" >> setup_files/debug.log
      echo "SSH hostname/IP: $ssh_host" >> setup_files/debug.log
      break
    else
      dialog --yesno "SSH connection failed. This could be due to:\n- Host unreachable\n- SSH keys not set up\n- Firewall blocking connection\n\nWould you like to save these settings anyway?" 12 60
      if [ $? -eq 0 ]; then
        # User chose to save anyway
        if [ -f setup_files/config.txt ]; then
          grep -v "^ssh_user=" setup_files/config.txt | grep -v "^ssh_host=" > setup_files/temp_config.txt
          mv setup_files/temp_config.txt setup_files/config.txt
        fi
        echo "ssh_user=$ssh_user" >> setup_files/config.txt
        echo "ssh_host=$ssh_host" >> setup_files/config.txt
        
        echo "SSH username: $ssh_user (connection failed but saved)" >> setup_files/debug.log
        echo "SSH hostname/IP: $ssh_host (connection failed but saved)" >> setup_files/debug.log
        break
      else
        # User chose to retry
        continue
      fi
    fi
  done
}

# Function to configure API settings with validation and testing
configure_api_settings() {
  while true; do
    prev_api_host=""
    prev_api_token_id=""
    prev_api_token_secret=""
    if [ -f setup_files/config.txt ]; then
      prev_api_host=$(grep "^api_host=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
      prev_api_token_id=$(grep "^api_token_id=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
      prev_api_token_secret=$(grep "^api_token_secret=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
    fi
    
    # Get API hostname/IP with validation
    while true; do
      dialog --inputbox "Enter API hostname/IP:" 8 40 "$prev_api_host" 2>setup_files/temp_input.txt
      api_host=$(cat setup_files/temp_input.txt)
      
      if [ -z "$api_host" ]; then
        dialog --msgbox "API hostname/IP cannot be empty. Please try again." 8 40
        continue
      fi
      
      # Validate IP if it looks like an IP address
      if [[ $api_host =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if ! validate_ip "$api_host"; then
          dialog --msgbox "Invalid IP address format. Please try again." 8 40
          continue
        fi
      fi
      break
    done
    
    # Get API Token ID
    while true; do
      dialog --inputbox "Enter API Token ID:" 8 40 "$prev_api_token_id" 2>setup_files/temp_input.txt
      api_token_id=$(cat setup_files/temp_input.txt)
      
      if [ -z "$api_token_id" ]; then
        dialog --msgbox "API Token ID cannot be empty. Please try again." 8 40
        continue
      fi
      break
    done
    
    # Get API Token Secret (hidden input)
    dialog --insecure --passwordbox "Enter API Token Secret:" 8 40 "$prev_api_token_secret" 2>setup_files/temp_input.txt
    api_token_secret=$(cat setup_files/temp_input.txt)
    
    if [ -z "$api_token_secret" ]; then
      dialog --msgbox "API Token Secret cannot be empty. Please try again." 8 40
      continue
    fi
    
    # Test API connection
    dialog --infobox "Testing API connection to $api_host..." 5 50
    if test_api_connection "$api_host" "$api_token_id" "$api_token_secret"; then
      dialog --msgbox "API connection test successful!" 8 40
      
      # Update config file
      if [ -f setup_files/config.txt ]; then
        grep -v "^api_host=" setup_files/config.txt | grep -v "^api_token_id=" | grep -v "^api_token_secret=" > setup_files/temp_config.txt
        mv setup_files/temp_config.txt setup_files/config.txt
      fi
      echo "api_host=$api_host" >> setup_files/config.txt
      echo "api_token_id=$api_token_id" >> setup_files/config.txt
      echo "api_token_secret=$api_token_secret" >> setup_files/config.txt
      
      echo "API hostname/IP: $api_host" >> setup_files/debug.log
      echo "API Token ID: $api_token_id" >> setup_files/debug.log
      echo "API Token Secret: [hidden]" >> setup_files/debug.log
      break
    else
      dialog --yesno "API connection failed. This could be due to:\n- Host unreachable\n- Invalid token credentials\n- API not enabled\n- Firewall blocking port 8006\n\nWould you like to save these settings anyway?" 14 60
      if [ $? -eq 0 ]; then
        # User chose to save anyway
        if [ -f setup_files/config.txt ]; then
          grep -v "^api_host=" setup_files/config.txt | grep -v "^api_token_id=" | grep -v "^api_token_secret=" > setup_files/temp_config.txt
          mv setup_files/temp_config.txt setup_files/config.txt
        fi
        echo "api_host=$api_host" >> setup_files/config.txt
        echo "api_token_id=$api_token_id" >> setup_files/config.txt
        echo "api_token_secret=$api_token_secret" >> setup_files/config.txt
        
        echo "API hostname/IP: $api_host (connection failed but saved)" >> setup_files/debug.log
        echo "API Token ID: $api_token_id (connection failed but saved)" >> setup_files/debug.log
        echo "API Token Secret: [hidden] (connection failed but saved)" >> setup_files/debug.log
        break
      else
        # User chose to retry
        continue
      fi
    fi
  done
}

# Function to get PVE details
get_pve_details() {
  # Check if SSH credentials are configured
  if [ ! -f setup_files/config.txt ]; then
    dialog --msgbox "Please configure SSH settings first (Option 1)" 8 50
    return 1
  fi
  
  ssh_user=$(grep "^ssh_user=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
  ssh_host=$(grep "^ssh_host=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
  
  # Check if SSH credentials are not empty
  if [ -z "$ssh_user" ] || [ -z "$ssh_host" ]; then
    dialog --msgbox "SSH username and hostname/IP cannot be empty. Please configure SSH settings first (Option 1)" 8 50
    return 1
  fi
  
  echo "Connecting to Proxmox node $ssh_host as $ssh_user" >> setup_files/debug.log
  echo "Retrieving cluster information..." >> setup_files/debug.log
  
  dialog --infobox "Connecting to Proxmox host $ssh_host...\nRetrieving cluster information..." 6 50
  
  cluster_info=$(ssh $ssh_user@$ssh_host "awk '/node {/,/}/ {if (\$1 == \"name:\") name=\$2; if (\$1 == \"ring0_addr:\") ip=\$2; if (name && ip) {nodes=nodes name \" \" ip \"\\n\"; name=\"\"; ip=\"\"}} /cluster_name:/ {cluster=\$2} END {print \"Cluster Name:\", cluster; print \"Nodes:\\n\" nodes}' /etc/pve/corosync.conf") || echo "Failed to retrieve cluster information" >> setup_files/debug.log

  echo "Cluster Info: $cluster_info" >> setup_files/debug.log

  dialog --infobox "Retrieving storage pool information..." 5 50
  
  echo "Retrieving storage pool information..." >> setup_files/debug.log
  storage_pools=$(ssh $ssh_user@$ssh_host "awk '/^[a-z]+:/ {type=\$1; name=\$2} /content/ {print type, name, \$2}' /etc/pve/storage.cfg") || echo "Failed to retrieve storage pool information" >> setup_files/debug.log

  echo "Storage Pools: $storage_pools" >> setup_files/debug.log
  
  # Determine if host is part of a cluster
  cluster_name=$(echo "$cluster_info" | awk '/Cluster Name:/ {print $3}')
  node_count=$(echo "$cluster_info" | awk 'BEGIN {count=0} /Nodes:/ {in_nodes=1; next} in_nodes && NF >= 2 && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {count++} END {print count}')
  
  if [ -n "$cluster_name" ] && [ "$node_count" -gt 1 ]; then
    is_clustered="true"
  else
    is_clustered="false"
  fi
  
  # Format Cluster Nodes into a neat table
  cluster_nodes_table=$(echo "$cluster_info" | awk '
    BEGIN {
      print "==============================================="
      print "                 CLUSTER NODES                "
      print "==============================================="
      printf "%-15s | %-15s\n", "Node Name", "IP Address"
      print "-----------------------------------------------"
      in_nodes=0
    }
    /Nodes:/ {in_nodes=1; next}
    in_nodes && NF >= 2 && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
      printf "%-15s | %-15s\n", $1, $2
    }
    END {
      print "==============================================="
    }
  ')

  # Format Storage Pools into a neat table
  storage_pools_table=$(echo "$storage_pools" | awk '
    BEGIN {
      print ""
      print "==============================================="
      print "                STORAGE POOLS                "
      print "==============================================="
      printf "%-8s | %-12s | %-25s\n", "Type", "Name", "Contents"
      print "-----------------------------------------------"
    }
    NF >= 3 {
      # Remove colon from type for display
      gsub(/:/, "", $1)
      printf "%-8s | %-12s | %-25s\n", $1, $2, $3
    }
    END {
      print "==============================================="
    }
  ')

  # Extract node information into variables with proper Terraform syntax
  node_variables=$(echo "$cluster_info" | awk '
    BEGIN {i=1; in_nodes=0} 
    /Nodes:/ {in_nodes=1; next}
    in_nodes && NF >= 2 && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
      print "node" i "_name = \"" $1 "\""
      print "node" i "_ip = \"" $2 "\""
      i++
    }
  ')

  # Extract storage pool information into variables with generic names
  storage_variables=$(echo "$storage_pools" | awk '
    BEGIN {i=1}
    NF >= 3 {
      # Remove colon from type
      gsub(/:/, "", $1)
      print "storage_" i "_name = \"" $2 "\""
      print "storage_" i "_type = \"" $1 "\""
      print "storage_" i "_contents = \"" $3 "\""
      i++
    }
  ')

  # Get API configuration from config.txt
  api_host=$(grep "^api_host=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
  api_token_id=$(grep "^api_token_id=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
  api_token_secret=$(grep "^api_token_secret=" setup_files/config.txt 2>/dev/null | cut -d'=' -f2)
  
  # Build API URL and token
  if [ -n "$api_host" ]; then
    proxmox_api_url="https://$api_host:8006/api2/json"
  else
    proxmox_api_url=""
  fi
  
  # For bpg/proxmox provider, we need the full token as password
  if [ -n "$api_token_id" ] && [ -n "$api_token_secret" ]; then
    proxmox_api_token="$api_token_id=$api_token_secret"
  else
    proxmox_api_token=""
  fi
  
  # Write variables to tfvars file with proper format
  {
    echo "# Proxmox Host Configuration"
    echo "pve_host_ip = \"$ssh_host\""
    echo "pve_clustered = $is_clustered"
    echo "pve_cluster_name = \"$cluster_name\""
    echo ""
    echo "# Proxmox API Configuration"
    echo "proxmox_api_url = \"$proxmox_api_url\""
    echo "proxmox_api_user = \"$api_token_id\""
    echo "proxmox_api_token = \"$proxmox_api_token\""
    echo ""
    echo "# Proxmox Nodes"
    echo "$node_variables"
    echo ""
    echo "# Storage Pools"
    echo "$storage_variables"
  } > setup_files/from-setup.tfvars

  # Create cluster status table
  cluster_status_table=$(cat <<EOF
===============================================
                CLUSTER STATUS               
===============================================
Cluster Name    : $cluster_name
Node Count      : $node_count
Is Clustered    : $is_clustered
===============================================
EOF
)

  echo -e "$cluster_status_table\n$cluster_nodes_table\n$storage_pools_table" > setup_files/details.txt
  echo "Cluster Info: $cluster_info" >> setup_files/debug.log
  echo "Storage Pools: $storage_pools" >> setup_files/debug.log
  echo "Is Clustered: $is_clustered" >> setup_files/debug.log
  
  dialog --msgbox "Successfully retrieved Proxmox host information!\n\nCluster: $cluster_name\nNodes: $node_count\nClustered: $is_clustered" 10 50
}

# Function to view PVE information
view_pve_information() {
  if [ ! -f setup_files/details.txt ]; then
    dialog --msgbox "No information available. Please run 'Get Details' first." 8 50
    return 1
  fi
  
  dialog --textbox setup_files/details.txt 30 100
}
