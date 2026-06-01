# ============================================================
# sync-backend-to-render.ps1
# Syncs the latest backend code from Ludo_Game/backend/ into
# the separate Ludo_Backend GitHub repository that Render uses.
#
# Usage (from C:\Ludo_Game):
#   .\sync-backend-to-render.ps1
#   .\sync-backend-to-render.ps1 -Message "feat: add new endpoint"
# ============================================================

param(
    [string]$Message = "chore: sync backend from Ludo_Game monorepo"
)

$ErrorActionPreference = "Stop"

$MONOREPO_BACKEND  = "$PSScriptRoot\backend"
$RENDER_REPO_URL   = "https://github.com/Pedapolukarthik/Ludo_Backend.git"
$TEMP_DIR          = "$PSScriptRoot\_render_sync_temp"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Ludo Backend -> Render Sync Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean up any leftover temp directory
if (Test-Path $TEMP_DIR) {
    Write-Host "[1/5] Cleaning up leftover temp directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $TEMP_DIR
}

# Step 2: Clone the Render repo
Write-Host "[2/5] Cloning Ludo_Backend repository..." -ForegroundColor Yellow
git clone $RENDER_REPO_URL $TEMP_DIR
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to clone repository." -ForegroundColor Red
    exit 1
}

# Step 3: Copy latest backend files (excluding .git, node_modules, .env)
Write-Host "[3/5] Copying latest backend files..." -ForegroundColor Yellow

# Copy src/ folder
Copy-Item -Path "$MONOREPO_BACKEND\src\*" -Destination "$TEMP_DIR\src\" -Recurse -Force

# Copy root-level files
$rootFiles = @("server.js", "package.json", ".env.example")
foreach ($file in $rootFiles) {
    $src = "$MONOREPO_BACKEND\$file"
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination "$TEMP_DIR\" -Force
    }
}

# Step 4: Commit the changes
Write-Host "[4/5] Committing changes..." -ForegroundColor Yellow
Push-Location $TEMP_DIR
git add -A
$hasChanges = git status --porcelain
if (-not $hasChanges) {
    Write-Host "  No changes detected. Render is already up to date!" -ForegroundColor Green
    Pop-Location
    Remove-Item -Recurse -Force $TEMP_DIR
    exit 0
}
git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Commit failed." -ForegroundColor Red
    Pop-Location
    exit 1
}

# Step 5: Push to GitHub (triggers Render auto-deploy)
Write-Host "[5/5] Pushing to GitHub (this will trigger Render deploy)..." -ForegroundColor Yellow
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Push failed." -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# Cleanup
Write-Host ""
Write-Host "  Cleaning up temp directory..." -ForegroundColor Gray
Remove-Item -Recurse -Force $TEMP_DIR

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SUCCESS! Render deployment triggered." -ForegroundColor Green
Write-Host "  Watch your Render Dashboard for the" -ForegroundColor Green
Write-Host "  new deployment to go Live (2-5 min)." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
