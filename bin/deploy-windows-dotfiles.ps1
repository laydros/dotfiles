# deploy-windows-dotfiles.ps1
# Deploy shared dotfiles from yadm repo to Windows

$ErrorActionPreference = "Stop"

Write-Host "Deploying dotfiles to Windows..." -ForegroundColor Green

# Ensure target directories exist
$configDirs = @(
    "$env:USERPROFILE\.config\git",
    "$env:USERPROFILE\.config\nvim",
    "$env:APPDATA\espanso\config",
    "$env:APPDATA\espanso\match"
)

foreach ($dir in $configDirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Yellow
    }
}

# Deploy Git config (remove ##template suffix)
Copy-Item ".\.config\git\config##template" "$env:USERPROFILE\.config\git\config" -Force
Write-Host "✓ Git config"

# Deploy Git ignore  
Copy-Item ".\.config\git\gitignore" "$env:USERPROFILE\.config\git\ignore" -Force
Write-Host "✓ Git ignore"

# Deploy Neovim config
Copy-Item ".\.config\nvim\init.vim" "$env:USERPROFILE\.config\nvim\init.vim" -Force
Write-Host "✓ Neovim config"

# Deploy Espanso configs
Copy-Item ".\.config\espanso\config\*" "$env:APPDATA\espanso\config\" -Force
Copy-Item ".\.config\espanso\match\*" "$env:APPDATA\espanso\match\" -Force  
Write-Host "✓ Espanso configs"

Write-Host "Dotfiles deployment complete!" -ForegroundColor Green