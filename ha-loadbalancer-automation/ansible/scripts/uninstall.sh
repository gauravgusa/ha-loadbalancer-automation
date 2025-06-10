# 3. scripts/uninstall.sh
#!/bin/bash
# scripts/uninstall.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE="config/environment.conf"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

confirm_uninstall() {
    log_warning "This will remove the entire HA Load Balancer setup!"
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi
}

uninstall_services() {
    log_info "Stopping and removing services..."
    
    source "$CONFIG_FILE"
    
    # Create uninstall playbook
    cat > ansible/playbooks/uninstall.yml << 'EOF'
---
- name: Uninstall HA Load Balancer Services
  hosts: loadbalancers
  become: yes
  tasks:
    - name: Stop services
      systemd:
        name: "{{ item }}"
        state: stopped
        enabled: no
      loop:
        - haproxy
        - keepalived
      ignore_errors: yes

    - name: Remove packages
      apt:
        name:
          - haproxy
          - keepalived
        state: absent
        purge: yes

    - name: Remove configuration files
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /etc/haproxy
        - /etc/keepalived
        - /var/lib/haproxy

    - name: Reset firewall rules
      ufw:
        state: reset
      ignore_errors: yes

- name: Uninstall Web Servers
  hosts: webservers
  become: yes
  tasks:
    - name: Stop Apache2
      systemd:
        name: apache2
        state: stopped
        enabled: no
      ignore_errors: yes

    - name: Remove Apache2
      apt:
        name: apache2
        state: absent
        purge: yes

    - name: Remove web content
      file:
        path: /var/www/ha-webserver
        state: absent

    - name: Reset firewall rules
      ufw:
        state: reset
      ignore_errors: yes
EOF
    
    # Run uninstall playbook
    ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/uninstall.yml --ask-become-pass
    
    # Remove uninstall playbook
    rm -f ansible/playbooks/uninstall.yml
    
    log_success "Services uninstalled successfully"
}

uninstall_kubernetes() {
    log_info "Removing Kubernetes deployment..."
    
    if command -v helm &> /dev/null; then
        helm uninstall ha-loadbalancer --namespace ha-loadbalancer 2>/dev/null || true
        log_success "Helm release removed"
    fi
    
    if command -v kubectl &> /dev/null; then
        kubectl delete namespace ha-loadbalancer 2>/dev/null || true
        log_success "Kubernetes namespace removed"
    fi
}

cleanup_local_files() {
    log_info "Cleaning up local files..."
    
    # Remove generated inventory if it exists
    if [[ -f "ansible/inventory/hosts.yml.backup" ]]; then
        mv ansible/inventory/hosts.yml.backup ansible/inventory/hosts.yml
    fi
    
    # Remove any temporary files
    find . -name "*.tmp" -delete 2>/dev/null || true
    find . -name "*.log" -delete 2>/dev/null || true
    
    log_success "Local cleanup completed"
}

main() {
    log_info "Starting HA Load Balancer uninstallation..."
    
    # Parse command line arguments
    local force=false
    local k8s_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            --kubernetes-only|-k)
                k8s_only=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--force|-f] [--kubernetes-only|-k] [--help|-h]"
                echo "  --force, -f           Skip confirmation prompt"
                echo "  --kubernetes-only, -k Only remove Kubernetes deployment"
                echo "  --help, -h           Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option $1"
                exit 1
                ;;
        esac
    done
    
    if [[ "$force" != "true" ]]; then
        confirm_uninstall
    fi
    
    if [[ "$k8s_only" == "true" ]]; then
        uninstall_kubernetes
    else
        if [[ -f "$CONFIG_FILE" ]]; then
            uninstall_services
        else
            log_warning "Configuration file not found, skipping service removal"
        fi
        uninstall_kubernetes
        cleanup_local_files
    fi
    
    log_success "HA Load Balancer uninstallation completed!"
}

main "$@"