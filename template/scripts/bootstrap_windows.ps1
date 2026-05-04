# SAM Deployment Bootstrap — Windows
# Run during remote session (Tailscale SSH or screen share). Requires admin for some installs.
# Usage: powershell -ExecutionPolicy Bypass -File bootstrap_windows.ps1 -ClientSlug gotbedlam

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientSlug
)

$ErrorActionPreference = "Stop"
$STACK_ROOT = "$env:USERPROFILE\.sam"
$REPO_URL = "git@github.com:StrangeAdvancedMarketing/sam-deployments.git"
$CLIENT_DIR = "$STACK_ROOT\clients\$ClientSlug"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SAM Stack Bootstrap - Windows"
Write-Host "  Client: $ClientSlug"
Write-Host "  Target: $STACK_ROOT"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. Check winget ----------
Write-Host "[1/10] Checking winget..." -ForegroundColor Yellow
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: winget not found. Install App Installer from Microsoft Store first." -ForegroundColor Red
    exit 1
}
Write-Host "  winget: OK"

# ---------- 2. Core deps ----------
Write-Host "[2/10] Installing core deps (Node, Python, Git, FFmpeg)..." -ForegroundColor Yellow
$deps = @(
    @{id="OpenJS.NodeJS.LTS"; name="Node.js"},
    @{id="Python.Python.3.12"; name="Python 3.12"},
    @{id="Git.Git"; name="Git"},
    @{id="Gyan.FFmpeg"; name="FFmpeg"}
)

foreach ($dep in $deps) {
    $installed = winget list --id $dep.id 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed -match $dep.id) {
        Write-Host "  $($dep.name): already installed"
    } else {
        Write-Host "  Installing $($dep.name)..."
        winget install --id $dep.id --accept-source-agreements --accept-package-agreements -h
    }
}

# ---------- 3. Claude Code CLI ----------
Write-Host "[3/10] Installing Claude Code CLI..." -ForegroundColor Yellow
$npxCheck = npm list -g @anthropic-ai/claude-code 2>$null
if ($LASTEXITCODE -ne 0) {
    npm install -g @anthropic-ai/claude-code
} else {
    Write-Host "  Claude Code: already installed"
}

# ---------- 4. Voice I/O ----------
Write-Host "[4/10] Installing edge-tts + whisper..." -ForegroundColor Yellow
pip install --user edge-tts openai-whisper 2>$null

# ---------- 5. Clone sam-deployments (sparse) ----------
Write-Host "[5/10] Cloning sam-deployments (sparse-checkout)..." -ForegroundColor Yellow
if (-not (Test-Path $STACK_ROOT)) { New-Item -ItemType Directory -Path $STACK_ROOT -Force | Out-Null }

if (-not (Test-Path "$STACK_ROOT\sam-deployments\.git")) {
    Push-Location $STACK_ROOT
    git clone --filter=blob:none --sparse $REPO_URL sam-deployments
    Set-Location sam-deployments
    git sparse-checkout init --cone
    git sparse-checkout set "clients/$ClientSlug" "template"
    Pop-Location
} else {
    Push-Location "$STACK_ROOT\sam-deployments"
    git pull --ff-only
    Pop-Location
}

# ---------- 6. Tailscale ----------
Write-Host "[6/10] Installing Tailscale..." -ForegroundColor Yellow
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements -h
    Write-Host "  -> Open Tailscale and sign in. SAM will invite you to the tailnet."
} else {
    Write-Host "  Tailscale: already installed"
}

# ---------- 7. Obsidian ----------
Write-Host "[7/10] Installing Obsidian..." -ForegroundColor Yellow
if (-not (Test-Path "$env:LOCALAPPDATA\Obsidian\Obsidian.exe")) {
    winget install --id Obsidian.Obsidian --accept-source-agreements --accept-package-agreements -h
} else {
    Write-Host "  Obsidian: already installed"
}

# ---------- 8. gog.exe ----------
Write-Host "[8/10] Setting up gog.exe (Google Workspace CLI)..." -ForegroundColor Yellow
$gogDir = "$STACK_ROOT\gogcli"
if (-not (Test-Path "$gogDir\gog.exe")) {
    New-Item -ItemType Directory -Path $gogDir -Force | Out-Null
    Write-Host "  -> gog.exe must be copied manually (binary not in package manager)"
    Write-Host "  -> Target: $gogDir\gog.exe"
} else {
    Write-Host "  gog.exe: already present"
}

# ---------- 9. Nightly git-pull scheduled task ----------
Write-Host "[9/10] Creating nightly git-pull task (3 AM ET)..." -ForegroundColor Yellow
$taskName = "SAM-NightlyUpdate-$ClientSlug"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -eq $existingTask) {
    $action = New-ScheduledTaskAction -Execute "git" -Argument "-C `"$STACK_ROOT\sam-deployments`" pull --ff-only" -WorkingDirectory $STACK_ROOT
    $trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "SAM: nightly config pull for $ClientSlug"
    Write-Host "  Task registered: $taskName (3 AM daily)"
} else {
    Write-Host "  Task already exists: $taskName"
}

# ---------- 10. Credential setup ----------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  [10/10] Live credential setup - Jereme drives this section"
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  The remaining items are handled live with the client watching:"
Write-Host ""
Write-Host "    1. Telegram bot - create via BotFather OR use SAM-provisioned bot"
Write-Host "    2. Anthropic login - client signs into Claude Pro at claude.ai"
Write-Host "    3. Google Workspace - gog.exe auth add <email>"
Write-Host "    4. Shopify Admin API - store > Apps > Develop apps > create token"
Write-Host "    5. Postiz - client signs up, connects socials, copies API key"
Write-Host "    6. ChatGPT data export - client exports, we import into Obsidian"
Write-Host ""
Write-Host "  Once credentials are captured, write them to:"
Write-Host "    $STACK_ROOT\credentials.env"
Write-Host ""
Write-Host "  Stack location: $STACK_ROOT"
Write-Host "  Client folder: $CLIENT_DIR"
Write-Host ""
Write-Host "  Ready for fine-tuning." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
