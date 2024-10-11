#!/usr/bin/env bash

# Allow root ssh login and password auth
# supporting OS: CentOS 7~9, Ubuntu 15~22
#
# usage: curl -fsSL https://raw.githubusercontent.com/Cojad/script/main/sshcfChange.sh | sudo -E bash
# 
{ # this ensures the entire script is downloaded #

# Logger Function
log() {
  local message="$1"
  local type="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local color
  local endcolor="\033[0m"

  case "$type" in
    "info") color="\033[38;5;79m" ;;
    "success") color="\033[1;32m" ;;
    "error") color="\033[1;31m" ;;
    *) color="\033[1;34m" ;;
  esac

  echo -e "${color}${timestamp} - ${message}${endcolor}"
}

# Error handler function  
handle_error() {
  local exit_code=$1
  local error_message="$2"
  log "Error: $error_message (Exit Code: $exit_code)" "error"
  exit $exit_code
}

# Check if running as root
if [[ "$EUID" -ne 0 ]]; then
  handle_error 1 "This script must be run as root. Use sudo."
fi

# Check if the OS is Debian-based or CentOS-based
check_os() {
  if [ -f "/etc/debian_version" ]; then
    OS="Debian"
  elif [ -f "/etc/centos-release" ]; then
    OS="CentOS"
  else
    handle_error 1 "This script is only supported on Debian-based and CentOS systems."
  fi
}

# Function to configure sshd
configure_sshd() {
  # Backup sshd_config
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date '+%Y%m%d%H%M%S')
  if [ $? -ne 0 ]; then
    handle_error $? "Failed to back up sshd_config"
  fi

  # Update sshd_config
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  if [ -f "/etc/ssh/sshd_config.d/60-cloudimg-settings.conf" ]; then
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
  fi
  # if PasswordAuthentication is not found, add it to the end of the file
  grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

  # Remove restrictive commands from authorized_keys
  sed -i 's/^.*echo;sleep 10.*ssh-rsa/ssh-rsa/' /root/.ssh/authorized_keys 2>/dev/null
  sed -i 's/^.*echo;sleep 10.*ssh-ed25519/ssh-ed25519/' /root/.ssh/authorized_keys 2>/dev/null

  # Restart SSH service
  if [ "$OS" == "Debian" ]; then
    systemctl restart ssh || handle_error $? "Failed to restart SSH service"
  else
    systemctl restart sshd || handle_error $? "Failed to restart SSHD service"
  fi

  # Log message with AWS metadata IP using IMDSv2
  local token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
  local aws_ip=$(curl -s -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/public-ipv4)

  log "SSH configured to allow root login successfully." "success"
  log "PasswordAuthentication is enabled." "success"
  log "You can now login as root user with forced password parameter using 'ssh root@$aws_ip -o PreferredAuthentications=password' command." "info"
  log "------------------------------------------"
  log "      Server IP: $aws_ip"
  log "    SSH command: ssh root@$aws_ip"
  log "Forecd password: ssh root@$aws_ip -o PreferredAuthentications=password"
  log "------------------------------------------"
  log ""
  log "You may set root password with 'sudo passwd root' command."
}

# Main script execution
check_os
configure_sshd

} # this ensures the entire script is downloaded #
