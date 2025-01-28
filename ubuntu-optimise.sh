#!/bin/bash

echo "Starting Ubuntu memory optimization (Docker-aware)..."

# 1. Optimize system memory settings
echo "Configuring memory management..."
cat >> /etc/sysctl.conf << EOF

# Memory Management Optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=30
vm.dirty_background_ratio=5
vm.overcommit_memory=0
vm.overcommit_ratio=50

# Network optimizations for Docker
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192

# File handle limits
fs.file-max=2097152
fs.inotify.max_user_watches=524288
EOF

# Apply sysctl changes
sysctl -p

# 2. Configure system limits for Docker
echo "Configuring system limits..."
cat > /etc/security/limits.d/docker.conf << EOF
*         soft    nofile      1048576
*         hard    nofile      1048576
*         soft    nproc       unlimited
*         hard    nproc       unlimited
root      soft    nofile      1048576
root      hard    nofile      1048576
root      soft    nproc       unlimited
root      hard    nproc       unlimited
EOF

# 3. Optimize journal size
echo "Optimizing systemd journal..."
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/size.conf << EOF
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
RuntimeMaxUse=100M
EOF

# Restart journald
systemctl restart systemd-journald

# 4. Configure Docker daemon with memory limits
echo "Optimizing Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.size=10G"
    ]
}
EOF

# 5. Clean up old packages and cache
echo "Cleaning up system..."
apt-get clean
apt-get autoremove -y
journalctl --vacuum-size=100M

# Restart Docker to apply changes
systemctl restart docker

echo "Optimization complete! System needs to be rebooted to apply all changes."
echo "Please run: sudo reboot"