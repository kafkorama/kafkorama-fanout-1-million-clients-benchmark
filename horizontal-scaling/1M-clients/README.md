# Kafkorama Gateway Benchmark - 1M Clients Cluster Test

This benchmark evaluates the performance of a **4-node Kafkorama Gateway cluster** handling 1,000,000 concurrent WebSocket clients on AWS EC2 infrastructure. The test demonstrates the system's horizontal scalability and load distribution capabilities across multiple gateway instances.

## Overview

This cluster benchmark simulates an enterprise-scale messaging scenario where:
- **1,000,000 concurrent clients** connect via WebSocket across 4 gateway instances (250K clients per gateway)
- **4 Kafkorama Gateway nodes** form a high-availability cluster for load distribution
- **10,000 unique subjects** are distributed across all clients (100 clients per subject)
- **10,000 messages per second** are published through Apache Kafka
- **512-byte messages** provide realistic payload sizes
- All components run on **AWS EC2 instances of type compute-optimized** in a cluster placement group for optimal network performance

## Architecture

The benchmark uses a distributed 3-tier architecture:

1. **Publisher Machine (c6a.4xlarge)**: Runs Benchmark publisher and grafana/prometheus for monitoring
2. **Gateway Cluster (4x c5n.2xlarge)**: Four gateway nodes handling WebSocket connections
3. **Client Machines (2x c6a.8xlarge)**: Distribute 1M WebSocket subscribers across all gateways
4. **Apache Kafka Cluster**: Hosted on Confluent Cloud to provide message brokering

All machines are deployed in the same AWS placement group to minimize network latency and maximize throughput between cluster nodes.

## Performance Target

This cluster test validates the system's ability to:
- Maintain 1,000,000 concurrent WebSocket connections across multiple nodes
- Distribute load evenly across 4 gateway instances
- Process 10,000 messages/second with 512-byte payloads
- Achieve sub-millisecond message delivery latency
- Maintain high availability and fault tolerance in cluster configuration
- Scale horizontally while preserving performance characteristics

## Software Versions
- Kafkorama Gateway version: 6.0.24
- MigratoryData Benchmark Publisher version: 2023.21.11
- MigratoryData Benchmark Subscriber version: 2023.21.11


### Prepare the environment

#### Start Confluent kafka cluster and create topic

Access Confluent cloud at https://confluent.cloud/ and login or create an account.

Create a standard cluster and get the bootstrap servers and api key/secret to be used later to configure Kafkorama Gateway and publisher. The access information will be needed later to configure both the Kafkorama Gateway and the publisher. For Kafkorama Gateway, the configuration files are located in the `kafkorama-gateway/addons/kafka/consumer.properties` and `kafkorama-gateway/addons/kafka/producer.properties` files. For the publisher, the configuration file is located in the `migratorydata-benchpub/config.properties` file.

Define a topic named `u` with `10` partitions and replication factor of 3.

The benchmark uses the default configurations for cluster and topic provided by Confluent. Also the Kafka clients used by Kafkorama Gateway and publisher will use the default configurations.

#### Create a placement group where all machines will be placed on the same rack
```bash
aws ec2 create-placement-group --group-name kafkorama-gateway-benchmark --strategy cluster
```

#### Create ssh key to login into EC2 machines

```bash
aws ec2 create-key-pair --key-name kafkorama-gateway-benchmark-key --query 'KeyMaterial' --output text > k-g-benchmark-key.pem
chmod 400 k-g-benchmark-key.pem
```

#### Create VPC, subnets, gateway and security group

```bash
chmod a+x commons/scripts/create-vpc-with-internet.sh
source ./commons/scripts/create-vpc-with-internet.sh
```

## Publisher and grafana/prometheus setup

#### Create Publisher EC2 machine

Create one EC2 instance of type c6a.4xlarge which will run the publisher
```bash
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c6a.4xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --associate-public-ip-address --private-ip-address 10.0.1.10 --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=publisher-machine}]'
```

Get instance public ip

```bash
aws ec2 describe-instances --filters "Name=tag:name,Values=publisher-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

Connect to machine using command from bellow and the ip address you got from the previous command
```bash
ssh -A -i k-g-benchmark-key.pem admin@13.217.196.72
```

Install git and clone benchmark repository

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/ && git checkout confluent
```

Install grafana and prometheus to monitor kafkorama gateway

```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/commons/scripts
chmod a+x install-grafana.sh && ./install-grafana.sh
```

- Access Grafana at: `http://<publisher-machine-public-ip>:3000`
- Default credentials:
  - Username: `admin`
  - Password: `admin`

Go to Connections and add a new data source of type Prometheus with the following settings:
- Name: Prometheus
- URL: http://localhost:9090

Go to Dashboard and import the dashboard using the following id `14004` to monitor kafkorama gateway. Select Prometheus as data source.

Install Java and MigratoryData Benchpub

```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/commons/benchpub
chmod a+x setup.sh && ./setup.sh
```

To start the publisher run the following command

```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/commons/benchpub/migratorydata-benchpub
./start-migratorydata-benchpub.sh
```

> Update the `migratorydata-benchpub/config.properties` file to point to the confluent kafka cluster.

## Gateway cluster setup

#### Create four Gateway EC2 instance machines of type c5n.2xlarge

```bash
# Create first gateway machine
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c5n.2xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.20 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=gateway-machine}]'

# Create second gateway machine
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c5n.2xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.30 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=gateway2-machine}]'

# Create third gateway machine
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c5n.2xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.40 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=gateway3-machine}]'

# Create fourth gateway machine
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c5n.2xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.50 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=gateway4-machine}]'

```

Get instances public ip
```bash
# Get public IP for first gateway machine
aws ec2 describe-instances --filters "Name=tag:name,Values=gateway-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text

# Get public IP for second gateway machine
aws ec2 describe-instances --filters "Name=tag:name,Values=gateway2-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text

# Get public IP for third gateway machine
aws ec2 describe-instances --filters "Name=tag:name,Values=gateway3-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text

# Get public IP for fourth gateway machine
aws ec2 describe-instances --filters "Name=tag:name,Values=gateway4-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

Connect to machine using command from bellow and the ip address you got from the previous command

```bash
ssh -A -i k-g-benchmark-key.pem admin@52.90.44.5
```

Install git and clone benchmark repository on each gateway machine

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/ && git checkout confluent
```


Become root user and install java and Kafkorama gateway on each gateway machine

```bash
sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/gateway
chmod a+x setup.sh && ./setup.sh <license_key>
```

> Before starting configure the kafkorama gateway to connect to the confluent kafka cluster. Update the `kafkorama-gateway/addons/kafka/consumer.properties` & `kafkorama-gateway/addons/kafka/producer.properties` file with the credentials provided by confluent.

To run the gateway run the following command on each gateway machine
```bash
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/gateway/kafkorama-gateway
./start-kafkorama-gateway.sh
```

## Clients setup

#### CREATE clients EC2 machine of type c6a.8xlarge

Open another terminal and run the following commands to create the machine used to connect clients to gateway.

Create two EC2 instance of type c6a.8xlarge

```bash
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c6a.8xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.60 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=clients-machine}]'
```

```bash
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c6a.8xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.70 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=clients-machine-2}]'
```


Get instances public ip
```bash
# Get public IP for first clients machine
aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text
# Get public IP for second clients machine
aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine-2" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

Connect to machine using command from bellow and the ip address you got from the previous command

```bash
ssh -A -i k-g-benchmark-key.pem admin@34.207.137.75
```


## Connect to first machine using ssh terminal and run the following command to install MigratoryData Benchsub and start the first 500k clients

Install git and clone benchmark repository

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/ && git checkout confluent
```

Become root user and setup the first 250k clients 

```bash
sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-1
chmod a+x setup.sh && ./setup.sh <license_key>
```

Start the first 250k clients

```bash
ssh -A -i k-g-benchmark-key.pem admin@eclients_machine_public_ip-1

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-1/migratorydata-benchsub
./start-migratorydata-benchsub.sh
```


Become root user and setup the next 250k clients 

```bash
sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-2
chmod a+x setup.sh && ./setup.sh <license_key>
```

Start the next 250k clients

```bash
ssh -A -i k-g-benchmark-key.pem admin@eclients_machine_public_ip-1

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-2/migratorydata-benchsub
./start-migratorydata-benchsub.sh
```


## Do the same for the second machine to start the other 500k clients


Install git and clone benchmark repository

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/ && git checkout confluent
```

Become root user and setup the first 250k clients 

```bash
sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-3
chmod a+x setup.sh && ./setup.sh <license_key>
```

Start the first 250k clients

```bash
ssh -A -i k-g-benchmark-key.pem admin@eclients_machine_public_ip-2

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-3/migratorydata-benchsub
./start-migratorydata-benchsub.sh
```


Become root user and setup the next 250k clients 

```bash
sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-4
chmod a+x setup.sh && ./setup.sh <license_key>
```

Start the next 250k clients

```bash
ssh -A -i k-g-benchmark-key.pem admin@eclients_machine_public_ip-2

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/horizontal-scaling/1M-clients/configs/benchsub-4/migratorydata-benchsub
./start-migratorydata-benchsub.sh
```


#### Cleanup

Delete kafka and publisher EC2 instance
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=publisher-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

Delete clients EC2 instances
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine-2" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

Delete gateways EC2 instance
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=gateway-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=gateway2-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=gateway3-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=gateway4-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

Delete vpc
```bash
chmod a+x commons/scripts/cleanup-vpc.sh && ./commons/scripts/cleanup-vpc.sh
```