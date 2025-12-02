# Quick verification of WiFi IP configuration

Write-Host "=== WiFi IP Configuration Status ===" -ForegroundColor Cyan
Write-Host ""

# Get current WiFi connection
$ssid = (netsh wlan show interfaces | Select-String "^\s*Profile\s*:\s*(.+)").Matches[0].Groups[1].Value.Trim()

if ($ssid) {
    Write-Host "Connected to: $ssid" -ForegroundColor Green
    Write-Host ""
    
    # Get IP configuration
    $ipConfig = Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dhcpStatus = (Get-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4).Dhcp
    $dnsServers = (Get-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4).ServerAddresses
    $gateway = (Get-NetRoute -InterfaceAlias 'Wi-Fi' -DestinationPrefix '0.0.0.0/0').NextHop
    
    Write-Host "IP Address:      $($ipConfig.IPAddress)" -ForegroundColor White
    Write-Host "Subnet Mask:     /$($ ipConfig.PrefixLength) (255.255.255.0)" -ForegroundColor White
    Write-Host "Default Gateway: $gateway" -ForegroundColor White
    Write-Host "DNS Servers:     $($dnsServers -join ', ')" -ForegroundColor White
    Write-Host ""
    Write-Host "DHCP Status:     $dhcpStatus" -ForegroundColor $(if ($dhcpStatus -eq "Disabled") { "Green" } else { "Yellow" })
    Write-Host "IP Origin:       $($ipConfig.PrefixOrigin)" -ForegroundColor $(if ($ipConfig.PrefixOrigin -eq "Manual") { "Green" } else { "Yellow" })
    
    Write-Host ""
    if ($dhcpStatus -eq "Disabled" -and $ipConfig.PrefixOrigin -eq "Manual") {
        Write-Host "[OK] Static IP is configured correctly!" -ForegroundColor Green
    }
    else {
        Write-Host "[!] Using DHCP" -ForegroundColor Yellow
    }
}
else {
    Write-Host "[!] Not connected to WiFi" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Log File ===" -ForegroundColor Cyan
Write-Host "Last 10 log entries:" -ForegroundColor Gray
Get-Content (Join-Path $PSScriptRoot "NetworkEventHandler.log") -Tail 10 -ErrorAction SilentlyContinue

Write-Host ""
Read-Host "Press Enter to exit"
