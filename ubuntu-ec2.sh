#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Make this script executable
chmod +x "$0"

echo "[+] Running EC2-optimized Ubuntu hardening"

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Basic package updates
echo "[+] Updating APT package lists"
apt-get update -y

# Enable unattended upgrades
echo "[+] Enabling unattended-upgrades"
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# Configure login.defs
echo "[+] Applying login.defs hardening"
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'  /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs

# Configure password aging for existing users
echo "[+] Updating password aging for existing users"
for u in $(awk -F: '($3 >= 1000 && $3 < 65534) {print $1}' /etc/passwd); do
    chage --maxdays 90 --mindays 1 --warndays 14 "$u" || true
done

# Filesystem permission hardening
echo "[+] Securing /etc permissions"
chmod 0755 /etc
chmod 0644 /etc/passwd
chmod 0644 /etc/group
chmod 0640 /etc/shadow
chmod 0640 /etc/gshadow

# Disable core dumps
echo "[+] Disabling core dumps"
echo '* hard core 0' > /etc/security/limits.d/99-hardening.conf

# Configure sysctl network hardening (EC2-safe subset)
echo "[+] Applying sysctl safe network settings"
cat <<EOF >/etc/sysctl.d/99-ec2-hardening.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
kernel.kptr_restrict = 1
EOF
sysctl --system || true

# SSH hardening (EC2-safe)
echo "[+] Applying SSH hardening"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
# Keep password auth enabled for EC2 initial setup
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Remove world-writable permissions
echo "[+] Removing world-writable permissions"
find / -xdev -type f -perm -0002 -exec chmod o-w {} + 2>/dev/null || true
find / -xdev -type d -perm -0002 -exec chmod o-t {} + 2>/dev/null || true

# Enable firewall (EC2-compatible)
echo "[+] Enabling UFW firewall with EC2-safe rules"
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# Install security packages
echo "[+] Installing security packages"
apt-get install -y fail2ban auditd libpam-tmpdir apt-listchanges

# Configure fail2ban
echo "[+] Configuring fail2ban"
systemctl enable --now fail2ban
if [ -f /etc/fail2ban/jail.conf ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    chmod 600 /etc/fail2ban/jail.local
fi

# Enable auditd
echo "[+] Enabling auditd"
systemctl enable --now auditd

# Disable unused protocols (EC2-safe)
echo "[+] Disabling unused network protocols"
cat > /etc/modprobe.d/disable-unused-protocols.conf <<EOF
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

# Create warning banners
echo "[+] Creating login banners"
cat > /etc/issue <<EOF
****************************************************************
* WARNING: Unauthorized access to this system is prohibited   *
* All activities are monitored and logged.                    *
* Disconnect immediately if you are not an authorized user.   *
****************************************************************
EOF

cp /etc/issue /etc/issue.net

# Configure SSH banner
sed -i '/^#\?Banner/ c\Banner /etc/issue.net' /etc/ssh/sshd_config

# Additional sysctl hardening
cat >> /etc/sysctl.d/99-ec2-hardening.conf <<EOF

# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF

sysctl --system

# Clean up packages
echo "[+] Cleaning up packages"
apt-get autoremove -y
apt-get autoclean

# Create completion marker
touch /var/log/ec2-hardening-complete.flag

echo "[+] EC2 Ubuntu hardening completed successfully!"
echo "[+] Please reboot the system to ensure all changes take effect."
echo "[+] Completion marker: /var/log/ec2-hardening-complete.flag"

# Make sure all our scripts remain executable
chmod +x ubuntu-ec2.sh ec2-prereq-check.sh setup-ec2-hardening.sh 2>/dev/null || true