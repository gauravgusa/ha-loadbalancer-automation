#!/bin/bash
# scripts/configure.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="config/environment.conf"
INVENTORY_FILE="ansible/inventory/hosts.yml"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

configure_inventory() {
    log_info "Configuring Ansible inventory..."
    
    source "$CONFIG_FILE"
    
    IFS=',' read -ra LB_ARRAY <<< "$LOADBALANCER_IPS"
    IFS=',' read -ra WEB_ARRAY <<< "$WEBSERVER_IPS"
    IFS=',' read -ra PRIORITY_ARRAY <<< "$LOADBALANCER_PRIORITY"
    
    cat > "$INVENTORY_FILE" << EOF
all:
  children:
    loadbalancers:
      hosts:
EOF
    
    # Configure load balancers
    for i in "${!LB_ARRAY[@]}"; do
        local lb_name="lb$((i+1))"
        local state="BACKUP"
        if [[ $i -eq 0 ]]; then
            state="MASTER"
        fi
        
        cat >> "$INVENTORY_FILE" << EOF
        $lb_name:
          ansible_host: ${LB_ARRAY[$i]}
          keepalived_priority: ${PRIORITY_ARRAY[$i]:-100}
          keepalived_state: $state
EOF
    done
    
    cat >> "$INVENTORY_FILE" << EOF
    webservers:
      hosts:
EOF
    
    # Configure web servers
    for i in "${!WEB_ARRAY[@]}"; do
        local web_name="web$((i+1))"
        cat >> "$INVENTORY_FILE" << EOF
        $web_name:
          ansible_host: ${WEB_ARRAY[$i]}
          server_id: $((i+1))
EOF
    done
    
    log_success "Inventory configured successfully"
}

update_group_vars() {
    log_info "Updating group variables..."
    
    source "$CONFIG_FILE"
    
    # Update all.yml with configuration values
    cat > "ansible/inventory/group_vars/all.yml" << EOF
---
# Network Configuration
virtual_ip: "$VIRTUAL_IP"
network_interface: "$NETWORK_INTERFACE"

# Authentication
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/id_rsa
ansible_become: yes

# Common Settings
timezone: "UTC"
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org

# Monitoring
enable_monitoring: true
log_level: "info"
EOF
    
    log_success "Group variables updated"
}

validate_ssh_access() {
    log_info "Validating SSH access to all hosts..."
    
    source "$CONFIG_FILE"
    
    IFS=',' read -ra ALL_IPS <<< "$LOADBALANCER_IPS,$WEBSERVER_IPS"
    
    for ip in "${ALL_IPS[@]}"; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$ip" exit 2>/dev/null; then
            log_success "SSH access to $ip: OK"
        else
            log_error "SSH access to $ip: FAILED"
            return 1
        fi
    done
}

main() {
    log_info "Starting configuration setup..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file $CONFIG_FILE not found"
        exit 1
    fi
    
    configure_inventory
    update_group_vars
    validate_ssh_access
    
    log_success "Configuration completed successfully!"
}

main "$@"