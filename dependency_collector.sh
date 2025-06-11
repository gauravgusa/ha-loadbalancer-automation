#!/bin/bash

# Safe Dependency Collection Script for Ubuntu 22.04
# Uses only standard Ubuntu repositories - no external repos
# Run this on an internet-connected Ubuntu 22.04 system

set -e

# Create working directory
mkdir -p ~/airgap_haproxy_keepalived
cd ~/airgap_haproxy_keepalived
mkdir -p deb_files source_files config_files temp_download

echo "=========================================="
echo "HAProxy + Keepalived Dependency Collector"
echo "Ubuntu 22.04 LTS Compatible"
echo "=========================================="

echo "Updating package lists..."
sudo apt update

echo "Installing required tools..."
sudo apt install -y wget curl apt-rdepends

# Core build dependencies for Ubuntu 22.04
echo "Defining package lists..."
ESSENTIAL_BUILD_PACKAGES=(
    "build-essential"
    "gcc"
    "g++"
    "make"
    "libc6-dev"
    "linux-libc-dev"
    "binutils"
    "cpp"
    "gcc-11"
    "g++-11"
    "libc-dev-bin"
    "libgcc-s1"
    "libstdc++6"
)

CRYPTO_SSL_PACKAGES=(
    "libssl-dev"
    "libssl3"
    "openssl"
    "ca-certificates"
)

COMPRESSION_PACKAGES=(
    "zlib1g-dev"
    "zlib1g"
    "liblzma-dev"
    "liblzma5"
)

REGEX_PACKAGES=(
    "libpcre3-dev"
    "libpcre3"
    "libpcre2-dev"
    "libpcre2-8-0"
)

NETWORKING_PACKAGES=(
    "libnl-3-dev"
    "libnl-3-200"
    "libnl-genl-3-dev"
    "libnl-genl-3-200"
    "libnl-route-3-dev"
    "libnl-route-3-200"
    "libmnl-dev"
    "libmnl0"
)

SYSTEM_PACKAGES=(
    "libsystemd-dev"
    "libsystemd0"
    "pkg-config"
    "rsyslog"
    "logrotate"
    "psmisc"
)

IPTABLES_PACKAGES=(
    "iptables"
    "iptables-dev"
    "libip4tc2"
    "libip6tc2"
    "libiptc0"
    "libnetfilter-conntrack3"
    "libnfnetlink0"
)

# Additional runtime dependencies
RUNTIME_PACKAGES=(
    "adduser"
    "lsb-base"
    "libc6"
    "libgcc-s1"
    "init-system-helpers"
)

# Function to download packages safely
download_packages() {
    local package_list=("$@")
    local failed_packages=()
    
    for package in "${package_list[@]}"; do
        echo "Downloading: $package"
        cd temp_download
        if apt download "$package" 2>/dev/null; then
            echo "  ✓ Downloaded $package"
        else
            echo "  ⚠ Failed to download $package"
            failed_packages+=("$package")
        fi
        cd ..
    done
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        echo "Warning: Failed to download the following packages:"
        printf '  - %s\n' "${failed_packages[@]}"
    fi
}

# Function to get recursive dependencies
get_recursive_deps() {
    local package="$1"
    echo "Getting recursive dependencies for: $package"
    apt-rdepends "$package" 2>/dev/null | grep -v "^ " | grep -v "^Reading" | grep -v "^$" | sort -u | while read dep; do
        if [ ! -z "$dep" ] && [ "$dep" != "Reverse" ] && [ "$dep" != "$package" ]; then
            cd temp_download
            apt download "$dep" 2>/dev/null || echo "  ⚠ Could not download dependency: $dep"
            cd ..
        fi
    done
}

echo "Downloading essential build packages..."
download_packages "${ESSENTIAL_BUILD_PACKAGES[@]}"

echo "Downloading crypto/SSL packages..."
download_packages "${CRYPTO_SSL_PACKAGES[@]}"

echo "Downloading compression packages..."
download_packages "${COMPRESSION_PACKAGES[@]}"

echo "Downloading regex packages..."
download_packages "${REGEX_PACKAGES[@]}"

echo "Downloading networking packages..."
download_packages "${NETWORKING_PACKAGES[@]}"

echo "Downloading system packages..."
download_packages "${SYSTEM_PACKAGES[@]}"

echo "Downloading iptables packages..."
download_packages "${IPTABLES_PACKAGES[@]}"

echo "Downloading runtime packages..."
download_packages "${RUNTIME_PACKAGES[@]}"

# Try to get HAProxy from Ubuntu repos (will be older version, but for dependencies)
echo "Attempting to download HAProxy from Ubuntu repositories..."
cd temp_download
if apt download haproxy 2>/dev/null; then
    echo "  ✓ Downloaded HAProxy from Ubuntu repos"
    # Get HAProxy dependencies
    get_recursive_deps "haproxy"
else
    echo "  ⚠ HAProxy not available in Ubuntu repos, will compile from source only"
fi

# Try to get Keepalived from Ubuntu repos
echo "Attempting to download Keepalived from Ubuntu repositories..."
if apt download keepalived 2>/dev/null; then
    echo "  ✓ Downloaded Keepalived from Ubuntu repos"
    # Get Keepalived dependencies
    get_recursive_deps "keepalived"
else
    echo "  ⚠ Keepalived not available in Ubuntu repos, will compile from source only"
fi
cd ..

# Move all .deb files and remove duplicates
echo "Organizing and deduplicating packages..."
mv temp_download/*.deb deb_files/ 2>/dev/null || echo "No .deb files to move"
rmdir temp_download 2>/dev/null || true

# Remove duplicate packages (keep latest version)
cd deb_files
if ls *.deb 1> /dev/null 2>&1; then
    echo "Removing duplicate packages..."
    # Group by package name and keep only the latest version
    for pkg in $(ls *.deb | sed 's/_[^_]*_[^_]*\.deb$//' | sort -u); do
        versions=($(ls ${pkg}_*.deb 2>/dev/null | sort -V))
        if [ ${#versions[@]} -gt 1 ]; then
            # Remove all but the last (latest) version
            for ((i=0; i<${#versions[@]}-1; i++)); do
                echo "  Removing older version: ${versions[i]}"
                rm -f "${versions[i]}"
            done
        fi
    done
fi
cd ..

echo "Downloading HAProxy source code..."
# Download HAProxy 2.8 LTS (Long Term Support)
HAPROXY_VERSION="2.8.5"
if wget -q "http://www.haproxy.org/download/2.8/src/haproxy-${HAPROXY_VERSION}.tar.gz" -O "source_files/haproxy-${HAPROXY_VERSION}.tar.gz"; then
    echo "  ✓ Downloaded HAProxy ${HAPROXY_VERSION}"
else
    echo "  ⚠ Failed to download HAProxy ${HAPROXY_VERSION}, trying alternative..."
    # Try older version as fallback
    HAPROXY_VERSION="2.8.3"
    if wget -q "http://www.haproxy.org/download/2.8/src/haproxy-${HAPROXY_VERSION}.tar.gz" -O "source_files/haproxy-${HAPROXY_VERSION}.tar.gz"; then
        echo "  ✓ Downloaded HAProxy ${HAPROXY_VERSION} (fallback)"
    else
        echo "  ✗ Failed to download HAProxy source"
        exit 1
    fi
fi

echo "Downloading Keepalived source code..."
# Download Keepalived stable version
KEEPALIVED_VERSION="2.2.8"
if wget -q "https://www.keepalived.org/software/keepalived-${KEEPALIVED_VERSION}.tar.gz" -O "source_files/keepalived-${KEEPALIVED_VERSION}.tar.gz"; then
    echo "  ✓ Downloaded Keepalived ${KEEPALIVED_VERSION}"
else
    echo "  ⚠ Failed to download from keepalived.org, trying GitHub..."
    if wget -q "https://github.com/acassen/keepalived/archive/v${KEEPALIVED_VERSION}.tar.gz" -O "source_files/keepalived-${KEEPALIVED_VERSION}.tar.gz"; then
        echo "  ✓ Downloaded Keepalived ${KEEPALIVED_VERSION} from GitHub"
    else
        echo "  ✗ Failed to download Keepalived source"
        exit 1
    fi
fi

echo "Creating optimized HAProxy configuration..."
cat > config_files/haproxy.cfg << 'EOF'
global
    log 127.0.0.1:514 local0 info
    chroot /var/lib/haproxy
    stats socket /var/run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    
    # Security
    ssl-default-bind-ciphers ECDHE+AESGCM:ECDHE+CHACHA20:RSA+AESGCM:RSA+SHA256:DHE+SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    
    # Performance
    maxconn 4096
    tune.ssl.default-dh-param 2048

defaults
    mode http
    log global
    option httplog
    option dontlognull
    option log-health-checks
    option forwardfor
    option http-server-close
    option httpchk GET /
    
    # Timeouts
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    timeout http-request 10s
    timeout http-keep-alive 2s
    timeout check 5s
    
    # Retry logic
    retries 3
    option redispatch

# Statistics interface
listen stats
    bind *:8404
    stats enable
    stats uri /
    stats refresh 30s
    stats admin if TRUE
    stats show-legends
    stats realm HAProxy\ Statistics

# Main frontend
frontend http_frontend
    bind *:80
    mode http
    
    # Security headers
    http-response set-header X-Frame-Options DENY
    http-response set-header X-Content-Type-Options nosniff
    http-response set-header X-XSS-Protection "1; mode=block"
    
    default_backend web_servers

# Backend servers
backend web_servers
    mode http
    balance roundrobin
    option httpchk GET /health
    
    # Health check configuration
    http-check expect status 200
    
    # Server definitions (update these IPs)
    server web1 192.168.1.10:80 check inter 5s fall 3 rise 2 weight 100
    server web2 192.168.1.11:80 check inter 5s fall 3 rise 2 weight 100
    
    # Backup server (optional)
    # server backup 192.168.1.12:80 check inter 10s fall 3 rise 2 backup
EOF

echo "Creating Keepalived master configuration..."
cat > config_files/keepalived_master.conf << 'EOF'
global_defs {
    router_id HAPROXY_MASTER
    enable_script_security
    script_user root
    enable_snmp_keepalived
}

# Health check script for HAProxy
vrrp_script chk_haproxy {
    script "/bin/curl -f http://localhost:8404/ || exit 1"
    interval 2
    timeout 2
    rise 2
    fall 2
    weight 2
}

# VRRP instance for high availability
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 110
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass haproxy123
    }
    
    virtual_ipaddress {
        192.168.1.100/24
    }
    
    track_script {
        chk_haproxy
    }
    
    # Notification scripts
    notify_master "/bin/echo 'Became MASTER' | /usr/bin/logger -t keepalived"
    notify_backup "/bin/echo 'Became BACKUP' | /usr/bin/logger -t keepalived"
    notify_fault "/bin/echo 'Entered FAULT state' | /usr/bin/logger -t keepalived"
    notify_stop "/bin/echo 'Keepalived stopped' | /usr/bin/logger -t keepalived"
}
EOF

echo "Creating Keepalived backup configuration..."
cat > config_files/keepalived_backup.conf << 'EOF'
global_defs {
    router_id HAPROXY_BACKUP
    enable_script_security
    script_user root
    enable_snmp_keepalived
}

# Health check script for HAProxy
vrrp_script chk_haproxy {
    script "/bin/curl -f http://localhost:8404/ || exit 1"
    interval 2
    timeout 2
    rise 2
    fall 2
    weight 2
}

# VRRP instance for high availability
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass haproxy123
    }
    
    virtual_ipaddress {
        192.168.1.100/24
    }
    
    track_script {
        chk_haproxy
    }
    
    # Notification scripts
    notify_master "/bin/echo 'Became MASTER' | /usr/bin/logger -t keepalived"
    notify_backup "/bin/echo 'Became BACKUP' | /usr/bin/logger -t keepalived"
    notify_fault "/bin/echo 'Entered FAULT state' | /usr/bin/logger -t keepalived"
    notify_stop "/bin/echo 'Keepalived stopped' | /usr/bin/logger -t keepalived"
}
EOF

echo "Creating updated bootstrap script reference..."
cat > UPDATE_BOOTSTRAP.md << 'EOF'
# Bootstrap Script Update Required

The bootstrap.sh script needs to be updated to use the correct HAProxy and Keepalived versions:

1. Update HAPROXY_SRC variable to match downloaded version
2. Update KEEPALIVED_SRC variable to match downloaded version
3. Ensure the script uses the new configuration files

Example updates needed in bootstrap.sh:
- HAPROXY_SRC="haproxy-2.8.5" (or whatever version was downloaded)
- KEEPALIVED_SRC="keepalived-2.2.8" (or whatever version was downloaded)
EOF

# Update the bootstrap script with correct versions
echo "Updating bootstrap script with correct versions..."
sed -i "s/HAPROXY_SRC=\"haproxy-2.8.3\"/HAPROXY_SRC=\"haproxy-${HAPROXY_VERSION}\"/g" ../bootstrap_fixed.md 2>/dev/null || true
sed -i "s/KEEPALIVED_SRC=\"keepalived-2.2.8\"/KEEPALIVED_SRC=\"keepalived-${KEEPALIVED_VERSION}\"/g" ../bootstrap_fixed.md 2>/dev/null || true

echo "Creating installation summary..."
cat > INSTALLATION_SUMMARY.txt << EOF
========================================
HAProxy + Keepalived Air-gap Package
Ubuntu 22.04 LTS Compatible
========================================

Package Versions:
- HAProxy: ${HAPROXY_VERSION}
- Keepalived: ${KEEPALIVED_VERSION}

Contents:
- $(ls deb_files/*.deb 2>/dev/null | wc -l) .deb packages for dependencies
- Source code for HAProxy and Keepalived
- Optimized configuration files
- Bootstrap installation script

Installation Instructions:
1. Copy airgap_haproxy_keepalived.tar.gz to target servers
2. Extract: tar -xzf airgap_haproxy_keepalived.tar.gz
3. Update configurations in config_files/ as needed
4. Run: sudo ./bootstrap.sh master  (on primary server)
5. Run: sudo ./bootstrap.sh backup  (on secondary server)

Configuration Notes:
- Update backend server IPs in config_files/haproxy.cfg
- Update network interface in keepalived configs (default: eth0)
- Update virtual IP address (default: 192.168.1.100)
- Update authentication password in keepalived configs

Verification:
- HAProxy stats: http://VIP:8404/
- Service status: systemctl status haproxy keepalived
- Virtual IP check: ip addr show eth0 | grep VIP
EOF

# Create the final package
echo "Creating final package..."
cd ..
tar -czf airgap_haproxy_keepalived.tar.gz -C airgap_haproxy_keepalived bootstrap.sh deb_files/ source_files/ config_files/ INSTALLATION_SUMMARY.txt UPDATE_BOOTSTRAP.md

# Final summary
echo "=========================================="
echo "✅ Package creation completed successfully!"
echo "=========================================="
echo "📦 Package: airgap_haproxy_keepalived.tar.gz"
echo "📊 Size: $(du -h airgap_haproxy_keepalived.tar.gz | cut -f1)"
echo ""
echo "📋 Contents:"
echo "   - HAProxy ${HAPROXY_VERSION} source code"
echo "   - Keepalived ${KEEPALIVED_VERSION} source code"
echo "   - $(ls airgap_haproxy_keepalived/deb_files/*.deb 2>/dev/null | wc -l) dependency packages"
echo "   - Optimized configuration files"
echo "   - Bootstrap installation script"
echo ""
echo "⚠️  Important: Update the bootstrap.sh script variables:"
echo "   - HAPROXY_SRC=\"haproxy-${HAPROXY_VERSION}\""
echo "   - KEEPALIVED_SRC=\"keepalived-${KEEPALIVED_VERSION}\""
echo ""
echo "🔧 Before installation, customize:"
echo "   - Backend server IPs in config_files/haproxy.cfg"
echo "   - Network interface in keepalived configs"
echo "   - Virtual IP address (192.168.1.100)"
echo "=========================================="
