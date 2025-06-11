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
ESSENTIAL_BUILD_PACKAGES=(
    "build-essential" "gcc" "g++" "make" "libc6-dev" "linux-libc-dev"
    "binutils" "cpp" "gcc-11" "g++-11" "libc-dev-bin" "libgcc-s1" "libstdc++6"
)
CRYPTO_SSL_PACKAGES=("libssl-dev" "libssl3" "openssl" "ca-certificates")
COMPRESSION_PACKAGES=("zlib1g-dev" "zlib1g" "liblzma-dev" "liblzma5")
REGEX_PACKAGES=("libpcre3-dev" "libpcre3" "libpcre2-dev" "libpcre2-8-0")
NETWORKING_PACKAGES=(
    "libnl-3-dev" "libnl-3-200" "libnl-genl-3-dev" "libnl-genl-3-200"
    "libnl-route-3-dev" "libnl-route-3-200" "libmnl-dev" "libmnl0"
)
SYSTEM_PACKAGES=("libsystemd-dev" "libsystemd0" "pkg-config" "rsyslog" "logrotate" "psmisc")
IPTABLES_PACKAGES=(
    "iptables" "iptables-dev" "libip4tc2" "libip6tc2" "libiptc0"
    "libnetfilter-conntrack3" "libnfnetlink0"
)
RUNTIME_PACKAGES=("adduser" "lsb-base" "libc6" "libgcc-s1" "init-system-helpers")

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

# Try to get HAProxy and Keepalived from Ubuntu repos for dependencies
cd temp_download
if apt download haproxy 2>/dev/null; then
    echo "  ✓ Downloaded HAProxy from Ubuntu repos"
    get_recursive_deps "haproxy"
else
    echo "  ⚠ HAProxy not available in Ubuntu repos, will compile from source only"
fi

if apt download keepalived 2>/dev/null; then
    echo "  ✓ Downloaded Keepalived from Ubuntu repos"
    get_recursive_deps "keepalived"
else
    echo "  ⚠ Keepalived not available in Ubuntu repos, will compile from source only"
fi
cd ..

# Move all .deb files and remove duplicates
echo "Organizing and deduplicating packages..."
mv temp_download/*.deb deb_files/ 2>/dev/null || echo "No .deb files to move"
rmdir temp_download 2>/dev/null || true

cd deb_files
if ls *.deb 1> /dev/null 2>&1; then
    echo "Removing duplicate packages..."
    for pkg in $(ls *.deb | sed 's/_[^_]*_[^_]*\.deb$//' | sort -u); do
        versions=($(ls ${pkg}_*.deb 2>/dev/null | sort -V))
        if [ ${#versions[@]} -gt 1 ]; then
            for ((i=0; i<${#versions[@]}-1; i++)); do
                echo "  Removing older version: ${versions[i]}"
                rm -f "${versions[i]}"
            done
        fi
    done
fi
cd ..

# Download HAProxy and Keepalived sources
HAPROXY_VERSION="2.8.5"
wget -q "http://www.haproxy.org/download/2.8/src/haproxy-${HAPROXY_VERSION}.tar.gz" -O "source_files/haproxy-${HAPROXY_VERSION}.tar.gz" || \
wget -q "http://www.haproxy.org/download/2.8/src/haproxy-2.8.3.tar.gz" -O "source_files/haproxy-2.8.3.tar.gz"

KEEPALIVED_VERSION="2.2.8"
wget -q "https://www.keepalived.org/software/keepalived-${KEEPALIVED_VERSION}.tar.gz" -O "source_files/keepalived-${KEEPALIVED_VERSION}.tar.gz" || \
wget -q "https://github.com/acassen/keepalived/archive/v${KEEPALIVED_VERSION}.tar.gz" -O "source_files/keepalived-${KEEPALIVED_VERSION}.tar.gz"

echo "✅ All dependencies and sources downloaded. See the working directory for .deb files and sources."
