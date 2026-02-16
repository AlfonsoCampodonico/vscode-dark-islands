# Islands Dark Theme Installer for Windows

param()

$ErrorActionPreference = "Stop"

Write-Host "Islands Dark Theme Installer for Windows" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check which editors are available
$HasVSCode = $false
$HasCursor = $false

$codePath = Get-Command "code" -ErrorAction SilentlyContinue
if ($codePath) {
    $HasVSCode = $true
} else {
    # Try to find code in common locations
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $env:Path += ";$(Split-Path $path)"
            $HasVSCode = $true
            break
        }
    }
}

$cursorPath = Get-Command "cursor" -ErrorAction SilentlyContinue
if ($cursorPath) {
    $HasCursor = $true
} else {
    $possibleCursorPaths = @(
        "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd",
        "$env:LOCALAPPDATA\cursor\cursor.cmd"
    )
    foreach ($path in $possibleCursorPaths) {
        if (Test-Path $path) {
            $env:Path += ";$(Split-Path $path)"
            $HasCursor = $true
            break
        }
    }
}

if (-not $HasVSCode -and -not $HasCursor) {
    Write-Host "Error: Neither VS Code CLI (code) nor Cursor CLI (cursor) found!" -ForegroundColor Red
    Write-Host "Please install VS Code or Cursor and make sure the CLI command is in your PATH."
    exit 1
}

if ($HasVSCode) { Write-Host "VS Code CLI found" -ForegroundColor Green }
if ($HasCursor) { Write-Host "Cursor CLI found" -ForegroundColor Green }

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "Step 1: Installing Islands Dark theme extension..."

# Install for VS Code
if ($HasVSCode) {
    $extDir = "$env:USERPROFILE\.vscode\extensions\bwya77.islands-dark-1.0.0"
    if (Test-Path $extDir) { Remove-Item -Recurse -Force $extDir }
    New-Item -ItemType Directory -Path $extDir -Force | Out-Null
    Copy-Item "$scriptDir\package.json" "$extDir\" -Force
    Copy-Item "$scriptDir\themes" "$extDir\themes" -Recurse -Force
    if (Test-Path "$extDir\themes") {
        Write-Host "Theme extension installed to $extDir" -ForegroundColor Green
    } else {
        Write-Host "Failed to install theme extension for VS Code" -ForegroundColor Red
    }
}

# Install for Cursor
if ($HasCursor) {
    $extDir = "$env:USERPROFILE\.cursor\extensions\bwya77.islands-dark-1.0.0"
    if (Test-Path $extDir) { Remove-Item -Recurse -Force $extDir }
    New-Item -ItemType Directory -Path $extDir -Force | Out-Null
    Copy-Item "$scriptDir\package.json" "$extDir\" -Force
    Copy-Item "$scriptDir\themes" "$extDir\themes" -Recurse -Force
    if (Test-Path "$extDir\themes") {
        Write-Host "Theme extension installed to $extDir" -ForegroundColor Green
    } else {
        Write-Host "Failed to install theme extension for Cursor" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Step 2: Installing Custom UI Style extension..."
if ($HasVSCode) {
    try {
        $output = code --install-extension subframe7536.custom-ui-style --force 2>&1
        Write-Host "Custom UI Style extension installed for VS Code" -ForegroundColor Green
    } catch {
        Write-Host "Could not install Custom UI Style extension for VS Code" -ForegroundColor Yellow
    }
}
if ($HasCursor) {
    try {
        $output = cursor --install-extension subframe7536.custom-ui-style --force 2>&1
        Write-Host "Custom UI Style extension installed for Cursor" -ForegroundColor Green
    } catch {
        Write-Host "Could not install Custom UI Style extension for Cursor" -ForegroundColor Yellow
        Write-Host "   Please install it manually from the Extensions marketplace in Cursor"
    }
}

Write-Host ""
Write-Host "Step 3: Installing Bear Sans UI fonts..."
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

# Try user fonts first
if (-not (Test-Path $fontDir)) {
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
}

try {
    $fonts = Get-ChildItem "$scriptDir\fonts\*.otf"
    foreach ($font in $fonts) {
        try {
            Copy-Item $font.FullName $fontDir -Force -ErrorAction SilentlyContinue
        } catch {
            # Silently continue if copy fails
        }
    }

    Write-Host "Fonts installed" -ForegroundColor Green
    Write-Host "   Note: You may need to restart applications to use the new fonts" -ForegroundColor DarkGray
} catch {
    Write-Host "Could not install fonts automatically" -ForegroundColor Yellow
    Write-Host "   Please manually install the fonts from the 'fonts/' folder"
    Write-Host "   Select all .otf files and right-click > Install"
}

Write-Host ""
Write-Host "Step 4: Applying settings..."

# Function to strip JSONC features (comments and trailing commas) for JSON parsing
function Strip-Jsonc {
    param([string]$Text)
    $Text = $Text -replace '//.*$', ''
    $Text = $Text -replace '/\*[\s\S]*?\*/', ''
    $Text = $Text -replace ',\s*([}\]])', '$1'
    return $Text
}

$newSettingsRaw = Get-Content "$scriptDir\settings.json" -Raw
$newSettings = (Strip-Jsonc $newSettingsRaw) | ConvertFrom-Json

function Apply-EditorSettings {
    param([string]$EditorName, [string]$SettingsDir)

    if (-not (Test-Path $SettingsDir)) {
        New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null
    }

    $settingsFile = Join-Path $SettingsDir "settings.json"
    Write-Host "   Applying settings for $EditorName..."

    if (Test-Path $settingsFile) {
        Write-Host "   Existing $EditorName settings.json found" -ForegroundColor Yellow
        Write-Host "   Backing up to settings.json.backup"
        Copy-Item $settingsFile "$settingsFile.backup" -Force

        try {
            $existingRaw = Get-Content $settingsFile -Raw
            $existingSettings = (Strip-Jsonc $existingRaw) | ConvertFrom-Json

            $mergedSettings = @{}
            $existingSettings.PSObject.Properties | ForEach-Object {
                $mergedSettings[$_.Name] = $_.Value
            }
            $newSettings.PSObject.Properties | ForEach-Object {
                $mergedSettings[$_.Name] = $_.Value
            }

            $stylesheetKey = 'custom-ui-style.stylesheet'
            if ($existingSettings.$stylesheetKey -and $newSettings.$stylesheetKey) {
                $mergedStylesheet = @{}
                $existingSettings.$stylesheetKey.PSObject.Properties | ForEach-Object {
                    $mergedStylesheet[$_.Name] = $_.Value
                }
                $newSettings.$stylesheetKey.PSObject.Properties | ForEach-Object {
                    $mergedStylesheet[$_.Name] = $_.Value
                }
                $mergedSettings[$stylesheetKey] = [PSCustomObject]$mergedStylesheet
            }

            [PSCustomObject]$mergedSettings | ConvertTo-Json -Depth 100 | Set-Content $settingsFile
            Write-Host "   $EditorName settings merged successfully" -ForegroundColor Green
        } catch {
            Write-Host "   Could not merge $EditorName settings automatically" -ForegroundColor Yellow
            Write-Host "   Please manually merge settings.json into your $EditorName settings"
            Write-Host "   Your original settings have been backed up to settings.json.backup"
        }
    } else {
        Copy-Item "$scriptDir\settings.json" $settingsFile
        Write-Host "   $EditorName settings applied" -ForegroundColor Green
    }
}

if ($HasVSCode) {
    Apply-EditorSettings "VS Code" "$env:APPDATA\Code\User"
}
if ($HasCursor) {
    Apply-EditorSettings "Cursor" "$env:APPDATA\Cursor\User"
}

Write-Host ""
Write-Host "Step 5: Enabling Custom UI Style..."

# Check if this is the first run
$firstRunFile = Join-Path $scriptDir ".islands_dark_first_run"
if (-not (Test-Path $firstRunFile)) {
    New-Item -ItemType File -Path $firstRunFile | Out-Null
    Write-Host ""
    Write-Host "Important Notes:" -ForegroundColor Yellow
    Write-Host "   - IBM Plex Mono and FiraCode Nerd Font Mono need to be installed separately"
    Write-Host "   - After VS Code reloads, you may see a 'corrupt installation' warning"
    Write-Host "   - This is expected - click the gear icon and select 'Don't Show Again'"
    Write-Host ""
    Read-Host "Press Enter to continue and reload VS Code"
}

Write-Host "   Applying CSS customizations..."

Write-Host ""
Write-Host "Islands Dark theme has been installed!" -ForegroundColor Green
Write-Host "   VS Code will now reload to apply the custom UI style."
Write-Host ""

# Reload editors
if ($HasVSCode) {
    Write-Host "   Reloading VS Code..." -ForegroundColor Cyan
    try { code --reload-window 2>$null } catch { code $scriptDir 2>$null }
}
if ($HasCursor) {
    Write-Host "   Reloading Cursor..." -ForegroundColor Cyan
    try { cursor --reload-window 2>$null } catch { cursor $scriptDir 2>$null }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

Start-Sleep -Seconds 3
