#!/bin/bash
# System exploration script for gathering infrastructure facts
# Outputs structured information suitable for documentation
# Usage: ssh user@host 'bash -s' < explore.sh

set -e

echo "# System Facts - $(hostname)"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# OS Information
echo "## Operating System"
echo ""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "- **Distro:** $NAME $VERSION"
    echo "- **Version ID:** $VERSION_ID"
else
    echo "- **OS:** $(uname -s)"
fi
echo "- **Kernel:** $(uname -r)"
echo "- **Architecture:** $(uname -m)"
echo ""

# Hardware
echo "## Hardware"
echo ""
cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
cpu_cores=$(nproc 2>/dev/null || echo "Unknown")
mem_total=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "Unknown")
echo "- **CPU:** $cpu_model"
echo "- **Cores:** $cpu_cores"
echo "- **Memory:** $mem_total"
echo ""

# Disk Usage
echo "## Disk Usage"
echo ""
echo '```'
df -h --output=target,size,used,avail,pcent -x tmpfs -x devtmpfs 2>/dev/null || df -h
echo '```'
echo ""

# Network
echo "## Network"
echo ""
echo "- **Hostname:** $(hostname -f 2>/dev/null || hostname)"
echo "- **IP Addresses:**"
ip -4 addr show 2>/dev/null | grep -oP 'inet \K[\d.]+(?=/)' | while read ip; do
    iface=$(ip -4 addr show | grep -B2 "$ip" | grep -oP '^\d+: \K[^:]+' | tail -1)
    echo "  - $ip ($iface)"
done
echo ""

# Listening Services
echo "## Listening Services"
echo ""
echo '```'
ss -tlnp 2>/dev/null | head -20 || netstat -tlnp 2>/dev/null | head -20 || echo "Unable to get listening services"
echo '```'
echo ""

# Mount Points
echo "## Mount Points"
echo ""
echo '```'
mount | grep -E '^(/dev|//|cifs|nfs)' || echo "No relevant mounts found"
echo '```'
echo ""

# Systemd Services (enabled, non-default)
echo "## Key Services"
echo ""
if command -v systemctl &>/dev/null; then
    echo "### Enabled Services (non-default)"
    echo '```'
    systemctl list-unit-files --type=service --state=enabled 2>/dev/null | \
        grep -v -E '(systemd|dbus|ssh|cron|rsyslog|networking|getty)' | \
        head -20 || echo "Unable to list services"
    echo '```'
    echo ""

    echo "### Running Services"
    echo '```'
    systemctl list-units --type=service --state=running 2>/dev/null | \
        grep -v -E '(systemd|dbus|user@)' | \
        head -20 || echo "Unable to list running services"
    echo '```'
fi
echo ""

# Scheduled Tasks
echo "## Scheduled Tasks"
echo ""
echo "### Cron Jobs"
echo '```'
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -l -u "$user" 2>/dev/null | grep -v '^#' | grep -v '^$' && echo "  (user: $user)"
done
cat /etc/crontab 2>/dev/null | grep -v '^#' | grep -v '^$' | head -10
ls /etc/cron.d/ 2>/dev/null | head -10
echo '```'
echo ""

if command -v systemctl &>/dev/null; then
    echo "### Systemd Timers"
    echo '```'
    systemctl list-timers --all 2>/dev/null | head -15 || echo "Unable to list timers"
    echo '```'
fi
echo ""

# Key Packages (detect what's relevant)
echo "## Installed Software"
echo ""
echo "### Key Packages"
packages=""
for pkg in nginx apache2 samba postgresql mysql mariadb docker podman forgejo gitea git ansible python3 nodejs java; do
    if command -v "$pkg" &>/dev/null || dpkg -l "$pkg" &>/dev/null 2>&1 || rpm -q "$pkg" &>/dev/null 2>&1; then
        version=$($pkg --version 2>/dev/null | head -1 || dpkg -l "$pkg" 2>/dev/null | awk '/^ii/{print $3}' || echo "installed")
        packages="$packages\n- **$pkg:** $version"
    fi
done
if [ -n "$packages" ]; then
    echo -e "$packages"
else
    echo "No notable packages detected"
fi
echo ""

# Users and Groups
echo "## Users and Groups"
echo ""
echo "### System Users (with login shell)"
echo '```'
grep -v -E '(nologin|false)$' /etc/passwd | cut -d: -f1,3,6 | column -t -s:
echo '```'
echo ""

echo "### Notable Groups"
echo '```'
grep -E '(sudo|wheel|docker|www-data|git|samba|m3db)' /etc/group 2>/dev/null || echo "No notable groups found"
echo '```'
echo ""

# Container Detection
if [ -f /.dockerenv ] || grep -q 'lxc' /proc/1/cgroup 2>/dev/null; then
    echo "## Container Information"
    echo ""
    echo "- **Type:** $([ -f /.dockerenv ] && echo 'Docker' || echo 'LXC/LXD')"
    echo ""
fi

# Config Files of Interest
echo "## Configuration Notes"
echo ""
echo "Key config locations to check:"
for conf in /etc/samba/smb.conf /etc/nginx/nginx.conf /etc/forgejo/app.ini /etc/gitea/app.ini /etc/fstab; do
    if [ -f "$conf" ]; then
        echo "- \`$conf\` exists"
    fi
done
echo ""

echo "---"
echo "*Facts gathered by system-explore skill*"
