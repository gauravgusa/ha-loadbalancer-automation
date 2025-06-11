#!/bin/bash

# Directory to store .deb files
OUTPUT_DIR="deb_files"

# Packages to download dependencies for
PACKAGES="haproxy keepalived"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Update package lists
echo "Updating package lists..."
sudo apt update

# Function to download package and its dependencies
download_deb() {
    local package=$1
    echo "Resolving dependencies for $package..."
    
    # Get list of dependencies
    deps=$(apt-cache depends "$package" | grep -E 'Depends|Recommends' | awk '{print $2}' | sort -u)
    
    # Download package and dependencies
    echo "Downloading $package and its dependencies..."
    sudo apt-get download "$package"
    for dep in $deps; do
        sudo apt-get download "$dep" 2>/dev/null
    done
}

# Download .deb files for each package
for pkg in $PACKAGES; do
    download_deb "$pkg"
done

# Move all .deb files to output directory
echo "Moving .deb files to $OUTPUT_DIR..."
mv *.deb "$OUTPUT_DIR" 2>/dev/null

# Check if any .deb files were downloaded
if ls "$OUTPUT_DIR"/*.deb >/dev/null 2>&1; then
    echo "All .deb files have been downloaded to $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"
else
    echo "No .deb files were downloaded. Check for errors above."
fi
