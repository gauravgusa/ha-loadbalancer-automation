# 2. scripts/test.sh
#!/bin/bash
# scripts/test.sh

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

test_virtual_ip_connectivity() {
    log_info "Testing Virtual IP connectivity..."
    
    source "$CONFIG_FILE"
    
    if ping -c 3 -W 5 "$VIRTUAL_IP" > /dev/null 2>&1; then
        log_success "Virtual IP $VIRTUAL_IP is reachable"
    else
        log_error "Virtual IP $VIRTUAL_IP is not reachable"
        return 1
    fi
    
    if curl -f --connect-timeout 10 --max-time 30 "http://$VIRTUAL_IP" > /dev/null 2>&1; then
        log_success "HTTP service on Virtual IP is responsive"
    else
        log_error "HTTP service on Virtual IP is not responsive"
        return 1
    fi
}

test_load_balancing() {
    log_info "Testing load balancing distribution..."
    
    source "$CONFIG_FILE"
    
    declare -A server_counts
    local total_requests=20
    
    for i in $(seq 1 $total_requests); do
        response=$(curl -s --connect-timeout 5 "http://$VIRTUAL_IP" 2>/dev/null || echo "")
        if [[ -n "$response" ]]; then
            server_id=$(echo "$response" | grep -o "Server ID: [0-9]*" | grep -o "[0-9]*" || echo "unknown")
            ((server_counts[$server_id]++))
        else
            log_warning "Request $i failed"
        fi
        sleep 0.1
    done
    
    log_info "Load balancing results:"
    for server_id in "${!server_counts[@]}"; do
        local percentage=$((server_counts[$server_id] * 100 / total_requests))
        log_info "  Server $server_id: ${server_counts[$server_id]} requests ($percentage%)"
    done
    
    # Check if load balancing is working (at least 2 different servers should respond)
    if [[ ${#server_counts[@]} -ge 2 ]]; then
        log_success "Load balancing is working correctly"
    else
        log_error "Load balancing may not be working properly"
        return 1
    fi
}

test_haproxy_stats() {
    log_info "Testing HAProxy statistics interface..."
    
    source "$CONFIG_FILE"
    
    IFS=',' read -ra LB_ARRAY <<< "$LOADBALANCER_IPS"
    
    for lb_ip in "${LB_ARRAY[@]}"; do
        if curl -f --connect-timeout 5 "http://admin:secure123!@$lb_ip:8404/stats" > /dev/null 2>&1; then
            log_success "HAProxy stats accessible on $lb_ip"
        else
            log_warning "HAProxy stats not accessible on $lb_ip (may need authentication)"
        fi
    done
}

test_failover() {
    log_info "Testing failover mechanism..."
    
    source "$CONFIG_FILE"
    
    # Test if virtual IP is accessible
    if ! curl -f --connect-timeout 5 "http://$VIRTUAL_IP" > /dev/null 2>&1; then
        log_error "Cannot test failover - service not accessible"
        return 1
    fi
    
    log_info "Failover test requires manual intervention:"
    log_info "1. Stop HAProxy on the master load balancer"
    log_info "2. Verify that traffic continues to flow"
    log_info "3. Check that backup becomes master"
    log_info "4. Restart HAProxy on original master"
    log_info "Use: 'systemctl stop haproxy' and 'systemctl start haproxy'"
}

test_health_checks() {
    log_info "Testing backend health checks..."
    
    source "$CONFIG_FILE"
    
    IFS=',' read -ra WEB_ARRAY <<< "$WEBSERVER_IPS"
    
    for web_ip in "${WEB_ARRAY[@]}"; do
        if curl -f --connect-timeout 5 "http://$web_ip:8888/health" > /dev/null 2>&1; then
            log_success "Health check endpoint accessible on $web_ip"
        else
            log_warning "Health check endpoint not accessible on $web_ip"
        fi
    done
}

run_comprehensive_test() {
    log_info "Running comprehensive test suite..."
    
    local test_results=()
    
    # Run all tests
    test_virtual_ip_connectivity && test_results+=("Virtual IP: PASS") || test_results+=("Virtual IP: FAIL")
    test_load_balancing && test_results+=("Load Balancing: PASS") || test_results+=("Load Balancing: FAIL")
    test_haproxy_stats && test_results+=("HAProxy Stats: PASS") || test_results+=("HAProxy Stats: WARN")
    test_health_checks && test_results+=("Health Checks: PASS") || test_results+=("Health Checks: WARN")
    
    # Display results
    echo ""
    log_info "Test Results Summary:"
    echo "====================="
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            log_success "$result"
        elif [[ "$result" == *"WARN"* ]]; then
            log_warning "$result"
        else
            log_error "$result"
        fi
    done
    echo "====================="
}

main() {
    log_info "Starting HA Load Balancer test suite..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file $CONFIG_FILE not found"
        exit 1
    fi
    
    case "${1:-all}" in
        connectivity|conn)
            test_virtual_ip_connectivity
            ;;
        loadbalancing|lb)
            test_load_balancing
            ;;
        stats)
            test_haproxy_stats
            ;;
        health)
            test_health_checks
            ;;
        failover)
            test_failover
            ;;
        all)
            run_comprehensive_test
            ;;
        *)
            echo "Usage: $0 [connectivity|loadbalancing|stats|health|failover|all]"
            exit 1
            ;;
    esac
    
    log_success "Test suite completed!"
}

main "$@"
