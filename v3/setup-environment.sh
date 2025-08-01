#!/bin/bash
# setup-environment.sh - Environment setup for HAProxy and Keepalived on physical nodes

set -e

echo "========================================="
echo "HAProxy Keepalived Ansible/Helm Setup"
echo "========================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install prerequisites
install_prerequisites() {
    echo "Installing prerequisites..."

    # Check for package manager
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip curl wget haproxy keepalived
    elif command_exists yum; then
        sudo yum install -y python3 python3-pip curl wget haproxy keepalived
    else
        echo "Package manager not found. Please install Python3, pip, curl, wget, haproxy, and keepalived manually."
        exit 1
    fi

    # Install Python packages
    pip3 install ansible kubernetes PyYAML

    # Install kubectl if not present
    if ! command_exists kubectl; then
        echo "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi

    # Install helm if not present
    if ! command_exists helm; then
        echo "Installing helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    # Install Ansible Kubernetes collection
    echo "Installing Ansible Kubernetes collection..."
    ansible-galaxy collection install kubernetes.core
}

# Create project structure
create_project_structure() {
    echo "Creating project structure..."

    PROJECT_DIR="$HOME/haproxy-keepalived-k8s"
    
    # Create directories
    mkdir -p $PROJECT_DIR/{inventory,playbooks,roles/haproxy-keepalived/{tasks,templates,vars},helm/haproxy-keepalived/templates,scripts}
    
    cd $PROJECT_DIR

    # Create ansible.cfg
    cat > ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = inventory/hosts.yml
roles_path = roles
stdout_callback = yaml
gathering = smart
fact_caching = memory

[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml
EOF

    # Create inventory
    cat > inventory/hosts.yml << 'EOF'
all:
  children:
    loadbalancers:
      hosts:
        lb1:
          ansible_host: 192.168.1.100  # Replace with actual IP
          ansible_user: root
        lb2:
          ansible_host: 192.168.1.101  # Replace with actual IP
          ansible_user: root
    k8s_cluster:
      hosts:
        k8snode:
          ansible_connection: local
          ansible_python_interpreter: "{{ ansible_playbook_python }}"
  vars:
    haproxy_stats_port: 8404
    haproxy_stats_user: admin
    haproxy_stats_password: admin123
    keepalived_interface: eth0
    keepalived_vip: "192.168.1.200"  # Replace with desired VIP
    keepalived_router_id: 100
    backend_servers:
      - name: web1
        address: "web1.default.svc.cluster.local"
        port: 80
        check: "check inter 2000ms rise 2 fall 3"
      - name: web2
        address: "web2.default.svc.cluster.local"
        port: 80
        check: "check inter 2000ms rise 2 fall 3"
EOF

    echo "Project structure created in $PROJECT_DIR/"
    echo "Please update inventory/hosts.yml with actual load balancer IPs and VIP."
}

# Deploy sample backend applications in Kubernetes
deploy_k8s_backends() {
    echo "Deploying sample backend applications in Kubernetes..."

    # Ensure kubeconfig is available
    if [ ! -f "$HOME/.kube/config" ]; then
        echo "Kubernetes config not found. Please set up kubeconfig."
        exit 1
    fi

    # Create web1 deployment
    kubectl create deployment web1 --image=nginx:alpine --namespace=default || true
    kubectl expose deployment web1 --port=80 --target-port=80 --namespace=default || true
    
    # Create web2 deployment
    kubectl create deployment web2 --image=httpd:alpine --namespace=default --image=httpd:2.4-alpine || true
    # Expose web2 services
    kubectl expose deployment web2 --port=80 --target-port=80 --namespace=default || true
    
    # Scale deployments
    kubectl scale deployment web1 --replicas=3 --namespace=default
    kubectl scale deployment web2 --replicas=3 --namespace=default --namespace=default
    
    # Wait for deployments
    kubectl wait --for=condition=available deployment/web1 --namespace=default --timeout=300s
    kubectl wait --for=condition=available deployment/web2 --namespace=default --timeout=300s
    
    echo "Backend applications deployed successfully in Kubernetes."
}

# Main execution
main() {
    echo "Starting setup process..."
    
    # Install prerequisites
    install_prerequisites
    
    # Create project structure
    create_project_structure
    
    # Deploy backend applications
    deploy_k8s_backends
    
    echo "========================================="
    echo "Setup completed successfully!"
    echo "========================================="
    echo "Next steps:"
    echo "1. Update inventory/hosts.yml with actual load balancer IPs and VIP"
    echo "2. cd haproxy-keepalived-k8s"
    echo "3. Deploy using Ansible: ./deploy-haproxy.sh deploy"
    echo "   or using Helm: ./deploy-haproxy.sh helm"
    echo "4. Test deployment: ./test-deployment.sh"
    echo "========================================="
}

main "$@"
