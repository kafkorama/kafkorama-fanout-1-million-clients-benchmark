#!/bin/bash
set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 <license_key>"
    echo "  license_key: Required license key for MigratoryData Benchsub"
    exit 1
}

# Check if license parameter is provided
if [[ $# -ne 1 ]]; then
    echo "Error: License key is required"
    usage
fi

LICENSE_KEY=$1

# Validate license key is not empty
if [[ -z "$LICENSE_KEY" ]]; then
    echo "Error: License key cannot be empty"
    usage
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update system packages
apt update || { echo "Failed to update packages"; exit 1; }
apt install zip unzip git gpg chrony -y || { echo "Failed to install packages"; exit 1; }

# Configure chrony for time synchronization
CHRONY_CONF="/etc/chrony/chrony.conf"
NEW_SERVER_LINE="server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4"

if [[ -f "$CHRONY_CONF" ]]; then
    # Check if the line already exists
    if ! grep -q "169.254.169.123" "$CHRONY_CONF"; then
        # Insert the new server line before any existing server/pool lines
        sed -i "1i\\$NEW_SERVER_LINE" "$CHRONY_CONF"
        echo "Added time server to chrony configuration"
        /etc/init.d/chrony restart || echo "Warning: Failed to restart chrony service"
    else
        echo "Time server already configured in chrony.conf"
    fi
else
    echo "Warning: $CHRONY_CONF not found"
fi

if [[ -f "/usr/share/keyrings/corretto-keyring.gpg" ]]; then
    echo "Corretto keyring already exists"
else
    wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
    apt-get update || { echo "Failed to update package list after adding Corretto repository"; exit 1; }
    apt-get install -y java-1.8.0-amazon-corretto-jdk || { echo "Failed to install Amazon Corretto JDK"; exit 1; }
fi

# Download and extract MigratoryData Benchsub
MIGRATORYDATA_BENCHSUB_VERSION="migratorydata-benchsub-6.0-build20250923.tar.gz"
wget "https://kafkorama.com/releases/bench/benchsub/${MIGRATORYDATA_BENCHSUB_VERSION}" || { echo "Failed to download MigratoryData Benchsub"; exit 1; }
tar zxvf "${MIGRATORYDATA_BENCHSUB_VERSION}" || { echo "Failed to extract MigratoryData Benchsub"; exit 1; }
rm "${MIGRATORYDATA_BENCHSUB_VERSION}"  # Clean up


REPLACE_LICENSE_KEY="@@REPLACE_LICENSE_KEY@@"

if [[ -f "migratorydata-benchsub.conf" ]]; then
    sed "s/$REPLACE_LICENSE_KEY/$LICENSE_KEY/" migratorydata-benchsub.conf > "migratorydata-benchsub/migratorydata-benchsub.conf"
else
    echo "Warning: migratorydata-benchsub.conf not found"
fi

# Update hosts file
if ! grep -q "10.0.1.20 gateway" /etc/hosts; then
    echo "10.0.1.20 gateway" >> /etc/hosts
fi

# Update hosts file
if ! grep -q "10.0.1.30 gateway2" /etc/hosts; then
    echo "10.0.1.30 gateway2" >> /etc/hosts
fi

# Update hosts file
if ! grep -q "10.0.1.40 gateway3" /etc/hosts; then
    echo "10.0.1.40 gateway3" >> /etc/hosts
fi

# Update hosts file
if ! grep -q "10.0.1.50 gateway4" /etc/hosts; then
    echo "10.0.1.50 gateway4" >> /etc/hosts
fi
