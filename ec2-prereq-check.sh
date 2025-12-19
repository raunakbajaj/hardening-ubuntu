#!/bin/bash

# Make this script executable
chmod +x "$0"

echo "=== EC2 Ubuntu Hardening Prerequisites Check ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: Not running as root. Use: sudo bash $0"
    exit 1
else
    echo "✅ Running as root"
fi

# Check Ubuntu version
if lsb_release -i | grep -q 'Ubuntu'; then
    VERSION=$(lsb_release -r | awk '{print $2}')
    echo "✅ Ubuntu $VERSION detected"
else
    echo "❌ ERROR: Not running on Ubuntu"
    exit 1
fi

# Check internet connectivity
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connectivity available"
else
    echo "❌ ERROR: No internet connectivity"
    exit 1
fi

# Check available disk space
AVAILABLE=$(df / | awk 'NR==2 {print $4}')
if [ "$AVAILABLE" -gt 1000000 ]; then
    echo "✅ Sufficient disk space available"
else
    echo "⚠️  WARNING: Low disk space ($(($AVAILABLE/1024))MB available)"
fi

# Check if systemctl is available
if command -v systemctl >/dev/null 2>&1; then
    echo "✅ systemctl available"
else
    echo "❌ ERROR: systemctl not found"
    exit 1
fi

# Check if apt is working
if apt-get update >/dev/null 2>&1; then
    echo "✅ APT package manager working"
else
    echo "❌ ERROR: APT package manager issues"
    exit 1
fi

echo ""
echo "=== Prerequisites Check Complete ==="
echo "✅ System ready for hardening"
echo ""
echo "To run hardening:"
echo "  sudo bash ubuntu-ec2.sh"