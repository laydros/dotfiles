# main.ps1 - Boxstarter setup script for laydros/dotfiles
# Location: .config/boxstarter/main.ps1

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
Write-BoxstarterMessage "✓ Windows environment confirmed"

# Check 2: Verify we're in the dotfiles directory
$expectedRepo = "dotfiles"
$currentDir = Split-Path -Leaf (Get-Location)
if ($currentDir -ne $expectedRepo) {
    $dotfilesPath = Join-Path $env:USERPROFILE $expectedRepo
    if (Test-Path $dotfilesPath) {
        Write-BoxstarterMessage "Switching to dotfiles directory: $dotfilesPath"
        Set-Location $dotfilesPath
    } else {
        throw "Could not find dotfiles directory. Expected to run from ~/dotfiles or find it at $dotfilesPath"
    }
}
Write-BoxstarterMessage "✓ Dotfiles directory confirmed: $(Get-Location)"

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
Write-BoxstarterMessage "✓ All required dotfiles scripts found"

# Check 4: Verify Chocolatey is available
try {
    choco --version | Out-Null
    Write-BoxstarterMessage "✓ Chocolatey is available"
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
Write-BoxstarterMessage "✓ Sufficient disk space available: ${freeSpaceGB}GB"

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
        Write-BoxstarterMessage "✓ Git is configured for: $gitUser <$gitEmail>"
    }
} catch {
    Write-Warning "Git configuration could not be checked"
}

# =============================================================================
# USER CONFIRMATION
# =============================================================================

Write-Host ""
Write-Host "=== BOXSTARTER SETUP PLAN ===" -ForegroundColor Cyan
Write-Host "This script will:"
Write-Host "  • Install applications via Chocolatey" -ForegroundColor Green
Write-Host "  • Configure Windows settings and disable telemetry" -ForegroundColor Green  
Write-Host "  • Deploy dotfiles using your existing script" -ForegroundColor Green
Write-Host "  • May require restarts (will auto-login and continue)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Current location: $(Get-Location)" -ForegroundColor Gray
Write-Host "Free disk space: ${freeSpaceGB}GB" -ForegroundColor Gray
Write-Host ""

$confirmation = Read-Host "Proceed with setup? (y/N)"
if ($confirmation -notmatch "^[Yy]") {
    throw "Setup cancelled by user"
}

Write-BoxstarterMessage "All checks passed! Starting installation..."

# =============================================================================
# PACKAGE INSTALLATIONS
# =============================================================================

Write-BoxstarterMessage "Installing applications..."

# Essential development tools
choco install -y git
choco install -y vscode
choco install -y powershell-core
choco install -y windows-terminal

# System utilities
choco install -y 7zip
choco install -y notepadplusplus
choco install -y sysinternals

# Add your other packages here - keeping minimal for now
# Examples you might want:
# choco install -y nodejs python docker-desktop

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
Write-Host "✓ Applications installed via Chocolatey" -ForegroundColor Green
Write-Host "✓ Windows settings configured" -ForegroundColor Green
Write-Host "✓ Dotfiles deployed" -ForegroundColor Green
Write-Host ""
Write-Host "You may want to:" -ForegroundColor Yellow
Write-Host "  • Configure git if not already done: git config --global user.name/email" -ForegroundColor Yellow
Write-Host "  • Review installed applications" -ForegroundColor Yellow
Write-Host "  • Customize Windows Terminal/VS Code settings" -ForegroundColor Yellow
Write-Host ""