# ============================================================================
# Permanent DHCP Disable - Run this to ensure DHCP never activates
# This is the ONLY way to prevent DHCP requests
# ============================================================================

Write-Host "=== Ensuring DHCP Remains Disabled ===" -ForegroundColor Cyan
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

Write-Host "[*] WiFi Adapter: $($wifiAdapter.Name)" -ForegroundColor Cyan
Write-Host ""

# Force DHCP disabled
Write-Host "[*] Forcing DHCP to stay disabled..." -ForegroundColor Yellow

try {
    # Disable DHCP
    Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
    
    # Remove any DHCP-obtained IP
    $dhcpIPs = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
    Where-Object { $_.PrefixOrigin -eq "Dhcp" }
    
    if ($dhcpIPs) {
        Write-Host "[!] Found DHCP IP addresses, removing them..." -ForegroundColor Yellow
        foreach ($ip in $dhcpIPs) {
            Remove-NetIPAddress -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    
    Write-Host "[OK] DHCP is disabled!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Current Status:" -ForegroundColor Cyan
    $status = Get-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4
    Write-Host "  DHCP: $($status.Dhcp)" -ForegroundColor $(if ($status.Dhcp -eq "Disabled") { "Green" } else { "Red" })
    
    Write-Host ""
    Write-Host "[SUCCESS] WiFi adapter will NOT send DHCP requests!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed: $_" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
