# Kafkorama Gateway Benchmark - 1M Clients Test

This benchmark evaluates the performance of the Kafkorama Gateway handling 1,000,000 concurrent WebSocket clients on AWS EC2 infrastructure. The test demonstrates real-time message distribution capabilities with high-throughput publish-subscribe patterns.

## Overview

This benchmark simulates a realistic messaging scenario where:
- **1,000,000 concurrent clients** connect via WebSocket to the Kafkorama Gateway
- **10,000 unique subjects** are distributed across all clients (100 clients per subject)
- **10,000 messages per second** are published through Apache Kafka
- **512-byte messages** provide realistic payload sizes
- All components run on **AWS EC2 c6a instances** in a cluster placement group for optimal network performance

## Architecture

The benchmark uses a 3-tier architecture:

1. **Kafka Machine (c6a.4xlarge)**: Runs Apache Kafka broker and message publisher
2. **Gateway Machine (c6a.4xlarge)**: Runs Kafkorama Gateway handling WebSocket connections
3. **Clients Machine (c6a.8xlarge)**: Runs 500,000 WebSocket subscribers
4. **Clients Machine (c6a.8xlarge)**: Runs 500,000 WebSocket subscribers

All machines are deployed in the same AWS placement group to minimize network latency and maximize throughput.

## Performance Target

This test validates the gateway's ability to:
- Maintain 1,000,000 concurrent WebSocket connections
- Process 10,000 messages/second with 512-byte payloads
- Achieve sub-millisecond message delivery latency
- Sustain high throughput with minimal resource overhead

### Software Versions
- Kafkorama Gateway version: 6.0.24
- MigratoryData Benchmark Publisher version: 2023.21.11
- MigratoryData Benchmark Subscriber version: 2023.21.11
- Apache Kafka version: 3.9.1


### Prepare the environment

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

## Kafka and publisher setup

#### Create KAFKA and Publishers EC2 machine

Create one EC2 instance of type c6a.4xlarge which will run Kafka and the publisher
```bash
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c6a.4xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --associate-public-ip-address --private-ip-address 10.0.1.10 --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=kafka-machine}]'  --block-device-mappings '[
    {
      "DeviceName": "/dev/xvda",
      "Ebs": {
        "VolumeSize": 100,
        "VolumeType": "gp3",
        "DeleteOnTermination": true,
        "Encrypted": false
      }
    }
  ]'
```

Get instance public ip

```bash
aws ec2 describe-instances --filters "Name=tag:name,Values=kafka-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

Connect to machine using command from bellow and the ip address you got from the previous command
```bash
ssh -A -i k-g-benchmark-key.pem admin@54.162.182.167
```

Install git and clone benchmark repository

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/
```

Become root user and install java and kafka
```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/commons/kafka
chmod a+x setup.sh && ./setup.sh
```

Start kafka server using `start.sh` script

```bash
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/commons/kafka/kafka_2.12-3.9.1
chmod a+x start.sh && ./start.sh
```

Additionally you can install grafana and prometheus to monitor kafkorama gateway

```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/commons/scripts
chmod a+x install-grafana.sh && ./install-grafana.sh
```

- Access Grafana at: `http://<kafka-machine-public-ip>:3000`
- Default credentials:
  - Username: `admin`
  - Password: `admin`

Go to Connections and add a new data source of type Prometheus with the following settings:
- Name: Prometheus
- URL: http://localhost:9090

Go to Dashboard and import the dashboard using the following id `14004` to monitor kafkorama gateway. Select Prometheus as data source.

Open another terminal and instal MigratoryData Benchpub

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

## Gateway setup

#### Create Gateway Machine EC2 instance machine of type c6a.8xlarge
```bash
aws ec2 run-instances --image-id ami-058bd2d568351da34 --count 1 --instance-type c5n.9xlarge --key-name kafkorama-gateway-benchmark-key --security-group-ids $SECURITY_GROUP_ID --subnet-id $PUBLIC_SUBNET_ID --private-ip-address 10.0.1.20 --associate-public-ip-address --placement "GroupName = kafkorama-gateway-benchmark" --tag-specifications 'ResourceType=instance,Tags=[{Key=name,Value=gateway-machine}]'
```

Get instance public ip

```bash
aws ec2 describe-instances --filters "Name=tag:name,Values=gateway-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

Connect to machine using command from bellow and the ip address you got from the previous command

```bash
ssh -A -i k-g-benchmark-key.pem admin@34.207.196.87
```

Install git and clone benchmark repository

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/
```


Become root user and install java

```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/gateway
chmod a+x setup.sh && ./setup.sh <license_key>
```

To run the gateway run the following command on each gateway machine
```bash
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/gateway/kafkorama-gateway
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


Get instance public ip for first machine
```bash
aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine" --query "Reservations[].Instances[].PublicIpAddress" --output text
```

Get instance public ip for second machine
```bash
aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine-2" --query "Reservations[].Instances[].PublicIpAddress" --output text
```


Connect to machine using command from bellow and the ip address you got from the previous command

```bash
# first machine
ssh -A -i k-g-benchmark-key.pem admin@52.90.15.213

# second machine
ssh -A -i k-g-benchmark-key.pem admin@54.80.219.129
```

Install git and clone benchmark repository

```bash
sudo apt update && sudo apt install git -y
git clone git@github.com:kafkorama/kafkorama-fanout-1-million-clients-benchmark.git && cd kafkorama-fanout-1-million-clients-benchmark/
```

Become root user and setup the MigratoryData benchsub clients 

```bash
sudo -i

cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/benchsub-x
chmod a+x setup.sh && ./setup.sh <license_key>
```


Connect to first machine using ssh terminal and run the following command to start the first 500k clients

```bash
ssh -A -i k-g-benchmark-key.pem admin@first_clients_machine_public_ip

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/benchsub-1/migratorydata-benchsub/
./start-migratorydata-benchsub.sh
```

```bash
ssh -A -i k-g-benchmark-key.pem admin@first_clients_machine_public_ip

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/benchsub-2/migratorydata-benchsub/
./start-migratorydata-benchsub.sh
```

Do the same for the second machine to start the other 500k clients

```bash
ssh -A -i k-g-benchmark-key.pem admin@second_clients_machine_public_ip

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/benchsub-3/migratorydata-benchsub/
./start-migratorydata-benchsub.sh
```

```bash
ssh -A -i k-g-benchmark-key.pem admin@second_clients_machine_public_ip

sudo -i
cd /home/admin/kafkorama-fanout-1-million-clients-benchmark/vertical-scaling/04-1M-clients/configs/benchsub-4/migratorydata-benchsub/
./start-migratorydata-benchsub.sh
```

#### Cleanup

Delete kafka and publisher EC2 instance
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=kafka-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

Delete clients EC2 instance
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

Delete clients EC2 instance
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=clients-machine-2" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```


Delete gateway EC2 instance
```bash
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:name,Values=gateway-machine" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text)
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

Delete vpc
```bash
chmod a+x commons/scripts/cleanup-vpc.sh && ./commons/scripts/cleanup-vpc.sh
```