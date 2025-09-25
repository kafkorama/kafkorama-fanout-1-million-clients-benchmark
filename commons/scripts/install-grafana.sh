apt update && apt install wget curl -y

# Create directories
mkdir /etc/prometheus
mkdir /var/lib/prometheus

# Download and install Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.53.5/prometheus-2.53.5.linux-amd64.tar.gz
tar xvf prometheus-2.53.5.linux-amd64.tar.gz
cd prometheus-2.53.5.linux-amd64

# Copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

# Create Prometheus configuration
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'gateway-machine'
    static_configs:
      - targets: ['gateway:9988', 'gateway2:9988', 'gateway3:9988', 'gateway4:9988']  # Gateway machine
    scrape_interval: 5s
EOF


cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.listen-address=0.0.0.0:9090 \
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# Start Prometheus
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
systemctl status prometheus


# Install Grafana
apt-get install -y apt-transport-https software-properties-common wget
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt install grafana -y

# Start Grafana
systemctl enable grafana-server
systemctl start grafana-server
systemctl status grafana-server
