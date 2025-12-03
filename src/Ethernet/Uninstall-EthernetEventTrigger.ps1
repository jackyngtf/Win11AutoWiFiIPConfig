# ============================================================================
# Uninstall Ethernet Event Trigger
# Removes the Scheduled Task and restores default settings (DHCP)
# ============================================================================

$TaskName = "Ethernet-AutoConfig"

# 1. Unregister Task
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Host "Removing scheduled task: $TaskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
else {
    Write-Host "Task '$TaskName' not found." -ForegroundColor Gray
}

# 2. Restore DHCP on all Ethernet Adapters (Optional but recommended)
Write-Host "Restoring DHCP on all active Ethernet adapters..." -ForegroundColor Cyan
$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3" }

foreach ($Adapter in $Adapters) {
    Write-Host "Resetting adapter: $($Adapter.Name)"
    
    # 1. Remove Default Gateway (Route)
    Get-NetRoute -InterfaceAlias $Adapter.Name -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

    # 2. Remove Static IP Addresses
    Remove-NetIPAddress -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

    # 3. Enable DHCP
    Set-NetIPInterface -InterfaceAlias $Adapter.Name -Dhcp Enabled -ErrorAction SilentlyContinue
    
    # 4. Reset DNS
    Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ResetServerAddresses -ErrorAction SilentlyContinue
}

Write-Host "Uninstall Complete. Ethernet adapters are back to default (DHCP)." -ForegroundColor Green

# 3. Re-enable WiFi (in case it was disabled by Auto-Switch)
Write-Host "Ensuring WiFi is enabled..." -ForegroundColor Cyan
Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
