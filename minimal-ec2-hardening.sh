#!/bin/bash

# Minimal EC2 Ubuntu Hardening Script
# Designed for EC2 Image Builder compatibility
# Avoids operations that can cause bootstrap failures

set -e  # Exit on error but don't use pipefail in pipeline environments

# Basic logging
exec > >(tee -a /var/log/ec2-hardening.log)
exec 2>&1

echo "$(date): Starting minimal EC2 Ubuntu hardening"

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Function to safely run commands
safe_run() {
    echo "Running: $*"
    if ! "$@"; then
        echo "Warning: Command failed: $*"
        return 1
    fi
    return 0
}

# Check if we're root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Must run as root"
    exit 1
fi

# Update package lists (essential for pipeline)
echo "Updating package lists..."
safe_run apt-get update -y

# Install essential security packages
echo "Installing essential security packages..."
safe_run apt-get install -y \
    unattended-upgrades \
    fail2ban \
    ufw \
    libpam-tmpdir

# Configure unattended upgrades
echo "Configuring unattended upgrades..."
safe_run dpkg-reconfigure -f noninteractive unattended-upgrades

# Basic SSH hardening (pipeline-safe)
echo "Applying basic SSH hardening..."
if [ -f /etc/ssh/sshd_config ]; then
    # Backup original
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Apply safe SSH settings
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Don't restart SSH in pipeline - let it restart on boot
    echo "SSH configuration updated (will take effect on next boot)"
fi

# Basic firewall setup (very conservative)
echo "Configuring basic firewall..."
safe_run ufw --force reset
safe_run ufw default deny incoming
safe_run ufw default allow outgoing
safe_run ufw allow ssh
safe_run ufw --force enable

# Configure fail2ban
echo "Configuring fail2ban..."
safe_run systemctl enable fail2ban
# Don't start services in pipeline - let them start on boot

# Basic sysctl hardening (minimal set)
echo "Applying basic sysctl hardening..."
cat > /etc/sysctl.d/99-basic-hardening.conf << 'EOF'
# Basic network hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

# Apply sysctl settings (safe for pipeline)
safe_run sysctl -p /etc/sysctl.d/99-basic-hardening.conf || true

# Basic login hardening
echo "Applying basic login hardening..."
if [ -f /etc/login.defs ]; then
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
fi

# Create login banner
echo "Creating login banner..."
cat > /etc/issue << 'EOF'
*******************************************************************
* WARNING: Unauthorized access to this system is prohibited      *
* All activities are monitored and logged.                       *
* Disconnect immediately if you are not an authorized user.      *
*******************************************************************
EOF

cp /etc/issue /etc/issue.net

# Disable unused network protocols (safe set)
echo "Disabling unused network protocols..."
cat > /etc/modprobe.d/disable-protocols.conf << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

# Clean up packages
echo "Cleaning up packages..."
safe_run apt-get autoremove -y
safe_run apt-get autoclean

# Create completion marker for pipeline validation
echo "$(date): Hardening completed successfully" > /var/log/ec2-hardening-complete.flag
chmod 644 /var/log/ec2-hardening-complete.flag

echo "$(date): Minimal EC2 Ubuntu hardening completed successfully"
echo "Reboot required to fully activate all security settings"

# Exit successfully for pipeline
exit 0