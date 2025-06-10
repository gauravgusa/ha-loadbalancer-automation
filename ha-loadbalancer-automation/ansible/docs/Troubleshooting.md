# ============================================================================

# docs/TROUBLESHOOTING.md
# Troubleshooting Guide

## Common Issues

### 1. Virtual IP Not Accessible

**Symptoms**: Cannot reach the virtual IP address

**Possible Causes**:
- Keepalived not running
- Network interface configuration
- Firewall blocking traffic
- IP conflict

**Solutions**:
```bash
# Check Keepalived status
systemctl status keepalived

# Check virtual IP assignment
ip addr show

# Check firewall rules
ufw status

# Test VRRP communication
tcpdump -i eth0 proto VRRP
```

### 2. Load Balancing Not Working

**Symptoms**: All traffic going to one server

**Possible Causes**:
- HAProxy configuration error
- Backend servers not responding to health checks
- Incorrect algorithm configuration

**Solutions**:
```bash
# Check HAProxy status
systemctl status haproxy

# View HAProxy stats
curl http://admin:secure123!@LOADBALANCER_IP:8404/stats

# Check backend health
curl http://WEBSERVER_IP:8888/health

# Review HAProxy logs
tail -f /var/log/haproxy.log
```

### 3. Services Won't Start

**Symptoms**: HAProxy or Keepalived failing to start

**Solutions**:
```bash
# Check configuration syntax
haproxy -c -f /etc/haproxy/haproxy.cfg
keepalived --config-test

# Check system logs
journalctl -u haproxy -f
journalctl -u keepalived -f

# Verify permissions
ls -la /etc/haproxy/
ls -la /etc/keepalived/
```

### 4. Ansible Deployment Fails

**Common Errors**:

**SSH Connection Issues**:
```bash
# Test SSH connectivity
ansible all -m ping -i ansible/inventory/hosts.yml

# Check SSH agent
ssh-add -l
```

**Permission Denied**:
```bash
# Ensure sudo access
ansible all -m shell -a "sudo whoami" -i ansible/inventory/hosts.yml
```

**Package Installation Fails**:
```bash
# Update package cache
ansible all -m apt -a "update_cache=yes" -i ansible/inventory/hosts.yml --become
```

### 5. Kubernetes Deployment Issues

**Pod Not Starting**:
```bash
# Check pod status
kubectl get pods -n ha-loadbalancer

# View pod logs
kubectl logs -n ha-loadbalancer deployment/ha-loadbalancer-haproxy

# Describe pod for events
kubectl describe pod -n ha-loadbalancer POD_NAME
```

**Service Not Accessible**:
```bash
# Check services
kubectl get svc -n ha-loadbalancer

# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it -- sh
curl http://ha-loadbalancer-haproxy
```

## Performance Tuning

### HAProxy Optimization
```bash
# Increase connection limits
echo "net.core.somaxconn = 4096" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 4096" >> /etc/sysctl.conf
sysctl -p
```

### System Limits
```bash
# Increase file descriptor limits
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
```

## Monitoring Commands

### Check Virtual IP Status
```bash
# On load balancers
ip addr show | grep VIRTUAL_IP
```

### Monitor Traffic
```bash
# Real-time traffic monitoring
watch -n 1 'curl -s http://VIRTUAL_IP | grep "Server ID"'
```

### Check Service Health
```bash
# Comprehensive health check
./scripts/test.sh all
```

## Recovery Procedures

### Restore from Backup
```bash
# If configurations are backed up
cp /etc/haproxy/haproxy.cfg.backup /etc/haproxy/haproxy.cfg
cp /etc/keepalived/keepalived.conf.backup /etc/keepalived/keepalived.conf
systemctl restart haproxy keepalived
```

### Emergency Shutdown
```bash
# Graceful shutdown
./scripts/uninstall.sh --force
```

## Getting Help

1. Check system logs first
2. Review configuration files
3. Test individual components
4. Use the built-in test suite
5. Check network connectivity
6. Verify firewall rules