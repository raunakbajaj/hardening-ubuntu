#!/bin/bash

# EC2 Ubuntu Hardening Setup Script
# This script makes all necessary files executable and sets up the environment

echo "=== Setting up EC2 Ubuntu Hardening ==="

# Make this script executable
chmod +x "$0"

# Make all shell scripts executable
echo "[+] Making scripts executable..."
chmod +x ubuntu-ec2.sh
chmod +x ec2-prereq-check.sh
chmod +x ubuntu.sh
chmod +x hardening.sh
chmod +x checkScore.sh
chmod +x createPartitions.sh
chmod +x runTests.sh
chmod +x test_hardening.sh

# Make scripts in subdirectories executable
if [ -d "scripts" ]; then
    find scripts/ -type f -name "*.sh" -exec chmod +x {} \;
    echo "[+] Made scripts in scripts/ directory executable"
fi

if [ -d "misc" ]; then
    find misc/ -type f -name "*.sh" -exec chmod +x {} \;
    echo "[+] Made scripts in misc/ directory executable"
fi

if [ -d "tests" ]; then
    find tests/ -type f -name "*.sh" -exec chmod +x {} \;
    echo "[+] Made scripts in tests/ directory executable"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Available commands:"
echo "  ./ec2-prereq-check.sh    - Check system prerequisites"
echo "  ./ubuntu-ec2.sh          - Run EC2-optimized hardening (recommended)"
echo "  ./ubuntu.sh              - Run full hardening script"
echo ""
echo "Recommended workflow:"
echo "1. sudo ./ec2-prereq-check.sh"
echo "2. sudo ./ubuntu-ec2.sh"