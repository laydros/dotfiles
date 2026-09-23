---
name: system-explore
description: Explore Linux systems Jason manages to gather infrastructure context and create system facts files. This skill should be used when needing to understand a system's configuration before making changes, when creating or updating system documentation, or when planning Ansible roles. Works for Factor 500 infrastructure and personal systems (gibson, ibanez, vox, etc.) via SSH.
---

# System Explore

## Overview

This skill provides a structured approach to exploring Linux systems and documenting their configuration. It gathers comprehensive system facts (OS, hardware, services, mounts, packages) and outputs them in a markdown format suitable for documentation.

## When to Use This Skill

- Before proposing infrastructure changes (understand current state first)
- When creating or updating system facts documentation
- When planning new Ansible roles for a system
- When troubleshooting or investigating system configuration
- When onboarding a new system into management

## Workflow

### 1. Run the Exploration Script

Execute the exploration script on the target system via SSH:

```bash
ssh root@hostname 'bash -s' < /Users/laydros/.claude/skills/system-explore/scripts/explore.sh
```

Or if already connected to the system:

```bash
bash /Users/laydros/.claude/skills/system-explore/scripts/explore.sh
```

The script outputs markdown-formatted system facts including:
- OS version and kernel
- Hardware (CPU, memory)
- Disk usage
- Network configuration and listening services
- Mount points (especially CIFS/NFS)
- Systemd services and timers
- Cron jobs
- Key installed packages
- Users and groups
- Container detection (LXC/Docker)

### 2. Review and Annotate

After gathering raw facts, review the output and add:
- **Purpose:** What this system does (e.g., "Git server", "File server", "Backup orchestration")
- **Dependencies:** What other systems it relies on or serves
- **Special notes:** Anything unusual or important to remember
- **Ansible status:** Whether it's managed by Ansible and which roles apply

### 3. Create or Update Facts File

Save the annotated facts to the appropriate location:

**For Factor 500 systems:**
```
/Users/laydros/src/f500/sysadmin/docs/system-facts/{hostname}.md
```

**For personal systems:** no standard location yet. Ask Jason where it goes.

### 4. Facts File Format

The facts file should follow this structure:

```markdown
---
date: YYYY-MM-DD
updated: YYYY-MM-DD
tags:
  - infrastructure
  - work (or homelab)
---

# {hostname}

## Purpose
[Brief description of what this system does]

## Quick Reference
- **IP:** x.x.x.x
- **OS:** Debian 13 / Ubuntu 24.04 / etc.
- **Managed by Ansible:** Yes/No
- **Ansible roles:** role1, role2

## Operating System
[From exploration output]

## Hardware
[From exploration output]

## Network
[From exploration output]

## Services
[From exploration output]

## Mount Points
[From exploration output]

## Scheduled Tasks
[From exploration output]

## Installed Software
[From exploration output]

## Configuration Notes
[From exploration output + manual additions]

## Dependencies
- Depends on: [list systems this one needs]
- Serves: [list systems/users that depend on this]

## Maintenance Notes
[Any special procedures, gotchas, or historical context]
```

## Quick Commands Reference

Check specific aspects without full exploration:

```bash
# OS version
ssh root@host 'cat /etc/os-release'

# Listening ports
ssh root@host 'ss -tlnp'

# Disk usage
ssh root@host 'df -h'

# Systemd services
ssh root@host 'systemctl list-units --type=service --state=running'

# Mount points
ssh root@host 'mount | grep -E "^(/dev|//|cifs|nfs)"'

# Check specific config
ssh root@host 'cat /etc/samba/smb.conf'
```

## Integration with Ansible Workflow

Before proposing Ansible changes:

1. Run exploration on target system(s)
2. Check existing facts file (if any) for context
3. Note what's already managed vs manual configuration
4. Propose changes with clear "known state" vs "assumptions"

After Ansible deployment:

1. Re-run exploration to verify changes
2. Update facts file with new state
3. Note which Ansible roles now manage the system
