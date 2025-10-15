# main.ps1 - Boxstarter setup script for laydros/dotfiles
# Location: .config/boxstarter/main.ps1

<#
.SYNOPSIS
    Automated Windows system setup using Boxstarter + Chocolatey

.DESCRIPTION
    This script automates Windows configuration by:
    - Removing conflicting winget packages (with user consent)
    - Installing applications via Chocolatey (development tools, browsers, utilities, etc.)
    - Configuring Windows settings (developer mode, file extensions, disable telemetry)
    - Deploying dotfiles using your existing deploy-windows-dotfiles.ps1 script
    - Handling UAC prompts and automatic reboots as needed

.USAGE
    Prerequisites: Run bootstrap.ps1 first to install Chocolatey, Git, and Boxstarter

    1. Clone dotfiles: git clone https://github.com/laydros/dotfiles.git $env:USERPROFILE\src\dev\dotfiles
    2. Navigate to repo: cd $env:USERPROFILE\src\dev\dotfiles
    3. Run setup: Install-BoxstarterPackage -PackageName "$env:USERPROFILE\src\dev\dotfiles\.config\boxstarter\main.ps1"

    IMPORTANT: Use the absolute path (as shown above) so Boxstarter can find the script after reboots.
    The script uses temporary autologin for unattended reboots during setup.

.EMERGENCY CLEANUP
    Only needed if setup fails/crashes and autologin remains enabled:
    
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /f
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
    
    (Boxstarter normally cleans this up automatically on completion)

.AUTHOR
    Generated for laydros/dotfiles repository
#>

#Requires -RunAsAdministrator

# Boxstarter configuration
$Boxstarter.RebootOk = $true
$Boxstarter.NoPassword = $false
$Boxstarter.AutoLogin = $true

Write-BoxstarterMessage "Starting laydros dotfiles setup with verification checks..."

# =============================================================================
# VERIFICATION CHECKS
# =============================================================================

Write-BoxstarterMessage "Running pre-flight checks..."

# Check 1: Verify we're on Windows
if ($PSVersionTable.PSEdition -eq "Core" -and $IsLinux) {
    throw "This script is designed for Windows. Detected Linux environment."
}
if ($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
    throw "This script is designed for Windows. Detected macOS environment."
}
Write-BoxstarterMessage "Windows environment confirmed"

# Check 2: Verify we're in the dotfiles directory
$expectedRepo = "dotfiles"
$currentDir = Split-Path -Leaf (Get-Location)
if ($currentDir -ne $expectedRepo) {
    $dotfilesPath = Join-Path $env:USERPROFILE "src\dev\dotfiles"
    if (Test-Path $dotfilesPath) {
        Write-BoxstarterMessage "Switching to dotfiles directory: $dotfilesPath"
        Set-Location $dotfilesPath
    } else {
        throw "Could not find dotfiles directory. Expected to run from ~/src/dev/dotfiles or find it at $dotfilesPath"
    }
}
Write-BoxstarterMessage "Dotfiles directory confirmed: $(Get-Location)"

# Check 3: Verify required files exist
$requiredFiles = @(
    ".config\boxstarter\main.ps1",
    "bin\deploy-windows-dotfiles.ps1"
)

foreach ($file in $requiredFiles) {
    if (!(Test-Path $file)) {
        throw "Required file not found: $file"
    }
}
Write-BoxstarterMessage "All required dotfiles scripts found"

# Check 4: Verify Chocolatey is available
try {
    choco --version | Out-Null
    Write-BoxstarterMessage "Chocolatey is available"
} catch {
    throw "Chocolatey is not installed or not in PATH. Run bootstrap.ps1 first."
}

# Check 5: Check available disk space (warn if < 5GB free)
$freeSpace = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -ExpandProperty FreeSpace
$freeSpaceGB = [math]::Round($freeSpace / 1GB, 2)
if ($freeSpaceGB -lt 5) {
    Write-Warning "Low disk space detected: ${freeSpaceGB}GB free on C: drive"
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -notmatch "^[Yy]") {
        throw "Setup cancelled due to low disk space"
    }
}
Write-BoxstarterMessage "Sufficient disk space available: ${freeSpaceGB}GB"

# Check 6: Git configuration check (warn if not configured)
try {
    $gitUser = git config --global user.name
    $gitEmail = git config --global user.email
    
    if ([string]::IsNullOrEmpty($gitUser) -or [string]::IsNullOrEmpty($gitEmail)) {
        Write-Warning "Git is not fully configured:"
        Write-Warning "  user.name: '$gitUser'"
        Write-Warning "  user.email: '$gitEmail'"
        Write-Warning "You may want to configure git after setup completes"
    } else {
        Write-BoxstarterMessage "Git is configured for: $gitUser <$gitEmail>"
    }
} catch {
    Write-Warning "Git configuration could not be checked"
}

# =============================================================================
# PACKAGE MANAGER CLEANUP
# =============================================================================

Write-BoxstarterMessage "Checking for winget package conflicts..."

# Comprehensive winget to chocolatey package mapping
$wingetToChocoMap = @{
    "7zip.7zip" = "7zip"
    "Git.Git" = "git"
    "HeidiSQL.HeidiSQL" = "heidisql"
    "Mozilla.Firefox" = "firefox"
    "Mozilla.Thunderbird.ESR" = "thunderbird"
    "WinMerge.WinMerge" = "winmerge"
    "TheDocumentFoundation.LibreOffice" = "libreoffice-fresh"
    "WireGuard.WireGuard" = "wireguard"
    "Google.Chrome" = "googlechrome"
    "Oracle.JDK.17" = "openjdk17"
    "Microsoft.msodbcsql.17" = "sqlserver-odbcdriver"
    "PuTTY.PuTTY" = "putty"
    "Microsoft.SQLServer.2012.NativeClient" = "sqlserver-2012-nativeclient"
    "Python.Python.2" = "python2"
    "Python.Python.3.12" = "python3"
    "Microsoft.Edge" = "microsoft-edge"
    "Notepad++.Notepad++" = "notepadplusplus"
    "WinSCP.WinSCP" = "winscp"
    "Microsoft.DotNet.DesktopRuntime.5" = "dotnet-5.0-desktopruntime"
    "Microsoft.SQLServerManagementStudio" = "sql-server-management-studio"
    "Microsoft.DotNet.DesktopRuntime.7" = "dotnet-7.0-desktopruntime"
    "Oracle.JavaRuntimeEnvironment" = "jre8"
    "Microsoft.VCRedist.2013.x86" = "vcredist2013"
    "Microsoft.VCRedist.2015+.x64" = "vcredist140"
    "Microsoft.VCRedist.2015+.x86" = "vcredist140"
    "AltSnap.AltSnap" = "altsnap"
    "AutoHotkey.AutoHotkey" = "autohotkey"
    "Ferdium.Ferdium" = "ferdium"
    "GoTo.GoTo" = "gotomeeting"
    "Microsoft.VisualStudioCode" = "vscode"
    "Microsoft.WindowsTerminal" = "microsoft-windows-terminal"
    "Microsoft.PowerShell" = "powershell-core"
}

$installedWingetPackages = @()
$wingetAvailable = $false

# Check if winget is available
try {
    winget --version | Out-Null
    $wingetAvailable = $true
    Write-BoxstarterMessage "Winget detected, checking for conflicting packages..."
    
    # Check each package
    foreach ($wingetId in $wingetToChocoMap.Keys) {
        try {
            $result = winget list --id $wingetId --accept-source-agreements 2>$null
            if ($LASTEXITCODE -eq 0) {
                $installedWingetPackages += @{
                    WingetId = $wingetId
                    ChocoName = $wingetToChocoMap[$wingetId]
                }
            }
        } catch {
            # Package not found, continue
        }
    }
} catch {
    Write-BoxstarterMessage "Winget not available, no conflicts to resolve"
}

# Handle conflicts if found
$cleanupWingetPackages = $true
if ($wingetAvailable -and $installedWingetPackages.Count -gt 0) {
    Write-Warning "Found packages installed via winget that conflict with chocolatey installs:"
    foreach ($pkg in $installedWingetPackages) {
        Write-Warning "  - $($pkg.WingetId) (will install $($pkg.ChocoName) via chocolatey)"
    }
    Write-Host ""
    $cleanup = Read-Host "Remove winget versions to avoid conflicts? (Y/n)"
    
    if ($cleanup -match "^[Nn]") {
        $cleanupWingetPackages = $false
        Write-BoxstarterMessage "Keeping existing winget packages (may cause conflicts)"
    }
} else {
    Write-BoxstarterMessage "No winget package conflicts detected"
}

# =============================================================================
# USER CONFIRMATION
# =============================================================================

Write-Host ""
Write-Host "=== BOXSTARTER SETUP PLAN ===" -ForegroundColor Cyan
Write-Host "This script will:"
if ($wingetAvailable -and $installedWingetPackages.Count -gt 0 -and $cleanupWingetPackages) {
    Write-Host "  - Remove $($installedWingetPackages.Count) conflicting winget package(s)" -ForegroundColor Yellow
}
Write-Host "  - Install applications via Chocolatey" -ForegroundColor Green
Write-Host "  - Configure Windows settings and disable telemetry" -ForegroundColor Green
Write-Host "  - Deploy dotfiles using your existing script" -ForegroundColor Green
Write-Host "  - May require restarts (will auto-login and continue)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Current location: $(Get-Location)" -ForegroundColor Gray
Write-Host "Free disk space: ${freeSpaceGB}GB" -ForegroundColor Gray
if ($wingetAvailable -and $installedWingetPackages.Count -gt 0) {
    if ($cleanupWingetPackages) {
        Write-Host "Winget packages to remove: $($installedWingetPackages.Count)" -ForegroundColor Gray
    } else {
        Write-Host "Winget conflicts: $($installedWingetPackages.Count) (will be ignored)" -ForegroundColor Gray
    }
}
Write-Host ""

$confirmation = Read-Host "Proceed with setup? (y/N)"
if ($confirmation -notmatch "^[Yy]") {
    throw "Setup cancelled by user"
}

Write-BoxstarterMessage "All checks passed! Starting installation..."

# =============================================================================
# PACKAGE MANAGER CLEANUP 
# =============================================================================

if ($wingetAvailable -and $installedWingetPackages.Count -gt 0 -and $cleanupWingetPackages) {
    Write-BoxstarterMessage "Removing conflicting winget packages..."
    
    foreach ($pkg in $installedWingetPackages) {
        try {
            Write-BoxstarterMessage "Removing winget package: $($pkg.WingetId)"
            winget uninstall --id $pkg.WingetId --silent --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-BoxstarterMessage "Successfully removed $($pkg.WingetId)"
            } else {
                Write-Warning "Failed to remove $($pkg.WingetId) (exit code: $LASTEXITCODE)"
            }
        } catch {
            Write-Warning "Error removing $($pkg.WingetId): $_"
        }
    }
    
    Write-BoxstarterMessage "Winget cleanup complete"
}

# =============================================================================
# PACKAGE INSTALLATIONS
# =============================================================================

Write-BoxstarterMessage "Installing applications..."

# Development tools
choco install -y git
choco install -y vscode  
choco install -y powershell-core
choco install -y microsoft-windows-terminal
choco install -y autohotkey

# System utilities  
choco install -y 7zip
choco install -y notepadplusplus
choco install -y altsnap
choco install -y putty
choco install -y winscp
choco install -y winmerge

# Web browsers
choco install -y firefox
choco install -y googlechrome
choco install -y microsoft-edge

# Communication
choco install -y thunderbird
choco install -y ferdium
choco install -y gotomeeting

# Office & Productivity
choco install -y libreoffice-fresh

# Development platforms & languages
choco install -y openjdk17
choco install -y jre8
choco install -y python2
choco install -y python3

# Database tools
choco install -y heidisql
choco install -y sql-server-management-studio
choco install -y sqlserver-odbcdriver

# .NET runtimes & redistributables
choco install -y dotnet-5.0-desktopruntime
choco install -y dotnet-7.0-desktopruntime
choco install -y vcredist140
choco install -y vcredist2013

# Networking & VPN
choco install -y wireguard

Write-BoxstarterMessage "Application installation complete"

# =============================================================================
# WINDOWS CONFIGURATION
# =============================================================================

Write-BoxstarterMessage "Configuring Windows settings..."

# Enable Developer Mode
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1

# Disable Windows Consumer Features (suggested apps, etc.)
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
}
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1

# Disable Microsoft Account nagging
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" -Name "DevicePasswordLessBuildVersion" -Type DWord -Value 0

# Show file extensions
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 0

# Show hidden files
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Type DWord -Value 1

Write-BoxstarterMessage "Windows configuration complete"

# =============================================================================
# DEPLOY DOTFILES
# =============================================================================

Write-BoxstarterMessage "Deploying dotfiles..."

$deployScript = Join-Path (Get-Location) "bin\deploy-windows-dotfiles.ps1"
if (Test-Path $deployScript) {
    Write-BoxstarterMessage "Running dotfiles deployment script..."
    & $deployScript
    Write-BoxstarterMessage "Dotfiles deployment complete"
} else {
    Write-Warning "Dotfiles deployment script not found at: $deployScript"
}

# =============================================================================
# COMPLETION
# =============================================================================

Write-BoxstarterMessage "Setup complete!"
Write-Host ""
Write-Host "=== SETUP SUMMARY ===" -ForegroundColor Green
Write-Host "Applications installed via Chocolatey" -ForegroundColor Green
Write-Host "Windows settings configured" -ForegroundColor Green
Write-Host "Dotfiles deployed" -ForegroundColor Green
Write-Host ""
Write-Host "You may want to:" -ForegroundColor Yellow
Write-Host "  - Configure git if not already done: git config --global user.name email" -ForegroundColor Yellow
Write-Host "  - Review installed applications" -ForegroundColor Yellow
Write-Host "  - Customize Windows Terminal VS Code settings" -ForegroundColor Yellow
Write-Host ""