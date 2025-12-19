#!/bin/bash

# EC2 Hardening Validation Script
# For use with EC2 Image Builder testing phase

set -e

echo "=== EC2 Ubuntu Hardening Validation ==="

VALIDATION_FAILED=0

# Function to check and report
check_item() {
    local description="$1"
    local command="$2"
    
    echo -n "Checking $description... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo "✅ PASS"
        return 0
    else
        echo "❌ FAIL"
        VALIDATION_FAILED=1
        return 1
    fi
}

# Check if hardening completion marker exists
check_item "hardening completion marker" "[ -f /var/log/ec2-hardening-complete.flag ]"

# Check essential packages are installed
check_item "unattended-upgrades package" "dpkg -l | grep -q unattended-upgrades"
check_item "fail2ban package" "dpkg -l | grep -q fail2ban"
check_item "ufw package" "dpkg -l | grep -q ufw"

# Check SSH configuration
check_item "SSH root login disabled" "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config"
check_item "SSH public key auth enabled" "grep -q '^PubkeyAuthentication yes' /etc/ssh/sshd_config"

# Check firewall status
check_item "UFW firewall enabled" "ufw status | grep -q 'Status: active'"

# Check sysctl settings
check_item "IP forwarding disabled" "grep -q 'net.ipv4.ip_forward = 0' /etc/sysctl.d/99-basic-hardening.conf"

# Check login banner
check_item "login banner exists" "[ -f /etc/issue ] && [ -f /etc/issue.net ]"

# Check disabled protocols
check_item "unused protocols disabled" "[ -f /etc/modprobe.d/disable-protocols.conf ]"

# Check services are enabled (but not necessarily running in image build)
check_item "fail2ban service enabled" "systemctl is-enabled fail2ban"

echo ""
if [ $VALIDATION_FAILED -eq 0 ]; then
    echo "✅ All hardening validations passed!"
    echo "Image is ready for deployment"
    exit 0
else
    echo "❌ Some validations failed!"
    echo "Check the output above for details"
    exit 1
fi