# ============================================================================
# Initialize WiFi Adapter - Disable DHCP by Default
# Run this once to set WiFi adapter to static mode by default
# ============================================================================

Write-Host "=== Initializing WiFi Adapter ===" -ForegroundColor Cyan
Write-Host "This disables DHCP by default to prevent DHCP requests" -ForegroundColor Gray
Write-Host ""

# Check admin
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Must run as Administrator!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Get WiFi adapter
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" }

if (-not $wifiAdapter) {
    Write-Host "[ERROR] No Wi-Fi adapter found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$interfaceIndex = $wifiAdapter.ifIndex
$interfaceName = $wifiAdapter.Name

Write-Host "[*] Found WiFi Adapter: $interfaceName" -ForegroundColor Cyan
Write-Host ""

# Disable DHCP by default
Write-Host "[*] Disabling DHCP on WiFi adapter..." -ForegroundColor Yellow

try {
    Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
    Write-Host "[OK] DHCP disabled successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Result:" -ForegroundColor Cyan
    Write-Host "  - WiFi adapter will NOT send DHCP requests by default" -ForegroundColor Gray
    Write-Host "  - Event handler will enable DHCP only for unknown networks" -ForegroundColor Gray
    Write-Host "  - Event handler will apply static IP for company networks" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[IMPORTANT] This prevents DHCP requests for company networks!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to disable DHCP: $_" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
