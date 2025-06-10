bash#!/bin/bash
# scripts/install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PACKAGE_NAME="ha-loadbalancer-automation"
VERSION="1.0.0"
INSTALL_DIR="/opt/ha-loadbalancer"
CONFIG_FILE="config/environment.conf"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("ansible" "ansible-playbook" "kubectl" "helm")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is not installed"
            exit 1
        fi
    done
    
    log_success "System requirements check passed"
}

install_ansible_dependencies() {
    log_info "Installing Ansible dependencies..."
    
    # Install Ansible collections
    ansible-galaxy collection install community.general
    ansible-galaxy collection install ansible.posix
    
    log_success "Ansible dependencies installed"
}

setup_configuration() {
    log_info "Setting up configuration..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file $CONFIG_FILE not found"
        exit 1
    fi
    
    # Source configuration
    source "$CONFIG_FILE"
    
    # Validate configuration
    if [[ -z "$VIRTUAL_IP" ]] || [[ -z "$LOADBALANCER_IPS" ]] || [[ -z "$WEBSERVER_IPS" ]]; then
        log_error "Configuration validation failed. Check $CONFIG_FILE"
        exit 1
    fi
    
    log_success "Configuration validated"
}

deploy_infrastructure() {
    log_info "Deploying HA Load Balancer infrastructure..."
    
    # Deploy using Ansible
    ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml \
        --extra-vars "@config/environment.conf" \
        --ask-become-pass
    
    if [[ $? -eq 0 ]]; then
        log_success "Infrastructure deployment completed"
    else
        log_error "Infrastructure deployment failed"
        exit 1
    fi
}

deploy_kubernetes() {
    local deploy_k8s=${1:-false}
    
    if [[ "$deploy_k8s" == "true" ]]; then
        log_info "Deploying to Kubernetes..."
        
        # Create namespace
        kubectl create namespace ha-loadbalancer --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy using Helm
        helm upgrade --install ha-loadbalancer helm/ha-loadbalancer \
            --namespace ha-loadbalancer \
            --values helm/ha-loadbalancer/values.yaml
        
        if [[ $? -eq 0 ]]; then
            log_success "Kubernetes deployment completed"
        else
            log_error "Kubernetes deployment failed"
            exit 1
        fi
    fi
}

run_tests() {
    log_info "Running deployment tests..."
    
    # Source configuration for test variables
    source "$CONFIG_FILE"
    
    # Test virtual IP connectivity
    if curl -f --connect-timeout 10 "http://$VIRTUAL_IP" > /dev/null 2>&1; then
        log_success "Virtual IP connectivity test passed"
    else
        log_warning "Virtual IP connectivity test failed"
    fi
    
    # Test load balancing
    log_info "Testing load balancing..."
    for i in {1..5}; do
        response=$(curl -s "http://$VIRTUAL_IP" | grep -o "Server ID: [0-9]*" || echo "No server ID found")
        log_info "Request $i: $response"
    done
    
    # Test HAProxy stats
    IFS=',' read -ra LB_ARRAY <<< "$LOADBALANCER_IPS"
    for lb_ip in "${LB_ARRAY[@]}"; do
        if curl -f --connect-timeout 5 "http://$lb_ip:8404/stats" > /dev/null 2>&1; then
            log_success "HAProxy stats accessible on $lb_ip"
        else
            log_warning "HAProxy stats not accessible on $lb_ip"
        fi
    done
}

display_summary() {
    log_info "Deployment Summary"
    echo "===================="
    source "$CONFIG_FILE"
    echo "Virtual IP: $VIRTUAL_IP"
    echo "Load Balancers: $LOADBALANCER_IPS"
    echo "Web Servers: $WEBSERVER_IPS"
    echo "HAProxy Stats: http://${LOADBALANCER_IPS%%,*}:8404/stats"
    echo "Access URL: http://$VIRTUAL_IP"
    echo "===================="
}

main() {
    log_info "Starting $PACKAGE_NAME v$VERSION installation..."
    
    # Parse command line arguments
    local deploy_k8s=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --kubernetes|-k)
                deploy_k8s=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--kubernetes|-k] [--help|-h]"
                echo "  --kubernetes, -k    Also deploy to Kubernetes"
                echo "  --help, -h          Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option $1"
                exit 1
                ;;
        esac
    done
    
    check_requirements
    setup_configuration
    install_ansible_dependencies
    deploy_infrastructure
    deploy_kubernetes "$deploy_k8s"
    
    sleep 10  # Wait for services to start
    
    run_tests
    display_summary
    
    log_success "$PACKAGE_NAME installation completed successfully!"
}

# Trap to handle script interruption
trap 'log_error "Installation interrupted"; exit 1' INT TERM

main "$@"