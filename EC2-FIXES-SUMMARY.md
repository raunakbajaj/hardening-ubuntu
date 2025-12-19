# EC2 Image Builder Compatibility Fixes

## Problem
The "Unable to bootstrap TOE" error was occurring because the hardening script was running functions that break in EC2 Image Builder environments.

## Root Cause
The `hardening.sh` script had ALL functions enabled, including ones that:
- Modify `/etc/fstab` with mount restrictions that break bootstrap
- Change APT configuration that prevents package installation
- Apply network restrictions that break EC2 networking
- Set process limits too restrictive for EC2 environment

## Fixes Applied

### 1. Modified `ubuntu.sh`
- Added EC2 environment detection
- Routes to EC2-compatible hardening when in AWS environment
- Falls back to full hardening for non-EC2 environments

### 2. Modified `hardening.sh`
- Disabled problematic functions that break EC2 Image Builder
- Kept essential security functions that work in EC2
- Added clear comments explaining why functions are disabled

### 3. Created EC2-Specific Scripts
- `ubuntu-ec2-imagebuilder.sh` - Standalone EC2-compatible hardening
- `minimal-ec2-hardening.sh` - Minimal security hardening for EC2
- `validate-hardening.sh` - Validation script for testing phase

## Functions Disabled for EC2 Compatibility

### Critical (Break Bootstrap)
- `f_fstab` - Mount restrictions break bootstrap process
- `f_aptget_configure` - APT config breaks package installation
- `f_aptget_noexec` - /tmp remount fails in EC2
- `f_password` - Strict password policies prevent changes

### Network/System (Break EC2 Environment)
- `f_disablenet` - May break EC2 networking
- `f_sysctl` - Network restrictions break EC2
- `f_systemdconf` - Process limits too restrictive
- `f_limitsconf` - Process limits too restrictive

### Security Tools (Too Aggressive for EC2)
- `f_psad` - Intrusion detection blocks EC2 operations
- `f_auditd` - Aggressive auditing slows EC2 Image Builder
- `f_aide` - File integrity checking interferes with EC2
- `f_rkhunter` - May interfere with EC2 operations

### Package Management (May Break Dependencies)
- `f_package_install` - May install conflicting packages
- `f_package_remove` - Removes packages EC2 might need
- `f_users` - Removes system users EC2 might need

## Functions Kept (EC2-Safe)
- `f_pre` - Basic checks
- `f_kernel` - Kernel hardening
- `f_firewall` - UFW firewall setup
- `f_ssh*` - SSH hardening
- `f_sudo` - Sudo configuration
- `f_hosts` - Host access controls
- `f_issue` - Login banners
- `f_cron` - Cron security
- `f_umask` - Default permissions
- `f_path` - PATH security
- And other non-disruptive security functions

## Usage
Your existing Terraform configuration should now work without the "Unable to bootstrap TOE" error:

```bash
git clone https://github.com/raunakbajaj/hardening-ubuntu.git
cd hardening-ubuntu
sed -i 's/^CHANGEME=""/CHANGEME="ok"/' ubuntu.cfg
bash ubuntu.sh
```

The script will automatically detect the EC2 environment and run only compatible functions.

## Validation
The hardening will create a completion marker at `/var/log/ec2-hardening-complete.flag` that your pipeline can check to verify successful completion.