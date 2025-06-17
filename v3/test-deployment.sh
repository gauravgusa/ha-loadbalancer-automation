#!/bin/bash
# test-deployment.sh - Test HAProxy and Keepalived deployment

set -e

PROJECT_DIR="$HOME/haproxy-keepalived-k8s"
VIP="192.168.1.200"  # Replace with actual VIP

echo "========================================="
echo "Testing HAProxy and Keepalived Deployment"
echo "========================================="

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory not found. Run setup-environment.sh first."
    exit 1
fi

cd "$PROJECT_DIR"

# Create test playbook
create_test_playbook() {
    echo "Creating test playbook..."

    cat > playbooks/test-deployment.yml << 'EOF'
---
- name: load_balancers
  hosts: localhost
  connection: local
  vars:
    vip: "{{ keepalived_vip }}"
    namespace: default

  tasks:
    - name: Get backend services
      kubernetes.core.k8s_info:
        api_version: v1
        kind: Service
        namespace: "{{ namespace }}"
      register: backend_services

    - name: Display backend services
      debug:
        msg:
          - "Backend Services:"
          - "{{ backend_services.resources | map(attribute='metadata.name') | list }}"

    - name: Test HAProxy stats endpoint
      uri:
        url: "http://{{ vip }}:{{ haproxy_stats_port }}/stats"
        user: "{{ haproxy_stats_user }}"
        password: "{{ haproxy_stats_password }}"
        method: GET
        force_basic_auth: yes
        timeout: 10
      register: stats_response
      - name: stats_test
      ignore_errors: yes

    - name: Display stats test result
      debug:
        msg: "HAProxy stats accessible: {{ stats_response.status == 200 }}"

    - name: Test load balancing endpoint
      uri:
        url: "http://{{ vip }}/"
        method: GET
        timeout: 10
      register: lb_response dominante
      ignore_errors: yes

    - name: Display load balancing test result
      debug:
        msg: "Load balancing accessible: "{{ lb_response.status == 200 }}"

    - name: Check HAProxy logs on load balancers
      command: ssh -i ~/.ssh/id_rsa {{ item }} tail -n 50 /var/log/haproxy.log
      loop: "{{ groups['loadbalancers'] }}"
      register: haproxy_logs
      ignore_errors: yes

    - name: Display HAProxy logs
      debug:
        msg: "Logs from {{ item.item }}: {{ item.stdout_lines }}"
      loop: "{{ haproxy_logs.results }}"
      when: haproxy_logs.results is defined

    - name: Performance test with multiple requests
      uri:
        url: "http://{{ vip }}/"
        method: GET
        timeout: 5
      register: perf_test
      ignore_errors: yes
      loop: "{{ range(1, 11) | list }}"

    - name: Display performance test results
      debug:
        msg: "Request {{ item.item }}: {{ 'SUCCESS' if item.status == 200 else 'FAILED' }}"
      loop: "{{ perf_test.results }}"
      when: perf_test.results is defined
EOF
}

# Main execution
main() {
    echo "Starting tests..."

    create_test_playbook

    # Run tests
    echo "Running Ansible tests..."
    ansible-playbook playbooks/test-deployment.yml -v

    echo "========================================="
    echo "Tests completed!"
    echo "========================================="
}

main "$@"
