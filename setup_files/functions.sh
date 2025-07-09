#!/bin/bash

# Common functions for the setup script

# Configuration file paths
CONFIG_FILE="setup_files/config.conf"
CURSOR_FILE="setup_files/cursor.conf"
STATUS_FILE="setup_files/status.conf"

# Initialize configuration files if they don't exist
init_config_files() {
  [ ! -f "$CONFIG_FILE" ] && touch "$CONFIG_FILE"
  [ ! -f "$CURSOR_FILE" ] && touch "$CURSOR_FILE"
  [ ! -f "$STATUS_FILE" ] && touch "$STATUS_FILE"
}

# Function to set configuration value
set_config() {
  local key="$1"
  local value="$2"
  init_config_files
  
  # Remove existing key and add new value
  grep -v "^${key}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || touch "${CONFIG_FILE}.tmp"
  echo "${key}=${value}" >> "${CONFIG_FILE}.tmp"
  mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

# Function to get configuration value
get_config() {
  local key="$1"
  local default="$2"
  init_config_files
  
  local value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
  echo "${value:-$default}"
}

# Function to check if a configuration key exists and has content
is_configured() {
  local key="$1"
  local value=$(get_config "$key")
  [ -n "$value" ] && return 0 || return 1
}

# Function to get checkmark or empty space for menu items
get_status_indicator() {
  local key="$1"
  if is_configured "$key"; then
    echo "✓"
  else
    echo " "
  fi
}

# Function to display breadcrumb navigation
show_breadcrumb() {
  local breadcrumb="$1"
  set_config "current_path" "$breadcrumb"
}

# Function to save cursor position
save_cursor_position() {
  local menu="$1"
  local position="$2"
  init_config_files
  
  # Remove existing cursor position and add new value
  grep -v "^${menu}=" "$CURSOR_FILE" > "${CURSOR_FILE}.tmp" 2>/dev/null || touch "${CURSOR_FILE}.tmp"
  echo "${menu}=${position}" >> "${CURSOR_FILE}.tmp"
  mv "${CURSOR_FILE}.tmp" "$CURSOR_FILE"
}

# Function to get cursor position
get_cursor_position() {
  local menu="$1"
  local default="$2"
  init_config_files
  
  local position=$(grep "^${menu}=" "$CURSOR_FILE" 2>/dev/null | cut -d'=' -f2-)
  echo "${position:-$default}"
}

# Function to set status indicator
set_status() {
  local key="$1"
  local status="$2"
  init_config_files
  
  # Remove existing status and add new value
  grep -v "^${key}=" "$STATUS_FILE" > "${STATUS_FILE}.tmp" 2>/dev/null || touch "${STATUS_FILE}.tmp"
  echo "${key}=${status}" >> "${STATUS_FILE}.tmp"
  mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Function to get status indicator from status file
get_status() {
  local key="$1"
  init_config_files
  
  local status=$(grep "^${key}=" "$STATUS_FILE" 2>/dev/null | cut -d'=' -f2-)
  if [ "$status" = "true" ]; then
    echo "✓"
  else
    echo " "
  fi
}

# Function to validate numeric input
validate_number() {
  local input="$1"
  local min="$2"
  local max="$3"
  
  if ! [[ "$input" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  
  if [ -n "$min" ] && [ "$input" -lt "$min" ]; then
    return 1
  fi
  
  if [ -n "$max" ] && [ "$input" -gt "$max" ]; then
    return 1
  fi
  
  return 0
}

# Function to validate IP address
validate_ip() {
  local ip="$1"
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    IFS='.' read -ra ADDR <<< "$ip"
    for i in "${ADDR[@]}"; do
      if [ "$i" -gt 255 ]; then
        return 1
      fi
    done
    return 0
  fi
  return 1
}

# Function to validate CIDR notation
validate_cidr() {
  local cidr="$1"
  if [[ $cidr =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    local ip=$(echo "$cidr" | cut -d'/' -f1)
    local prefix=$(echo "$cidr" | cut -d'/' -f2)
    
    if validate_ip "$ip" && [ "$prefix" -ge 1 ] && [ "$prefix" -le 32 ]; then
      return 0
    fi
  fi
  return 1
}

# Function to test SSH connection
test_ssh_connection() {
  local user="$1"
  local host="$2"
  
  echo "Testing SSH connection to $host as $user..." >> setup_files/debug.log
  
  # Test SSH connection with timeout and automatic yes to fingerprint
  ssh_result=$(timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=no "$user@$host" "echo 'SSH connection successful'" 2>&1)
  ssh_exit_code=$?
  
  echo "SSH test result: $ssh_result" >> setup_files/debug.log
  echo "SSH exit code: $ssh_exit_code" >> setup_files/debug.log
  
  if [ $ssh_exit_code -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# Function to test API connection
test_api_connection() {
  local host="$1"
  local token_id="$2"
  local token_secret="$3"
  
  echo "Testing API connection to $host..." >> setup_files/debug.log
  
  # Test API connection
  api_result=$(timeout 10 curl -k -s -o /dev/null -w "%{http_code}" \
    "https://$host:8006/api2/json/version" \
    --header "Authorization: PVEAPIToken=$token_id=$token_secret" 2>&1)
  
  echo "API test result: $api_result" >> setup_files/debug.log
  
  if [ "$api_result" = "200" ]; then
    return 0
  else
    return 1
  fi
}

# Function to get validated numeric input
get_validated_number() {
  local prompt="$1"
  local default="$2"
  local min="$3"
  local max="$4"
  local config_key="$5"
  
  while true; do
    dialog --inputbox "$prompt" 8 40 "$default" 2>setup_files/temp_input.txt
    local input=$(cat setup_files/temp_input.txt)
    
    if [ -z "$input" ]; then
      input="$default"
    fi
    
    if validate_number "$input" "$min" "$max"; then
      set_config "$config_key" "$input"
      break
    else
      local error_msg="Invalid input. Please enter a number"
      if [ -n "$min" ] && [ -n "$max" ]; then
        error_msg="$error_msg between $min and $max"
      elif [ -n "$min" ]; then
        error_msg="$error_msg greater than or equal to $min"
      elif [ -n "$max" ]; then
        error_msg="$error_msg less than or equal to $max"
      fi
      dialog --msgbox "$error_msg." 8 50
    fi
  done
}

# Function to get validated IP input
get_validated_ip() {
  local prompt="$1"
  local default="$2"
  local config_key="$3"
  
  while true; do
    dialog --inputbox "$prompt" 8 40 "$default" 2>setup_files/temp_input.txt
    local input=$(cat setup_files/temp_input.txt)
    
    if [ -z "$input" ]; then
      input="$default"
    fi
    
    if validate_ip "$input"; then
      set_config "$config_key" "$input"
      break
    else
      dialog --msgbox "Invalid IP address format. Please enter a valid IP (e.g., 192.168.1.100)." 8 50
    fi
  done
}

# Function to get validated CIDR input
get_validated_cidr() {
  local prompt="$1"
  local default="$2"
  local config_key="$3"
  
  while true; do
    dialog --inputbox "$prompt" 8 40 "$default" 2>setup_files/temp_input.txt
    local input=$(cat setup_files/temp_input.txt)
    
    if [ -z "$input" ]; then
      input="$default"
    fi
    
    if validate_cidr "$input"; then
      set_config "$config_key" "$input"
      break
    else
      dialog --msgbox "Invalid CIDR format. Please enter a valid CIDR (e.g., 10.10.0.0/24)." 8 50
    fi
  done
}
