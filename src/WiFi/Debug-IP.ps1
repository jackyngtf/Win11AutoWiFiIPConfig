$ErrorActionPreference = "Continue"

function Test-IPAssignment {
    Write-Host "--- Debugging IP Assignment ---" -ForegroundColor Cyan
    
    # 1. Get Adapter
    $wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }
    if (-not $wifiAdapter) {
        Write-Host "[ERROR] No WiFi adapter found." -ForegroundColor Red
        return
    }
    $idx = $wifiAdapter.ifIndex
    Write-Host "Adapter: $($wifiAdapter.Name) (Index: $idx)" -ForegroundColor Gray
    
    # 2. Check Current State
    $netIP = Get-NetIPConfiguration -InterfaceIndex $idx
    Set-NetIPInterface -InterfaceIndex $idx -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
        
    # B. Remove existing IP
    Write-Host "  2. Removing existing IPs..."
    Remove-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        
    # C. Add New IP
    Write-Host "  3. Adding New IP..."
    New-NetIPAddress -InterfaceIndex $idx -IPAddress $StaticIP -PrefixLength $Prefix -DefaultGateway $Gateway -AddressFamily IPv4 -ErrorAction Stop
        
    # D. Set DNS
    Write-Host "  4. Setting DNS..."
    Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $DNS -ErrorAction Stop
        
    Write-Host "[SUCCESS] Static IP applied." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to set Static IP: $_" -ForegroundColor Red
    Write-Host "Exception Details: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Verify Result
Start-Sleep -Seconds 2
$newIP = Get-NetIPConfiguration -InterfaceIndex $idx
Write-Host "`n--- Verification ---"
Write-Host "New IP: $($newIP.IPv4Address.IPAddress)"
Write-Host "DHCP Status: $((Get-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4).Dhcp)"
}

Test-IPAssignment
