#!/bin/bash
set -euo pipefail


# Function to display usage
usage() {
    echo "Usage: $0 <license_key>"
    echo "  license_key: Required license key for Kafkorama Gateway"
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
apt install zip unzip git gpg -y || { echo "Failed to install packages"; exit 1; }

if [[ -f "/usr/share/keyrings/corretto-keyring.gpg" ]]; then
    echo "Corretto keyring already exists"
else
    wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
    apt-get update || { echo "Failed to update package list after adding Corretto repository"; exit 1; }
    apt-get install -y java-1.8.0-amazon-corretto-jdk || { echo "Failed to install Amazon Corretto JDK"; exit 1; }
fi

# Download and extract Kafkorama Gateway
KAFKORAMA_GATEWAY="6.0.24"
KAFKORAMA_GATEWAY_VERSION="6.0.24-build20250927"
KAFKORAMA_GATEWAY_PACKAGE="kafkorama-gateway-${KAFKORAMA_GATEWAY_VERSION}.tar.gz"
if [[ ! -d "$KAFKORAMA_GATEWAY_VERSION" ]]; then
    wget "https://kafkorama.com/releases/${KAFKORAMA_GATEWAY}/${KAFKORAMA_GATEWAY_PACKAGE}" || { echo "Failed to download Kafkorama Gateway"; exit 1; }
    tar zxvf "${KAFKORAMA_GATEWAY_PACKAGE}" || { echo "Failed to extract Kafkorama Gateway"; exit 1; }
    rm "${KAFKORAMA_GATEWAY_PACKAGE}"  # Clean up
fi

REPLACE_LICENSE_KEY="@@REPLACE_LICENSE_KEY@@"

if [[ -f "kafkorama-gateway.conf" ]]; then
    sed "s/$REPLACE_LICENSE_KEY/$LICENSE_KEY/" kafkorama-gateway.conf > "kafkorama-gateway/kafkorama-gateway.conf"
else
    echo "Warning: kafkorama-gateway.conf not found"
fi

if [[ -f "addons/kafka/consumer.properties" ]]; then
    cp addons/kafka/consumer.properties kafkorama-gateway/addons/kafka/consumer.properties
else
    echo "Warning: addons/kafka/consumer.properties not found"
fi

if [[ -f "addons/kafka/producer.properties" ]]; then
    cp addons/kafka/producer.properties kafkorama-gateway/addons/kafka/producer.properties
else
    echo "Warning: addons/kafka/producer.properties not found"
fi

# Update hosts file
if ! grep -q "10.0.1.10 kafka" /etc/hosts; then
    echo "10.0.1.10 kafka" >> /etc/hosts
fi
