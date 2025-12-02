# ============================================================================
# Apply Ethernet Configuration (Manual Trigger)
# Run this script as Administrator to immediately apply the configuration
# ============================================================================

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Restarting with elevated permissions..." -ForegroundColor Yellow
    Start-Process "PowerShell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Run the event handler
$HandlerScript = Join-Path $PSScriptRoot "EthernetEventHandler.ps1"
& $HandlerScript

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
