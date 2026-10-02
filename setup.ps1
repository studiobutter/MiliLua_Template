# =============================================================================
#  MiliLua Development Environment Setup
#  Genshin Impact - Miliastra Wonderland (BeyondLocal Lua Scripting)
# =============================================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host ">> $Text" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "  [..] $Text" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  [!!] $Text" -ForegroundColor Magenta
}

function Pause-ForUser {
    Write-Host ""
    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ── Banner ────────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  ███╗   ███╗██╗██╗     ██╗██╗     ██╗   ██╗ █████╗ " -ForegroundColor Magenta
Write-Host "  ████╗ ████║██║██║     ██║██║     ██║   ██║██╔══██╗" -ForegroundColor Magenta
Write-Host "  ██╔████╔██║██║██║     ██║██║     ██║   ██║███████║" -ForegroundColor Magenta
Write-Host "  ██║╚██╔╝██║██║██║     ██║██║     ██║   ██║██╔══██║" -ForegroundColor Magenta
Write-Host "  ██║ ╚═╝ ██║██║███████╗██║███████╗╚██████╔╝██║  ██║" -ForegroundColor Magenta
Write-Host "  ╚═╝     ╚═╝╚═╝╚══════╝╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Genshin Impact · Miliastra Wonderland · Lua Dev Setup" -ForegroundColor White
Write-Host ""

# =============================================================================
#  STEP 1 — Check / Install Visual Studio Code
# =============================================================================

Write-Header "STEP 1 · Visual Studio Code"

function Test-VSCode {
    # Check common install paths and PATH
    $codePaths = @(
        (Get-Command "code" -ErrorAction SilentlyContinue)?.Source,
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    ) | Where-Object { $_ -and (Test-Path $_) }

    return $codePaths.Count -gt 0
}

Write-Step "Checking for Visual Studio Code..."

if (Test-VSCode) {
    Write-OK "VS Code is already installed."
} else {
    Write-Warn "VS Code was not found. Installing via winget..."

    # Try winget first
    $winget = Get-Command "winget" -ErrorAction SilentlyContinue
    if ($winget) {
        try {
            winget install --id Microsoft.VisualStudioCode --silent --accept-package-agreements --accept-source-agreements
            Write-OK "VS Code installed successfully via winget."
        } catch {
            Write-Warn "winget install failed: $_"
            Write-Info "Please install VS Code manually from https://code.visualstudio.com/"
            Pause-ForUser
            exit 1
        }
    } else {
        Write-Warn "winget is not available on this system."
        Write-Info "Opening the VS Code download page..."
        Start-Process "https://code.visualstudio.com/Download"
        Write-Info "Please install VS Code, then re-run this script."
        Pause-ForUser
        exit 1
    }

    # Refresh PATH so 'code' is available in this session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")

    if (-not (Test-VSCode)) {
        Write-Warn "VS Code still not detected on PATH. Please restart your terminal and re-run."
        Pause-ForUser
        exit 1
    }
}

# Resolve the 'code' executable for later use
$codeExe = (Get-Command "code" -ErrorAction SilentlyContinue)?.Source
if (-not $codeExe) {
    # Fallback to known locations
    foreach ($p in @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )) {
        if (Test-Path $p) { $codeExe = $p; break }
    }
}

# =============================================================================
#  STEP 2 — Check / Install VS Code Extensions
# =============================================================================

Write-Header "STEP 2 · VS Code Extensions"

$requiredExtensions = @(
    @{ Id = "sumneko.lua";                        Name = "Lua Language Server (sumneko)" },
    @{ Id = "haminpants.mililua-api-definitions"; Name = "MiliLua API Definitions" }
)

Write-Step "Checking required extensions..."

foreach ($ext in $requiredExtensions) {
    $installed = & $codeExe --list-extensions 2>$null | Where-Object { $_ -ieq $ext.Id }

    if ($installed) {
        Write-OK "$($ext.Name) [$($ext.Id)] — already installed."
    } else {
        Write-Info "Installing $($ext.Name) [$($ext.Id)]..."
        try {
            & $codeExe --install-extension $ext.Id --force 2>&1 | Out-Null
            Write-OK "$($ext.Name) installed."
        } catch {
            Write-Warn "Failed to install $($ext.Name): $_"
        }
    }
}

# =============================================================================
#  STEP 3 — Locate BeyondLocal Development Folder
# =============================================================================

Write-Header "STEP 3 · Locate Miliastra Wonderland Dev Folder"

$beyondLocalRoot = "C:\Users\$env:USERNAME\AppData\LocalLow\miHoYo\Genshin Impact\BeyondLocal"

Write-Step "Looking for BeyondLocal at:"
Write-Info $beyondLocalRoot

if (-not (Test-Path $beyondLocalRoot)) {
    Write-Warn "BeyondLocal folder not found at expected path:"
    Write-Warn "  $beyondLocalRoot"
    Write-Info ""
    Write-Info "Please make sure Genshin Impact is installed and you have"
    Write-Info "entered the Miliastra Wonderland at least once."
    Pause-ForUser
    exit 1
}

# ── Detect UID folders ────────────────────────────────────────────────────────

Write-Step "Scanning for UID folders (6x / 7x / 8x / 9x / 18x)..."

$uidPattern = "^(6|7|8|9|18)\d+"
$uidFolders = Get-ChildItem -Path $beyondLocalRoot -Directory |
              Where-Object { $_.Name -match $uidPattern } |
              Sort-Object Name

if ($uidFolders.Count -eq 0) {
    Write-Warn "No UID folders found inside BeyondLocal."
    Write-Info "Please enter the Miliastra Wonderland in-game at least once."
    Pause-ForUser
    exit 1
}

# ── Select UID ───────────────────────────────────────────────────────────────

$selectedUID = $null

if ($uidFolders.Count -eq 1) {
    $selectedUID = $uidFolders[0]
    Write-OK "Found single UID: $($selectedUID.Name)"
} else {
    Write-Host ""
    Write-Host "  Multiple UIDs found. Please select one:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $uidFolders.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $uidFolders[$i].Name) -ForegroundColor Cyan
    }
    Write-Host ""

    do {
        $raw = Read-Host "  Enter number (1-$($uidFolders.Count))"
        $choice = $raw -as [int]
    } while (-not $choice -or $choice -lt 1 -or $choice -gt $uidFolders.Count)

    $selectedUID = $uidFolders[$choice - 1]
    Write-OK "Selected UID: $($selectedUID.Name)"
}

# =============================================================================
#  STEP 4 — Select Save Folder
# =============================================================================

Write-Header "STEP 4 · Select Save Folder"

$saveLevelRoot = Join-Path $selectedUID.FullName "Beyond_Local_Save_Level"

if (-not (Test-Path $saveLevelRoot)) {
    Write-Warn "Beyond_Local_Save_Level folder not found under UID $($selectedUID.Name)."
    Write-Info "Path checked: $saveLevelRoot"
    Write-Info "Please enter the Miliastra Wonderland and create a save at least once."
    Pause-ForUser
    exit 1
}

Write-Step "Scanning save folders in:"
Write-Info $saveLevelRoot

$saveFolders = Get-ChildItem -Path $saveLevelRoot -Directory | Sort-Object Name

if ($saveFolders.Count -eq 0) {
    Write-Warn "No save folders found. Please create a save in-game first."
    Pause-ForUser
    exit 1
}

Write-Host ""
Write-Host "  Available save folders:" -ForegroundColor White
Write-Host ""

for ($i = 0; $i -lt $saveFolders.Count; $i++) {
    $saveDir    = $saveFolders[$i]
    $luaPath    = Join-Path $saveDir.FullName "external_lua_file"
    $hasLua     = Test-Path $luaPath
    $luaStatus  = if ($hasLua) { "[Lua OK]" } else { "[No Lua]" }
    $luaColor   = if ($hasLua) { "Green"    } else { "DarkGray" }

    Write-Host ("  [{0}] {1}  " -f ($i + 1), $saveDir.Name) -NoNewline -ForegroundColor Cyan
    Write-Host $luaStatus -ForegroundColor $luaColor
}

Write-Host ""

do {
    $raw = Read-Host "  Enter number (1-$($saveFolders.Count))"
    $choice = $raw -as [int]
} while (-not $choice -or $choice -lt 1 -or $choice -gt $saveFolders.Count)

$selectedSave   = $saveFolders[$choice - 1]
$luaFolder      = Join-Path $selectedSave.FullName "external_lua_file"

Write-OK "Selected save: $($selectedSave.Name)"

# Create external_lua_file folder if it doesn't exist yet
if (-not (Test-Path $luaFolder)) {
    Write-Info "Creating external_lua_file folder..."
    New-Item -ItemType Directory -Path $luaFolder | Out-Null
    Write-OK "Folder created: $luaFolder"
} else {
    Write-OK "Lua folder exists: $luaFolder"
}

# =============================================================================
#  STEP 5 — Write VS Code Workspace Settings (.vscode)
# =============================================================================

Write-Header "STEP 5 · Configure VS Code Workspace"

$vscodeDir = Join-Path $luaFolder ".vscode"
if (-not (Test-Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir | Out-Null
}

# ── settings.json ─────────────────────────────────────────────────────────────

$settingsJson = @"
{
    "Lua.runtime.version": "Lua 5.4",
    "Lua.workspace.library": [],
    "Lua.workspace.checkThirdParty": false,
    "Lua.diagnostics.globals": [
        "WORLD",
        "EVENT",
        "TRIGGER",
        "ENTITY",
        "PLAYER",
        "Timer",
        "Vector3",
        "Quaternion",
        "Color",
        "Log",
        "CS"
    ],
    "Lua.hint.enable": true,
    "Lua.hint.paramType": true,
    "Lua.hint.returnType": true,
    "Lua.completion.autoRequire": false,
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.formatOnSave": true,
    "files.eol": "\n",
    "[lua]": {
        "editor.defaultFormatter": "sumneko.lua"
    }
}
"@

$settingsPath = Join-Path $vscodeDir "settings.json"
$settingsJson | Set-Content -Path $settingsPath -Encoding UTF8
Write-OK "Written: .vscode\settings.json"

# ── extensions.json (workspace recommendations) ───────────────────────────────

$extensionsJson = @"
{
    "recommendations": [
        "sumneko.lua",
        "haminpants.mililua-api-definitions"
    ]
}
"@

$extensionsPath = Join-Path $vscodeDir "extensions.json"
$extensionsJson | Set-Content -Path $extensionsPath -Encoding UTF8
Write-OK "Written: .vscode\extensions.json"

# =============================================================================
#  STEP 6 — Open Folder in VS Code
# =============================================================================

Write-Header "STEP 6 · Launch VS Code"

Write-Step "Opening folder in VS Code:"
Write-Info $luaFolder
Write-Host ""

try {
    & $codeExe $luaFolder
    Write-OK "VS Code launched successfully!"
} catch {
    Write-Warn "Could not launch VS Code automatically: $_"
    Write-Info "Please open the folder manually:"
    Write-Info "  $luaFolder"
}

# =============================================================================
#  Done
# =============================================================================

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  Setup complete! Happy scripting, Craftperson!" -ForegroundColor White
Write-Host ""
Write-Host "  Folder  : $luaFolder" -ForegroundColor Gray
Write-Host "  UID     : $($selectedUID.Name)" -ForegroundColor Gray
Write-Host "  Save    : $($selectedSave.Name)" -ForegroundColor Gray
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
