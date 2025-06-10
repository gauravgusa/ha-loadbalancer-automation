# HA Load Balancer Automation Package

## Overview

This package provides complete automation for setting up a High Availability Load Balancer using HAProxy and Keepalived with Apache web servers. It supports both traditional server deployment using Ansible and Kubernetes deployment using Helm charts.

## Features

- **High Availability**: Uses Keepalived for VRRP failover
- **Load Balancing**: HAProxy with configurable algorithms
- **Health Monitoring**: Built-in health checks and statistics
- **Multi-Platform**: Supports bare metal and Kubernetes deployments
- **Automation**: Complete infrastructure as code
- **Testing**: Comprehensive test suite included

## Quick Start

1. **Configure Environment**:
   ```bash
   # Edit config/environment.conf
   VIRTUAL_IP="192.168.1.100"
   LOADBALANCER_IPS="192.168.1.101,192.168.1.102"
   WEBSERVER_IPS="192.168.1.201,192.168.1.202,192.168.1.203"
   ```

2. **Setup Configuration**:
   ```bash
   ./scripts/configure.sh
   ```

3. **Deploy Infrastructure**:
   ```bash
   ./scripts/install.sh
   ```

4. **Test Deployment**:
   ```bash
   ./scripts/test.sh
   ```

## Architecture

```
Internet → Virtual IP (HAProxy + Keepalived) → Web Servers
           ├── Load Balancer 1 (Master)
           └── Load Balancer 2 (Backup)
                           ↓
           ├── Web Server 1
           ├── Web Server 2  
           └── Web Server 3
```

## Access Points

- **Application**: http://VIRTUAL_IP
- **HAProxy Stats**: http://LOADBALANCER_IP:8404/stats
- **Credentials**: admin/secure123!
