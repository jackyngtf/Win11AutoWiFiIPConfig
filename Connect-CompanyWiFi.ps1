# ============================================================================
# Connect to Company WiFi - Zero DHCP Solution
# This script ensures NO DHCP requests by controlling the connection process
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$NetworkName = "Company-WiFi-Main"
)

Write-Host "=== Connecting to $NetworkName ===" -ForegroundColor Cyan
Write-Host ""

# Check admin
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Must run as Administrator!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Load configuration
$scriptPath = $PSScriptRoot
$configFile = Join-Path $scriptPath "NetworkConfig.ps1"

if (Test-Path $configFile) {
    . $configFile
}
else {
    Write-Host "[ERROR] NetworkConfig.ps1 not found!" -ForegroundColor Red
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

Write-Host "[1] Disconnecting from current network..." -ForegroundColor Yellow
netsh wlan disconnect | Out-Null
Start-Sleep -Milliseconds 500

Write-Host "[2] Disabling DHCP on WiFi adapter..." -ForegroundColor Yellow
try {
    Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
    Write-Host "    DHCP is DISABLED" -ForegroundColor Green
}
catch {
    Write-Host "    Error: $_" -ForegroundColor Red
}

Write-Host "[3] Connecting to $NetworkName..." -ForegroundColor Yellow
netsh wlan connect name="$NetworkName" | Out-Null

# Wait for connection with timeout
Write-Host "    Waiting for connection..." -NoNewline -ForegroundColor Gray
$connected = $false
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    Write-Host "." -NoNewline -ForegroundColor Gray
    
    $netshOutput = netsh wlan show interfaces
    foreach ($line in $netshOutput) {
        if ($line -match '^\s*Profile\s*:\s*(.+)') {
            $currentSSID = $matches[1].Trim()
            if ($currentSSID -eq $NetworkName) {
                $connected = $true
                break
            }
        }
    }
    
    if ($connected) { break }
}
Write-Host ""

if (-not $connected) {
    Write-Host "    [!] Connection timeout or failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "    Connected!" -ForegroundColor Green

# Small delay to ensure adapter is ready
Start-Sleep -Milliseconds 500

Write-Host "[4] Applying static IP configuration..." -ForegroundColor Yellow

# Get network configuration
$matchingNetwork = $CompanyWiFiNetworks | Where-Object { $_.Name -eq $NetworkName }

if ($matchingNetwork) {
    $subnetMask = if ($matchingNetwork.SubnetMask) { $matchingNetwork.SubnetMask } else { $DefaultSubnetMask }
    $staticIP = if ($matchingNetwork.StaticIP) { $matchingNetwork.StaticIP } else { $DefaultStaticIP }
    $gateway = if ($matchingNetwork.Gateway) { $matchingNetwork.Gateway } else { $DefaultGateway }
    $primaryDNS = if ($matchingNetwork.PrimaryDNS) { $matchingNetwork.PrimaryDNS } else { $DefaultPrimaryDNS }
    $secondaryDNS = if ($matchingNetwork.SecondaryDNS) { $matchingNetwork.SecondaryDNS } else { $DefaultSecondaryDNS }
    
    try {
        # Remove any existing IP
        $existingIPs = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($existingIPs) {
            Write-Host "    Removing existing IPs..." -ForegroundColor Gray
            foreach ($ip in $existingIPs) {
                Remove-NetIPAddress -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
            }
            Start-Sleep -Milliseconds 300
        }
        
        # Remove existing routes
        $existingRoutes = Get-NetRoute -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($existingRoutes) {
            foreach ($route in $existingRoutes) {
                if ($route.DestinationPrefix -ne "255.255.255.255/32") {
                    Remove-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix $route.DestinationPrefix -Confirm:$false -ErrorAction SilentlyContinue
                }
            }
            Start-Sleep -Milliseconds 300
        }
        
        # Convert subnet to prefix
        $ip = [System.Net.IPAddress]$subnetMask
        $binary = [System.Convert]::ToString($ip.Address, 2).PadLeft(32, '0')
        $prefix = $binary.IndexOf('0')
        if ($prefix -eq -1) { $prefix = 32 }
        
        Write-Host "    Setting IP: $staticIP/$prefix" -ForegroundColor Gray
        New-NetIPAddress -InterfaceIndex $interfaceIndex `
            -IPAddress $staticIP `
            -PrefixLength $prefix `
            -DefaultGateway $gateway `
            -ErrorAction Stop | Out-Null
        
        Start-Sleep -Milliseconds 500
        
        Write-Host "    Setting DNS: $primaryDNS, $secondaryDNS" -ForegroundColor Gray
        Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex `
            -ServerAddresses ($primaryDNS, $secondaryDNS) `
            -ErrorAction Stop
        
        Write-Host ""
        Write-Host "[OK] Configuration complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Network: $NetworkName" -ForegroundColor White
        Write-Host "IP:      $staticIP" -ForegroundColor White
        Write-Host "Gateway: $gateway" -ForegroundColor White
        Write-Host "DNS:     $primaryDNS, $secondaryDNS" -ForegroundColor White
        Write-Host ""
        Write-Host "[IMPORTANT] NO DHCP requests were sent!" -ForegroundColor Green
    }
    catch {
        Write-Host "    [ERROR] $_" -ForegroundColor Red
    }
}
else {
    Write-Host "    [!] $NetworkName not found in configuration" -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
