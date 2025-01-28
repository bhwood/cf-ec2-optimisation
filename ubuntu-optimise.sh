#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (with sudo)"
    exit 1
fi

echo "Starting Ubuntu memory optimisation (Docker-aware)..."

# 1. Optimise system memory settings
echo "Configuring memory management..."
cat > /etc/sysctl.d/99-memory-optimise.conf << EOF
# Memory Management Optimisations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=30
vm.dirty_background_ratio=5
vm.overcommit_memory=0
vm.overcommit_ratio=50

# Network optimisations for Docker
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192

# File handle limits
fs.file-max=2097152
fs.inotify.max_user_watches=524288
EOF

# Apply sysctl changes
sysctl -p /etc/sysctl.d/99-memory-optimise.conf

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

# 3. Optimise journal size
echo "Optimising systemd journal..."
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/size.conf << EOF
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
RuntimeMaxUse=100M
ForwardToSyslog=no
EOF

# Restart journald
systemctl restart systemd-journald

# 4. Configure Docker daemon with memory limits
echo "Optimising Docker daemon..."
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
    "storage-driver": "overlay2"
}
EOF

# 5. Clean up old packages and cache
echo "Cleaning up system..."
apt-get clean
apt-get autoremove -y
journalctl --vacuum-size=100M

# 6. Create a daily cleanup cron job
echo "Setting up daily cleanup job..."
cat > /etc/cron.daily/docker-cleanup << EOF
#!/bin/bash
# Remove unused Docker data
docker system prune -f --volumes

# Cleanup journal
journalctl --vacuum-size=100M
EOF
chmod +x /etc/cron.daily/docker-cleanup

# 7. Enable and configure Docker limits
systemctl enable docker
mkdir -p /etc/systemd/system/docker.service.d/
cat > /etc/systemd/system/docker.service.d/memory-limits.conf << EOF
[Service]
MemoryHigh=80%
MemoryMax=90%
EOF

# Reload systemd and restart Docker
systemctl daemon-reload
systemctl restart docker || {
    echo "Docker restart failed. Rolling back daemon.json..."
    # Backup the current daemon.json
    mv /etc/docker/daemon.json /etc/docker/daemon.json.bak
    # Create a minimal daemon.json
    echo '{"storage-driver": "overlay2"}' > /etc/docker/daemon.json
    systemctl restart docker
    echo "Docker restarted with minimal configuration. Please check logs for details."
}

echo "Optimisation complete! System needs to be rebooted to apply all changes."
echo "Please run: sudo reboot"

# Print current memory usage for comparison after reboot
free -h
echo "Note these numbers for comparison after reboot."