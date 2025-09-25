
# Utils Scripts for Kafkorama benchmark

This folder contains utility scripts to help you set up, monitor, and clean up AWS infrastructure for the Kafkorama Gateway 1 Million Benchmark.

---

## 1. VPC Lifecycle Management

### Create VPC and Networking Resources

Use [`create-vpc-with-internet.sh`](utils/create-vpc-with-internet.sh) to create a VPC, subnets, internet gateway, NAT gateway, and route tables.

```sh
chmod +x create-vpc-with-internet.sh
source ./create-vpc-with-internet.sh
```

- The script generates a `values.sh` file containing resource IDs for use in benchmark tutorials.

### Delete VPC and Resources

Use [`cleanup-vpc.sh`](utils/cleanup-vpc.sh) to delete all resources created by the setup script.

```sh
chmod +x cleanup-vpc.sh
./cleanup-vpc.sh
```

---

## 2. Network Bandwidth Measurement

Measure network traffic using [`bw.sh`](utils/bw.sh).

### Prerequisites

Install the `bc` package:

```sh
apt install bc
```

Find your network interface name:

```sh
ip addr
```

### Usage

```sh
./bw.sh <interface> out   # Measure outgoing traffic
./bw.sh <interface> in    # Measure incoming traffic
```
Example:
```sh
./bw.sh ens5 out
./bw.sh ens5 in
```

---

## 3. Monitoring Setup: Grafana & Prometheus

Install and start Grafana and Prometheus using [`install-grafana.sh`](utils/install-grafana.sh):

```sh
sudo ./install-grafana.sh
```

- Access Grafana at: `http://<public-ip>:3000`
- Default credentials:
  - Username: `admin`
  - Password: `password`

---

## 4. Time Synchronization

Synchronize clocks on all EC2 machines for accurate benchmarking. See [AWS EC2 NTP documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-ec2-ntp.html).

---

## File Overview

- [`create-vpc-with-internet.sh`](utils/create-vpc-with-internet.sh): Create VPC and networking resources.
- [`cleanup-vpc.sh`](utils/cleanup-vpc.sh): Delete VPC and all associated resources.
- [`bw.sh`](utils/bw.sh): Measure network bandwidth.
- [`install-grafana.sh`](utils/install-grafana.sh): Install Grafana and Prometheus for monitoring.

---

For further details, refer to the benchmark tutorials in the main project documentation.