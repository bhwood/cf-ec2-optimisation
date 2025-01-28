#!/bin/bash

# Ubuntu EC2 Optimization Script
# Run with sudo

echo "Starting Ubuntu EC2 optimization..."

# 1. Disable unnecessary services
echo "Disabling unnecessary services..."
services_to_disable=(
    "snapd"
    "unattended-upgrades"
    "apt-daily.timer"
    "apt-daily-upgrade.timer"
)

for service in "${services_to_disable[@]}"; do
    if systemctl is-active --quiet "$service"; then
        systemctl stop "$service"
        systemctl disable "$service"
        echo "Disabled $service"
    fi
done

# 2. Optimize system memory management
echo "Optimizing system memory settings..."
cat >> /etc/sysctl.conf << EOF

# Memory Management Optimizations
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=60
vm.dirty_background_ratio=2
net.ipv4.tcp_max_syn_backlog=8096
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_tw_reuse=1
EOF

# Apply sysctl changes
sysctl -p

# 3. Configure system limits
echo "Configuring system limits..."
cat >> /etc/security/limits.conf << EOF

# System Limits Optimization
*         soft    nofile      65535
*         hard    nofile      65535
*         soft    nproc       65535
*         hard    nproc       65535
EOF

# 4. Optimize journal size
echo "Optimizing systemd journal..."
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/size.conf << EOF
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=10M
EOF

# Restart journald to apply changes
systemctl restart systemd-journald

# 5. Configure transparent hugepages for better memory management
echo "Configuring transparent hugepages..."
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
echo "never" > /sys/kernel/mm/transparent_hugepage/defrag

# Add to rc.local to persist after reboot
if [ ! -f "/etc/rc.local" ]; then
    echo '#!/bin/bash' > /etc/rc.local
    chmod +x /etc/rc.local
fi
echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag" >> /etc/rc.local

# 6. Clean up old packages and cache
echo "Cleaning up package cache..."
apt-get clean
apt-get autoremove -y

# 7. Optimize IO scheduler for SSD
echo "Optimising IO scheduler..."
for disk in $(lsblk -d -o name | grep -v NAME); do
    if [ -f "/sys/block/$disk/queue/scheduler" ]; then
        echo "none" > "/sys/block/$disk/queue/scheduler"
    fi
done

echo "Optimisation complete! Please reboot your instance to apply all changes."