#!/bin/bash
set -euo pipefail

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
        systemctl restart chrony || echo "Warning: Failed to restart chrony service"
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

# Download and extract Kafka
MIGRATORYDATA_BENCHPUB_VERSION="migratorydata-benchpub-6.0-build20250924.tar.gz"
wget "https://kafkorama.com/releases/bench/benchpub/${MIGRATORYDATA_BENCHPUB_VERSION}" || { echo "Failed to download MigratoryData Benchpub"; exit 1; }
tar zxvf "${MIGRATORYDATA_BENCHPUB_VERSION}" || { echo "Failed to extract MigratoryData Benchpub"; exit 1; }
rm "${MIGRATORYDATA_BENCHPUB_VERSION}"  # Clean up

if [[ -f "migratorydata-benchpub.conf" ]]; then
    cp migratorydata-benchpub.conf migratorydata-benchpub/migratorydata-benchpub.conf
else
    echo "Warning: migratorydata-benchpub.conf not found"
fi

# Update hosts file
if ! grep -q "10.0.1.10 kafka" /etc/hosts; then
    echo "10.0.1.10 kafka" >> /etc/hosts
fi
