#!/bin/bash

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

# Download and extract Kafka
KAFKA_VERSION="3.9.1"
KAFKA_PACKAGE="kafka_2.12-${KAFKA_VERSION}"
if [[ ! -d "$KAFKA_PACKAGE" ]]; then
    wget "https://dlcdn.apache.org/kafka/$KAFKA_VERSION/${KAFKA_PACKAGE}.tgz" || { echo "Failed to download Kafka"; exit 1; }
    tar zxvf "${KAFKA_PACKAGE}.tgz" || { echo "Failed to extract Kafka"; exit 1; }
    rm "${KAFKA_PACKAGE}.tgz"  # Clean up
fi


# Copy configuration
if [[ -f "start.sh" ]]; then
    cp start.sh "$KAFKA_PACKAGE/start.sh"
else
    echo "Warning: start.sh not found"
fi


# Configure server properties
REPLACE_IP_ID="@@REPLACE_IP_ID@@"
LOCAL_NETWORK_IP=$(hostname -I | awk '{print $1}')  # More reliable than xargs

if [[ -f "server.properties" ]]; then
    sed "s/$REPLACE_IP_ID/$LOCAL_NETWORK_IP/" server.properties > "$KAFKA_PACKAGE/config/kraft/server.properties"
else
    echo "Warning: server.properties not found"
fi

# Update hosts file
if ! grep -q "$LOCAL_NETWORK_IP kafka" /etc/hosts; then
    echo "$LOCAL_NETWORK_IP kafka" >> /etc/hosts
fi

# Create directory
mkdir -p /home/admin/disk

# Update hosts file
if ! grep -q "10.0.1.20 gateway" /etc/hosts; then
    echo "10.0.1.20 gateway" >> /etc/hosts
fi
if ! grep -q "10.0.1.30 gateway2" /etc/hosts; then
    echo "10.0.1.30 gateway2" >> /etc/hosts
fi
if ! grep -q "10.0.1.40 gateway3" /etc/hosts; then
    echo "10.0.1.40 gateway3" >> /etc/hosts
fi
if ! grep -q "10.0.1.50 gateway4" /etc/hosts; then
    echo "10.0.1.50 gateway4" >> /etc/hosts
fi

echo "Kafka setup completed successfully"