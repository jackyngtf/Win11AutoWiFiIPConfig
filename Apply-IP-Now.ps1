# ============================================================================
# APPLY IP CONFIGURATION NOW
# Manual trigger - use this to force apply configuration immediately
# ============================================================================

Write-Host "=== Applying IP Configuration Now ===" -ForegroundColor Cyan
Write-Host ""

# Run the handler script
$handlerScript = Join-Path $PSScriptRoot "NetworkEventHandler.ps1"

if (Test-Path $handlerScript) {
    & PowerShell.exe -ExecutionPolicy Bypass -File $handlerScript
    
    Write-Host ""
    Write-Host "=== Current Configuration ===" -ForegroundColor Cyan
    
    # Show current status
    Start-Sleep -Seconds 2
    
    $ssid = (netsh wlan show interfaces | Select-String "^\s*Profile\s*:\s*(.+)").Matches[0].Groups[1].Value.Trim()
    
    if ($ssid) {
        Write-Host "Connected to: $ssid" -ForegroundColor Green
        
        $ipConfig = Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dhcpStatus = (Get-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4).Dhcp
        
        Write-Host "IP Address:   $($ipConfig.IPAddress)" -ForegroundColor White
        Write-Host "DHCP Status:  $dhcpStatus" -ForegroundColor $(if ($dhcpStatus -eq "Disabled") { "Green" } else { "Yellow" })
        Write-Host "Origin:       $($ipConfig.PrefixOrigin)" -ForegroundColor $(if ($ipConfig.PrefixOrigin -eq "Manual") { "Green" } else { "Yellow" })
        
        Write-Host ""
        if ($dhcpStatus -eq "Disabled") {
            Write-Host "[OK] Static IP is active!" -ForegroundColor Green
        }
        else {
            Write-Host "[!] Using DHCP" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "[ERROR] Handler script not found!" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
