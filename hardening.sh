#!/bin/bash

# shellcheck disable=1090
# shellcheck disable=2009
# shellcheck disable=2034

set -u -o pipefail

# Bash detection disabled for EC2 Image Builder compatibility
# The script is explicitly called with bash from ubuntu.sh

if ! [ -x "$(command -v systemctl)" ]; then
  echo "systemctl required. Exiting."
  exit 1
fi

function main {
  clear

  # Get the directory where this script is located
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
  # Change to script directory to ensure relative paths work
  cd "$SCRIPT_DIR"

  REQUIREDPROGS='arp dig ping w'
  REQFAILED=0
  for p in $REQUIREDPROGS; do
    if ! command -v "$p" >/dev/null 2>&1; then
      echo "$p is required."
      REQFAILED=1
    fi
  done

  if [ $REQFAILED = 1 ]; then
    apt-get -qq update
    apt-get -qq install bind9-dnsutils iputils-ping net-tools procps --no-install-recommends
  fi

  ARPBIN="$(command -v arp)"
  DIGBIN="$(command -v dig)"
  PINGBIN="$(command -v ping)"
  WBIN="$(command -v w)"
  WHOBIN="$(command -v who)"
  LXC="0"

  if resolvectl status >/dev/null 2>&1; then
    SERVERIP="$(ip route get "$(resolvectl status |\
      grep -E 'DNS (Server:|Servers:)' | tail -n1 |\
      awk '{print $NF}')" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' |\
      tail -n1)"
  else
    SERVERIP="$(ip route get "$(grep '^nameserver' /etc/resolv.conf |\
      tail -n1 | awk '{print $NF}')" |\
      grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -n1)"
  fi

  if grep -qE 'container=lxc|container=lxd' /proc/1/environ; then
    LXC="1"
  fi

  if grep -s "AUTOFILL='Y'" ./ubuntu.cfg; then
    USERIP="$($WHOBIN | awk '{print $NF}' | tr -d '()' |\
      grep -E '^[0-9]' | head -n1)"

    if [[ "$USERIP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      ADMINIP="$USERIP"
    else
      ADMINIP="$(hostname -I | sed -E 's/\.[0-9]+ /.0\/24 /g')"
    fi

    sed -i "s/FW_ADMIN='/FW_ADMIN='$ADMINIP /" ./ubuntu.cfg
    sed -i "s/SSH_GRPS='/SSH_GRPS='$(id "$($WBIN -ih | awk '{print $1}' | head -n1)" -ng) /" ./ubuntu.cfg
    sed -i "s/CHANGEME=''/CHANGEME='$(date +%s)'/" ./ubuntu.cfg
    sed -i "s/VERBOSE='N'/VERBOSE='Y'/" ./ubuntu.cfg
  fi

  source ./ubuntu.cfg

  readonly ADDUSER
  readonly ADMINEMAIL
  readonly ARPBIN
  readonly AUDITDCONF
  readonly AUDITD_MODE
  readonly AUDITD_RULES
  readonly AUDITRULES
  readonly AUTOFILL
  readonly CHANGEME
  readonly COMMONACCOUNT
  readonly COMMONAUTH
  readonly COMMONPASSWD
  readonly COREDUMPCONF
  readonly DEFAULTGRUB
  readonly DISABLEFS
  readonly DISABLEMOD
  readonly DISABLENET
  readonly FAILLOCKCONF
  readonly FW_ADMIN
  readonly JOURNALDCONF
  readonly KEEP_SNAPD
  readonly LIMITSCONF
  readonly LOGINDCONF
  readonly LOGINDEFS
  readonly LOGROTATE
  readonly LOGROTATE_CONF
  readonly LXC
  readonly NTPSERVERPOOL
  readonly PAMLOGIN
  readonly PSADCONF
  readonly PSADDL
  readonly RESOLVEDCONF
  readonly RKHUNTERCONF
  readonly RSYSLOGCONF
  readonly SECURITYACCESS
  readonly SERVERIP
  readonly SSHDFILE
  readonly SSHFILE
  readonly SSH_GRPS
  readonly SSH_PORT
  readonly SYSCTL
  readonly SYSCTL_CONF
  readonly SYSTEMCONF
  readonly TIMEDATECTL
  readonly TIMESYNCD
  readonly UFWDEFAULT
  readonly USERADD
  readonly USERCONF
  readonly VERBOSE
  readonly WBIN

  for s in ./scripts/*; do
    [[ -f $s ]] || break

    source "$s"
  done


  # EC2-safe functions (confirmed working in EC2 Image Builder)
  f_pre
  f_kernel
  f_firewall
  #f_disablenet  # DISABLED: May break EC2 networking
  #f_disablefs  # DISABLED: May break EC2 filesystems
  #f_disablemod  # DISABLED: Breaks EC2 environment
  #f_systemdconf  # DISABLED: Too restrictive for EC2
  f_resolvedconf
  f_logindconf
  f_journalctl
  f_timesyncd
  #f_fstab  # DISABLED: Mount restrictions break EC2 Image Builder bootstrap
  f_prelink
  #f_aptget_configure  # DISABLED: Breaks package installation in EC2
  f_aptget
  f_hosts
  f_issue
  f_sudo
  f_logindefs
  #f_sysctl  # DISABLED: May break EC2 networking
  #f_limitsconf  # DISABLED: Too restrictive for EC2
  f_adduser
  f_rootaccess
  #f_package_install  # DISABLED: May install conflicting packages
  #f_psad  # DISABLED: Aggressive intrusion detection breaks EC2
  f_coredump
  #f_usbguard  # DISABLED: Not needed in EC2
  f_postfix
  f_apport
  f_motdnews
  #f_rkhunter  # DISABLED: May interfere with EC2 operations
  f_sshconfig
  f_sshdconfig
  #f_password  # DISABLED: Strict password policies break EC2
  f_cron
  #f_ctrlaltdel  # DISABLED: Not relevant in EC2
  #f_auditd  # DISABLED: May slow down EC2 Image Builder
  #f_aide  # DISABLED: File integrity checking breaks EC2
  f_rhosts
  #f_users  # DISABLED: Removes users EC2 might need
  #f_lockroot  # DISABLED: Breaks EC2 operations
  #f_package_remove  # DISABLED: Removes packages EC2 needs
  f_suid
  #f_restrictcompilers  # DISABLED: May break development tools
  f_umask
  f_path
  #f_aa_enforce  # DISABLED: AppArmor may break EC2 applications
  #f_aide_post  # DISABLED: File integrity checking breaks EC2
  #f_aide_timer  # DISABLED: File integrity checking breaks EC2
  #f_aptget_noexec  # DISABLED: /tmp remount fails in EC2
  f_aptget_clean
  f_systemddelta
  f_post
  f_checkreboot
  

  echo
}

LOGFILE="hardening-$(hostname --short)-$(date +%y%m%d).log"
echo "[HARDENING LOG - $(hostname --fqdn) - $(LANG=C date)]" >> "$LOGFILE"

main "$@" | tee -a "$LOGFILE"
