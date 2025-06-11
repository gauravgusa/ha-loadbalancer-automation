#dependency_collector.sh
#chmod +x dependency_collector.sh
#./dependency_collector.sh

#!/bin/bash

# Dependency Collection Script for Ubuntu 22.04
# Run this on an internet-connected Ubuntu 22.04 system

set -e

# Create working directory
mkdir -p ~/airgap_haproxy_keepalived
cd ~/airgap_haproxy_keepalived
mkdir -p deb_files source_files config_files

echo "Updating package lists..."
sudo apt update

echo "Installing apt-rdepends for dependency resolution..."
sudo apt install -y apt-rdepends

# Core build dependencies for Ubuntu 22.04
CORE_PACKAGES=(
    "build-essential"
    "gcc"
    "g++"
    "make"
    "libc6-dev"
    "linux-libc-dev"
    "libssl-dev"
    "libpcre3-dev"
    "zlib1g-dev"
    "libnl-3-dev"
    "libnl-genl-3-dev"
    "libnl-route-3-dev"
    "libiptc-dev"
    "libipset-dev"
    "libsystemd-dev"
    "pkg-config"
    "rsyslog"
)

# HAProxy specific packages
HAPROXY_PACKAGES=(
    "haproxy"
)

# Keepalived specific packages  
KEEPALIVED_PACKAGES=(
    "keepalived"
)

echo "Downloading core build dependencies..."
for package in "${CORE_PACKAGES[@]}"; do
    echo "Collecting dependencies for: $package"
    apt-rdepends "$package" 2>/dev/null | grep -v "^ " | grep -v "^Reading" | sort -u | while read dep; do
        if [ ! -z "$dep" ] && [ "$dep" != "Reverse" ]; then
            apt download "$dep" 2>/dev/null || echo "Warning: Could not download $dep"
        fi
    done
done

echo "Downloading HAProxy dependencies..."
for package in "${HAPROXY_PACKAGES[@]}"; do
    echo "Collecting dependencies for: $package"
    apt-rdepends "$package" 2>/dev/null | grep -v "^ " | grep -v "^Reading" | sort -u | while read dep; do
        if [ ! -z "$dep" ] && [ "$dep" != "Reverse" ]; then
            apt download "$dep" 2>/dev/null || echo "Warning: Could not download $dep"
        fi
    done
done

echo "Downloading Keepalived dependencies..."
for package in "${KEEPALIVED_PACKAGES[@]}"; do
    echo "Collecting dependencies for: $package"
    apt-rdepends "$package" 2>/dev/null | grep -v "^ " | grep -v "^Reading" | sort -u | while read dep; do
        if [ ! -z "$dep" ] && [ "$dep" != "Reverse" ]; then
            apt download "$dep" 2>/dev/null || echo "Warning: Could not download $dep"
        fi
    done
done

# Move all .deb files to deb_files directory
echo "Organizing .deb files..."
mv *.deb deb_files/ 2>/dev/null || echo "No additional .deb files to move"

# Remove duplicate packages
echo "Removing duplicate packages..."
cd deb_files
# Keep only the latest version of each package
ls *.deb | sed 's/_[^_]*_[^_]*\.deb$//' | sort | uniq -d | while read base; do
    # Find all versions of this package
    ls ${base}_*.deb | sort -V | head -n -1 | xargs rm -f 2>/dev/null || true
done
cd ..

echo "Downloading HAProxy source..."
wget http://www.haproxy.org/download/2.8/src/haproxy-2.8.3.tar.gz -O source_files/haproxy-2.8.3.tar.gz

echo "Downloading Keepalived source..."
wget http://www.keepalived.org/software/keepalived-2.2.8.tar.gz -O source_files/keepalived-2.2.8.tar.gz

echo "Creating HAProxy configuration..."
cat > config_files/haproxy.cfg << 'EOF'
global
    log 127.0.0.1:514 local0
    chroot /var/lib/haproxy
    stats socket /var/run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4096

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option log-health-checks
    option forwardfor
    option http-server-close
    timeout connect 5000
    timeout client 50000
    timeout server 50000
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend http_front
    bind *:80
    stats enable
    stats uri /haproxy?stats
    stats refresh 30s
    stats admin if TRUE
    default_backend web_backend

backend web_backend
    balance roundrobin
    option httpchk GET /
    server server1 192.168.1.10:80 check inter 5s fall 3 rise 2
    server server2 192.168.1.11:80 check inter 5s fall 3 rise 2
EOF

echo "Creating Keepalived master configuration..."
cat > config_files/keepalived_master.conf << 'EOF'
global_defs {
    router_id HAPROXY_MASTER
    enable_script_security
    script_user root
}

vrrp_script chk_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    timeout 2
    rise 2
    fall 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 110
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass test123
    }
    virtual_ipaddress {
        192.168.1.100/24
    }
    track_script {
        chk_haproxy
    }
    notify_master "/bin/echo 'I am now master' | /usr/bin/logger -t keepalived"
    notify_backup "/bin/echo 'I am now backup' | /usr/bin/logger -t keepalived"
    notify_fault "/bin/echo 'I am now fault' | /usr/bin/logger -t keepalived"
}
EOF

echo "Creating Keepalived backup configuration..."
cat > config_files/keepalived_backup.conf << 'EOF'
global_defs {
    router_id HAPROXY_BACKUP
    enable_script_security
    script_user root
}

vrrp_script chk_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    timeout 2
    rise 2
    fall 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass test123
    }
    virtual_ipaddress {
        192.168.1.100/24
    }
    track_script {
        chk_haproxy
    }
    notify_master "/bin/echo 'I am now master' | /usr/bin/logger -t keepalived"
    notify_backup "/bin/echo 'I am now backup' | /usr/bin/logger -t keepalived"
    notify_fault "/bin/echo 'I am now fault' | /usr/bin/logger -t keepalived"
}
EOF

echo "Creating README file..."
cat > README.md << 'EOF'
# HAProxy + Keepalived Air-gapped Installation

## Contents
- `bootstrap.sh` - Main installation script
- `deb_files/` - All required .deb packages
- `source_files/` - HAProxy and Keepalived source code
- `config_files/` - Configuration files

## Installation
1. Copy to air-gapped server
2. Extract: `tar -xzf airgap_haproxy_keepalived.tar.gz`
3. Run: `sudo ./bootstrap.sh [master|backup]`

## Configuration
Update the following in config_files/ before installation:
- Backend server IPs in haproxy.cfg
- Network interface in keepalived configs
- Virtual IP address

## Verification
- HAProxy stats: http://VIP/haproxy?stats
- Service status: systemctl status haproxy keepalived
- Logs: /var/log/haproxy/ and journalctl
EOF

# Summary of packages
echo "Creating package summary..."
echo "Package Summary:" > package_summary.txt
echo "================" >> package_summary.txt
echo "Total .deb packages: $(ls deb_files/*.deb 2>/dev/null | wc -l)" >> package_summary.txt
echo "" >> package_summary.txt
echo "Core packages:" >> package_summary.txt
ls deb_files/ | grep -E "(build-essential|gcc|make|libc6-dev)" >> package_summary.txt
echo "" >> package_summary.txt
echo "SSL/Crypto packages:" >> package_summary.txt
ls deb_files/ | grep -E "(libssl|openssl)" >> package_summary.txt
echo "" >> package_summary.txt
echo "Networking packages:" >> package_summary.txt
ls deb_files/ | grep -E "(libnl|libip)" >> package_summary.txt

# Package everything
echo "Creating final tarball..."
tar -czf airgap_haproxy_keepalived.tar.gz bootstrap.sh deb_files/ source_files/ config_files/ README.md package_summary.txt

echo "========================================"
echo "Collection completed successfully!"
echo "========================================"
echo "Final package: airgap_haproxy_keepalived.tar.gz"
echo "Size: $(du -h airgap_haproxy_keepalived.tar.gz | cut -f1)"
echo "Contents:"
echo "  - $(ls deb_files/*.deb 2>/dev/null | wc -l) .deb packages"
echo "  - HAProxy $(grep -o 'haproxy-[0-9.]*' source_files/haproxy-*.tar.gz)"
echo "  - Keepalived $(grep -o 'keepalived-[0-9.]*' source_files/keepalived-*.tar.gz)"
echo "  - Configuration files and bootstrap script"
echo "========================================"
