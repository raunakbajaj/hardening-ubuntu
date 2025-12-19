#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "[+] Running EC2 Image Builder compatible Ubuntu hardening"

# Ensure we're running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

#
# 1. Basic package updates (safe)
#
echo "[+] Updating APT package lists"
apt-get update -y

#
# 2. Install required packages first
#
echo "[+] Installing required packages"
apt-get install -y net-tools auditd audispd-plugins cron sudo bind9-dnsutils iputils-ping procps --no-install-recommends

#
# 3. Enable unattended upgrades (safe)
#
echo "[+] Enabling unattended-upgrades"
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

#
# 4. Configure login.defs (safe)
#
echo "[+] Applying safe login.defs hardening"
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'  /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs

#
# 5. Configure password aging for existing users (safe)
#
echo "[+] Updating password aging for existing users"
for u in $(awk -F: '($3 >= 1000 && $3 < 65534) {print $1}' /etc/passwd); do
    chage --maxdays 90 --mindays 1 --warndays 14 "$u" || true
done

#
# 6. Filesystem permission hardening (safe)
#
echo "[+] Securing /etc permissions"
chmod 0755 /etc
chmod 0644 /etc/passwd
chmod 0644 /etc/group
chmod 0640 /etc/shadow
chmod 0640 /etc/gshadow

#
# 7. Disable core dumps (safe)
#
echo "[+] Disabling core dumps"
echo '* hard core 0' > /etc/security/limits.d/99-hardening.conf

#
# 8. Configure sysctl network hardening (safe subset)
#
echo "[+] Applying sysctl safe network settings"
cat <<EOF >/etc/sysctl.d/99-safe-hardening.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
kernel.kptr_restrict = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
sysctl --system || true

#
# 9. SSH hardening (safe subset)
#
echo "[+] Applying SSH hardening"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

#
# 10. Remove world-writable permissions (safe)
#
echo "[+] Removing world-writable permissions"
find / -xdev -type f -perm -0002 -exec chmod o-w {} + 2>/dev/null || true
find / -xdev -type d -perm -0002 -exec chmod o-t {} + 2>/dev/null || true

#
# 11. Enable firewall (ufw, safe)
#
echo "[+] Enabling UFW firewall"
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

#
# 12. Install and configure security packages
#
echo "[+] Installing security packages"
apt-get install -y fail2ban libpam-tmpdir apt-listchanges

#
# 13. Configure fail2ban
#
echo "[+] Configuring fail2ban"
systemctl enable fail2ban
if [ -f /etc/fail2ban/jail.conf ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    chmod 600 /etc/fail2ban/jail.local
fi

#
# 14. Enable auditd
#
echo "[+] Enabling auditd"
systemctl enable auditd

#
# 15. Disable unused protocols
#
echo "[+] Disabling unused protocols"
cat > /etc/modprobe.d/disable-unused-protocols.conf <<EOF
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

#
# 16. Create unauthorized access banner
#
echo "[+] Creating login banners"
cat > /etc/issue <<EOF
****************************************************************
* WARNING: Unauthorized access to this system is prohibited   *
* All activities are monitored and logged.                    *
* Disconnect immediately if you are not an authorized user.   *
****************************************************************
EOF

cp /etc/issue /etc/issue.net
sed -i '/^#\?Banner/ c\Banner /etc/issue.net' /etc/ssh/sshd_config

#
# 17. Run safe subset of hardening functions
#
echo "[+] Running additional hardening functions"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Only run if hardening.sh exists and we have the config
if [ -f "$SCRIPT_DIR/hardening.sh" ] && [ -f "$SCRIPT_DIR/ubuntu.cfg" ]; then
    echo "[+] Running selected hardening functions"
    
    # Change to the script directory
    cd "$SCRIPT_DIR"
    
    # Source the config
    source ./ubuntu.cfg
    
    # Source the scripts
    for s in ./scripts/*; do
        [[ -f $s ]] || break
        source "$s"
    done
    
    # Run only the safe functions for EC2 Image Builder
    echo "[+] Running pre-checks"
    f_pre || true
    
    echo "[+] Configuring journald"
    f_journalctl || true
    
    echo "[+] Configuring timesyncd"
    f_timesyncd || true
    
    echo "[+] Configuring resolved"
    f_resolvedconf || true
    
    echo "[+] Configuring adduser"
    f_adduser || true
    
    echo "[+] Configuring root access"
    f_rootaccess || true
    
    echo "[+] Configuring coredump"
    f_coredump || true
    
    echo "[+] Configuring hosts"
    f_hosts || true
    
    echo "[+] Configuring issue"
    f_issue || true
    
    echo "[+] Configuring sudo"
    f_sudo || true
    
    echo "[+] Configuring cron"
    f_cron || true
    
    echo "[+] Configuring umask"
    f_umask || true
    
    echo "[+] Configuring path"
    f_path || true
    
    echo "[+] Running post configuration"
    f_post || true
    
    echo "[+] Checking reboot requirement"
    f_checkreboot || true
else
    echo "[+] Hardening scripts not found, using basic hardening only"
fi

#
# 18. Clean up
#
echo "[+] Cleaning up packages"
apt-get autoremove -y
apt-get autoclean

#
# 19. Create completion marker
#
echo "[+] Creating completion marker"
echo "$(date): EC2 Image Builder Ubuntu hardening completed successfully" > /var/log/ec2-hardening-complete.flag

echo "[+] EC2 Image Builder Ubuntu hardening completed successfully!"
echo "[+] System will be ready after reboot"