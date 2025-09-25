#!/bin/bash

# VPC Cleanup Script
# This script will delete all the resources created by create-vpc-with-internet.sh

set -e

# Source the variables if they exist
if [ -f "vpc-variables.sh" ]; then
    source vpc-variables.sh
    echo "Loaded VPC variables from vpc-variables.sh"
else
    echo "vpc-variables.sh not found. Please provide VPC_ID manually:"
    read -p "Enter VPC_ID: " VPC_ID
fi

if [ -z "$VPC_ID" ]; then
    echo "VPC_ID is required. Exiting."
    exit 1
fi

echo "Starting cleanup of VPC: $VPC_ID"

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_id=$2
    
    case $resource_type in
        "nat-gateway")
            aws ec2 describe-nat-gateways --nat-gateway-ids $resource_id --query 'NatGateways[0].State' --output text 2>/dev/null | grep -v "deleted" >/dev/null 2>&1
            ;;
        "internet-gateway")
            aws ec2 describe-internet-gateways --internet-gateway-ids $resource_id >/dev/null 2>&1
            ;;
        "subnet")
            aws ec2 describe-subnets --subnet-ids $resource_id >/dev/null 2>&1
            ;;
        "route-table")
            aws ec2 describe-route-tables --route-table-ids $resource_id >/dev/null 2>&1
            ;;
        "security-group")
            aws ec2 describe-security-groups --group-ids $resource_id >/dev/null 2>&1
            ;;
        "vpc")
            aws ec2 describe-vpcs --vpc-ids $resource_id >/dev/null 2>&1
            ;;
    esac
}

# Step 1: Delete NAT Gateway
if [ -n "$NAT_GW_ID" ] && resource_exists "nat-gateway" "$NAT_GW_ID"; then
    echo "1. Deleting NAT Gateway: $NAT_GW_ID"
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW_ID
    echo "Waiting for NAT Gateway to be deleted..."
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW_ID
else
    echo "1. NAT Gateway not found or already deleted"
fi

# Step 2: Release Elastic IP
if [ -n "$EIP_ALLOCATION_ID" ]; then
    echo "2. Releasing Elastic IP: $EIP_ALLOCATION_ID"
    aws ec2 release-address --allocation-id $EIP_ALLOCATION_ID 2>/dev/null || echo "Elastic IP already released or not found"
else
    echo "2. Elastic IP allocation ID not found"
fi

# Step 4: Delete Subnets
if [ -n "$PUBLIC_SUBNET_ID" ] && resource_exists "subnet" "$PUBLIC_SUBNET_ID"; then
    echo "5. Deleting Public Subnet: $PUBLIC_SUBNET_ID"
    aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_ID
else
    echo "5. Public Subnet not found or already deleted"
fi

if [ -n "$PRIVATE_SUBNET_ID" ] && resource_exists "subnet" "$PRIVATE_SUBNET_ID"; then
    echo "6. Deleting Private Subnet: $PRIVATE_SUBNET_ID"
    aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_ID
else
    echo "6. Private Subnet not found or already deleted"
fi

# Step 3: Delete Route Tables (except default)
if [ -n "$PUBLIC_RT_ID" ] && resource_exists "route-table" "$PUBLIC_RT_ID"; then
    echo "3. Deleting Public Route Table: $PUBLIC_RT_ID"
    aws ec2 delete-route-table --route-table-id $PUBLIC_RT_ID
else
    echo "3. Public Route Table not found or already deleted"
fi

if [ -n "$PRIVATE_RT_ID" ] && resource_exists "route-table" "$PRIVATE_RT_ID"; then
    echo "4. Deleting Private Route Table: $PRIVATE_RT_ID"
    aws ec2 delete-route-table --route-table-id $PRIVATE_RT_ID
else
    echo "4. Private Route Table not found or already deleted"
fi

# Step 5: Delete Security Groups (except default)
if [ -n "$SECURITY_GROUP_ID" ] && resource_exists "security-group" "$SECURITY_GROUP_ID"; then
    echo "7. Deleting Security Group: $SECURITY_GROUP_ID"
    aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID
else
    echo "7. Security Group not found or already deleted"
fi

# Step 6: Detach and Delete Internet Gateway
if [ -n "$IGW_ID" ] && resource_exists "internet-gateway" "$IGW_ID"; then
    echo "8. Detaching Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID 2>/dev/null || echo "Internet Gateway already detached"
    
    echo "9. Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
else
    echo "8-9. Internet Gateway not found or already deleted"
fi

# Step 7: Delete VPC
if resource_exists "vpc" "$VPC_ID"; then
    echo "10. Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "VPC cleanup completed successfully!"
else
    echo "10. VPC not found or already deleted"
fi

# Clean up the variables file
if [ -f "vpc-variables.sh" ]; then
    rm vpc-variables.sh
    echo "Removed vpc-variables.sh"
fi
