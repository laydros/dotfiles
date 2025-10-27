# deploy-windows-dotfiles.ps1
# Deploy shared dotfiles from yadm repo to Windows

$ErrorActionPreference = "Stop"

Write-Host "Deploying dotfiles to Windows..." -ForegroundColor Green

# Ensure target directories exist
$configDirs = @(
    "$env:USERPROFILE\.config\git",
    "$env:LOCALAPPDATA\nvim",
    "$env:APPDATA\espanso\config",
    "$env:APPDATA\espanso\match",
    "$env:USERPROFILE\.claude",
    "$env:USERPROFILE\.ssh"
)

foreach ($dir in $configDirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Yellow
    }
}

# Deploy Git config (remove ##template suffix)
Copy-Item ".\.config\git\config" "$env:USERPROFILE\.config\git\config" -Force
Write-Host "OK Git config"

# Deploy Git ignore
Copy-Item ".\.config\git\gitignore" "$env:USERPROFILE\.config\git\gitignore" -Force
Write-Host "OK Git ignore"

# Deploy Neovim config
Copy-Item ".\.config\nvim\init.vim" "$env:LOCALAPPDATA\nvim\init.vim" -Force
Write-Host "OK Neovim config"

# Deploy Espanso configs
Copy-Item ".\.config\espanso\config\*" "$env:APPDATA\espanso\config\" -Force
Copy-Item ".\.config\espanso\match\*" "$env:APPDATA\espanso\match\" -Force
Write-Host "OK Espanso configs"

# Deploy Claude config
Copy-Item ".\.claude\*" "$env:USERPROFILE\.claude\" -Force -Recurse
Write-Host "OK Claude config"

# Deploy SSH config
Copy-Item ".\.ssh\config" "$env:USERPROFILE\.ssh\config" -Force
Write-Host "OK SSH config"

Write-Host "Dotfiles deployment complete!" -ForegroundColor Green
