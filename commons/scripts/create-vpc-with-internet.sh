#!/bin/bash

# AWS VPC Creation Script with Internet Access
# This script creates a complete VPC infrastructure with public and private subnets,
# internet gateway, NAT gateway, and proper routing

set -e  # Exit on any error

# Configuration variables
VPC_NAME="k-g-cluster"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"
AVAILABILITY_ZONE="us-east-1a"
PRIVATE_AZ="us-east-1a"

echo "Creating VPC infrastructure..."

# Step 1: Create VPC
echo "1. Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC created with ID: $VPC_ID"

# Enable DNS hostnames for the VPC
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Step 2: Create Internet Gateway
echo "2. Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$VPC_NAME-igw}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

echo "Internet Gateway created with ID: $IGW_ID"

# Step 3: Attach Internet Gateway to VPC
echo "3. Attaching Internet Gateway to VPC..."
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Step 4: Create Public Subnet
echo "4. Creating Public Subnet..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_CIDR \
    --availability-zone $AVAILABILITY_ZONE \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-public-subnet}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Public Subnet created with ID: $PUBLIC_SUBNET_ID"

# Enable auto-assign public IP for public subnet
aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_ID --map-public-ip-on-launch

# Step 5: Create Private Subnet
echo "5. Creating Private Subnet..."
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_CIDR \
    --availability-zone $PRIVATE_AZ \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$VPC_NAME-private-subnet}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Private Subnet created with ID: $PRIVATE_SUBNET_ID"

# Step 6: Allocate Elastic IP for NAT Gateway
echo "6. Allocating Elastic IP for NAT Gateway..."
EIP_ALLOCATION_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$VPC_NAME-nat-eip}]" \
    --query 'AllocationId' \
    --output text)

echo "Elastic IP allocated with ID: $EIP_ALLOCATION_ID"

# Step 7: Create NAT Gateway
echo "7. Creating NAT Gateway..."
NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_ID \
    --allocation-id $EIP_ALLOCATION_ID \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$VPC_NAME-nat-gateway}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "NAT Gateway created with ID: $NAT_GW_ID"

# Wait for NAT Gateway to become available
echo "Waiting for NAT Gateway to become available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

# Step 8: Create Route Table for Public Subnet
echo "8. Creating Route Table for Public Subnet..."
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-public-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "Public Route Table created with ID: $PUBLIC_RT_ID"

# Step 9: Add route to Internet Gateway in Public Route Table
echo "9. Adding route to Internet Gateway..."
aws ec2 create-route \
    --route-table-id $PUBLIC_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

# Step 10: Associate Public Subnet with Public Route Table
echo "10. Associating Public Subnet with Public Route Table..."
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_ID --route-table-id $PUBLIC_RT_ID

# Step 11: Create Route Table for Private Subnet
echo "11. Creating Route Table for Private Subnet..."
PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$VPC_NAME-private-rt}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "Private Route Table created with ID: $PRIVATE_RT_ID"

# Step 12: Add route to NAT Gateway in Private Route Table
echo "12. Adding route to NAT Gateway..."
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID

# Step 13: Associate Private Subnet with Private Route Table
echo "13. Associating Private Subnet with Private Route Table..."
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_ID --route-table-id $PRIVATE_RT_ID

# Step 14: Create Security Group
echo "14. Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$VPC_NAME-sg" \
    --description "$VPC_NAME security group" \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$VPC_NAME-sg}]" \
    --query 'GroupId' \
    --output text)

echo "Security Group created with ID: $SECURITY_GROUP_ID"

# Step 15: Add Security Group Rules
echo "15. Adding Security Group Rules..."

# Allow SSH from anywhere
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

# Allow Kafka port
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 9092 \
    --cidr 0.0.0.0/0

# Allow HTTP
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Allow Grafana port
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port 3000 \
    --cidr 0.0.0.0/0

# Allow all traffic within VPC
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol -1 \
    --cidr $VPC_CIDR

echo "=== VPC Infrastructure Created Successfully ==="
echo "VPC ID: $VPC_ID"
echo "Internet Gateway ID: $IGW_ID"
echo "Public Subnet ID: $PUBLIC_SUBNET_ID"
echo "Private Subnet ID: $PRIVATE_SUBNET_ID"
echo "NAT Gateway ID: $NAT_GW_ID"
echo "Elastic IP Allocation ID: $EIP_ALLOCATION_ID"
echo "Public Route Table ID: $PUBLIC_RT_ID"
echo "Private Route Table ID: $PRIVATE_RT_ID"
echo "Security Group ID: $SECURITY_GROUP_ID"

# Save variables to file for later use
cat > vpc-variables.sh << EOF
export VPC_ID="$VPC_ID"
export IGW_ID="$IGW_ID"
export PUBLIC_SUBNET_ID="$PUBLIC_SUBNET_ID"
export PRIVATE_SUBNET_ID="$PRIVATE_SUBNET_ID"
export NAT_GW_ID="$NAT_GW_ID"
export EIP_ALLOCATION_ID="$EIP_ALLOCATION_ID"
export PUBLIC_RT_ID="$PUBLIC_RT_ID"
export PRIVATE_RT_ID="$PRIVATE_RT_ID"
export SECURITY_GROUP_ID="$SECURITY_GROUP_ID"
EOF

echo ""
echo "Variables saved to vpc-variables.sh - source this file to use the IDs in other scripts:"
echo "source vpc-variables.sh"
