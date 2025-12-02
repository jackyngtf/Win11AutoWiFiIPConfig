# ============================================================================
# Uninstall Network Event Trigger
# This script removes the scheduled task for automatic IP configuration
# ============================================================================

Write-Host "=== Network Event Trigger Uninstall ===" -ForegroundColor Cyan
Write-Host "This will remove the automatic IP configuration task" -ForegroundColor Gray
Write-Host ""

# Check for administrator privileges
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$taskNames = @(
    "WiFi-AutoConfig-Connect",
    "WiFi-AutoConfig-Disconnect",
    "WiFi-AutoConfig-OnConnect",
    "AutoConfigureNetworkIP"
)

$removedCount = 0

foreach ($name in $taskNames) {
    Write-Host "[*] Checking for task: $name" -ForegroundColor Cyan
    $existingTask = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Host "    Found task. Removing..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Host "    [OK] Removed." -ForegroundColor Green
        $removedCount++
    }
    else {
        Write-Host "    Not found." -ForegroundColor Gray
    }
}

Write-Host ""
if ($removedCount -gt 0) {
    Write-Host "[OK] Uninstallation complete. $removedCount tasks removed." -ForegroundColor Green
}
else {
    Write-Host "[!] No installed tasks were found." -ForegroundColor Yellow
}

# ============================================================================
# CRITICAL SAFETY SEQUENCE: Disconnect -> Reset -> Disable -> Re-enable
# This prevents DHCP lease consumption during the transition
# ============================================================================

Write-Host ""
Write-Host "[!] SAFETY SEQUENCE: Preventing accidental DHCP lease..." -ForegroundColor Yellow
Write-Host ""

# Step 1: Disconnect from network FIRST (breaks connection, no active network)
Write-Host "[1/5] Disconnecting from current network..." -ForegroundColor Cyan
try {
    netsh wlan disconnect interface="Wi-Fi" | Out-Null
    Write-Host "      [OK] Disconnected from network." -ForegroundColor Green
}
catch {
    Write-Host "      [OK] Already disconnected or error (continuing...)." -ForegroundColor Gray
}

# Step 2: Reset to DHCP (safe - no active connection, no DHCP broadcast sent)
Write-Host "[2/5] Resetting to DHCP (while disconnected)..." -ForegroundColor Cyan
try {
    # Remove static default gateway first
    Write-Host "      - Removing static gateway..." -ForegroundColor Gray
    Remove-NetRoute -InterfaceAlias "Wi-Fi" -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    
    # Enable DHCP for IP
    Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Dhcp Enabled -ErrorAction Stop
    
    # Reset DNS to automatic
    Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses -ErrorAction Stop
    
    Write-Host "      [OK] DHCP settings applied (gateway cleared)." -ForegroundColor Green
}
catch {
    Write-Host "      [ERROR] Failed to reset settings: $_" -ForegroundColor Red
    Write-Host "      You may need to manually reset your IP settings." -ForegroundColor Yellow
}

# Step 3: Disable adapter (ensures clean state)
Write-Host "[3/5] Disabling adapter (clean state)..." -ForegroundColor Cyan
try {
    Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction Stop
    Write-Host "      [OK] Adapter disabled." -ForegroundColor Green
}
catch {
    Write-Host "      [ERROR] Failed to disable adapter: $_" -ForegroundColor Red
}

# Step 4: Wait for clean state
Write-Host "[4/5] Waiting for clean state..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
Write-Host "      [OK] Ready." -ForegroundColor Green

# Step 5: Re-enable adapter (comes up with DHCP enabled but NOT connected)
Write-Host "[5/5] Re-enabling Wi-Fi adapter..." -ForegroundColor Cyan
try {
    Enable-NetAdapter -Name "Wi-Fi" -ErrorAction Stop
    Write-Host "      [OK] Wi-Fi is now ON but NOT connected." -ForegroundColor Green
}
catch {
    Write-Host "      [ERROR] Failed to re-enable adapter: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                    UNINSTALL COMPLETE                          " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Current State:" -ForegroundColor Cyan
Write-Host "  [Y] Scheduled tasks removed" -ForegroundColor White
Write-Host "  [Y] DHCP enabled (Automatic IP)" -ForegroundColor White
Write-Host "  [Y] Wi-Fi adapter is ON" -ForegroundColor White
Write-Host "  [Y] NOT connected to any network" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "  - Your Wi-Fi is enabled but disconnected." -ForegroundColor Gray
Write-Host "  - Auto-connect is disabled for company networks." -ForegroundColor Gray
Write-Host "  - You must MANUALLY connect to any network." -ForegroundColor Gray
Write-Host ""
Write-Host "  If in office: Set Static IP BEFORE connecting to company WiFi." -ForegroundColor White
Write-Host "  If not in office: Safe to connect to any network." -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
