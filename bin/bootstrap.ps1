# bootstrap.ps1 - Initial setup script for Windows
# Run this first in an elevated PowerShell prompt

#Requires -RunAsAdministrator

Write-Host "=== DOTFILES BOOTSTRAP SCRIPT ===" -ForegroundColor Cyan
Write-Host "This script will install the minimal tools needed to run your dotfiles setup" -ForegroundColor White
Write-Host "✓ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Install Chocolatey
Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
try {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "✓ Chocolatey installed successfully" -ForegroundColor Green
} catch {
    throw "Failed to install Chocolatey: $_"
}

# Refresh environment to get choco in PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
refreshenv

# Verify Chocolatey is available
$chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoCmd) {
    throw "Chocolatey installation failed or is not in PATH. Please close this window and run the script again."
}

# Install essential tools
Write-Host "Installing Git and Boxstarter..." -ForegroundColor Yellow
try {
    choco install git boxstarter -y
    Write-Host "✓ Git and Boxstarter installed successfully" -ForegroundColor Green
} catch {
    throw "Failed to install Git and Boxstarter: $_"
}

# Success message and next steps
Write-Host ""
Write-Host "=== BOOTSTRAP COMPLETE ===" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Clone your dotfiles:" -ForegroundColor Yellow
Write-Host "   git clone https://github.com/laydros/dotfiles.git" -ForegroundColor Gray
Write-Host "2. Navigate to the dotfiles directory:" -ForegroundColor Yellow  
Write-Host "   cd dotfiles" -ForegroundColor Gray
Write-Host "3. Run the boxstarter setup:" -ForegroundColor Yellow
Write-Host "   Install-BoxstarterPackage -PackageName .\.config\boxstarter\main.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Or run all at once (in a new PowerShell window after this completes):" -ForegroundColor White
Write-Host "git clone https://github.com/laydros/dotfiles.git" -ForegroundColor Cyan
Write-Host "cd dotfiles" -ForegroundColor Cyan
Write-Host "Install-BoxstarterPackage -PackageName .\.config\boxstarter\main.ps1" -ForegroundColor Cyan
Write-Host ""