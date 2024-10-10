#!/usr/bin/env bash
#
# Allow root ssh login and password auth
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

check_os() {
  if ! [ -f "/etc/debian_version" ]; then
    echo "Error: This script is only supported on Debian-based systems."
    exit 1
  fi
}

# Function to configure the Repo
configure_sshd() {
  # backup sshd_config tp sshd_config.bak.yyyymmddhhmmss
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date '+%Y%m%d%H%M%S')
  echo 'PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
PasswordAuthentication yes
PermitRootLogin yes
PasswordAuthentication yes
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server' > /etc/ssh/sshd_config

  if [ $? -ne 0 ]; then
    return 1
  fi
  # remove 'no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo 'Please login as the user \"ubuntu\" rather than the user \"root\".';echo;sleep 10;exit 142" ' from /root/.ssh/authorized_keys
  sed -i 's/^.*exit 142.*ssh-ed25519/ssh-ed25519/' /root/.ssh/authorized_keys
  if [ $? -ne 0 ]; then
    return 1
  fi
  # Restart sshd
  if ! service ssh restart; then
      handle_error "$?" "Failed to run 'service ssh restart'"
  fi
  log "ssh is configured to allow root login successfully."
  log "PasswordAuthentication is enabled."
  log ""
  log "Please set root password with 'sudo passwd root' command."
}

# Check OS
check_os

# Main execution
configure_sshd || handle_error $? "Failed configuring sshd to allow password authentication"

} # this ensures the entire script is downloaded #