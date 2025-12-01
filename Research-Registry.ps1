# Research Script - Windows 11 Per-Network IP Configuration Registry Structure

Write-Host "=== Researching Windows Network Profile Registry Structure ===" -ForegroundColor Cyan

# 1. Get Current WiFi Connection Info
$ssid = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1).ToString().Split(":")[1].Trim()
Write-Host "`nCurrent SSID: $ssid" -ForegroundColor Yellow

# 2. Get Network Adapter GUID
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }
$adapterGuid = $adapter.InterfaceGuid
Write-Host "Adapter GUID: $adapterGuid" -ForegroundColor Gray

# 3. Explore NetworkList Profiles (Windows stores network profiles here)
Write-Host "`n--- Network List Profiles ---" -ForegroundColor Cyan
$profilesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"
Get-ChildItem $profilesPath | ForEach-Object {
    $profile = Get-ItemProperty $_.PSPath
    if ($profile.ProfileName -eq $ssid) {
        Write-Host "Found Profile for $ssid" -ForegroundColor Green
        Write-Host "  GUID: $($_.PSChildName)" -ForegroundColor Gray
        Write-Host "  Registry Path: $($_.PSPath)" -ForegroundColor Gray
        $profile | Format-List
    }
}

# 4. Explore WlanSvc Interface Profiles
Write-Host "`n--- WLAN Service Interface Profiles ---" -ForegroundColor Cyan
$wlanPath = "HKLM:\SOFTWARE\Microsoft\WlanSvc\Interfaces"
if (Test-Path $wlanPath) {
    Get-ChildItem $wlanPath | ForEach-Object {
        $interfaceGuid = $_.PSChildName
        Write-Host "Interface: $interfaceGuid" -ForegroundColor Gray
        $profilesSubPath = Join-Path $_.PSPath "Profiles"
        if (Test-Path $profilesSubPath) {
            Get-ChildItem $profilesSubPath | ForEach-Object {
                $profileData = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                Write-Host "  Profile GUID: $($_.PSChildName)" -ForegroundColor Gray
                if ($profileData.ProfileName) {
                    Write-Host "    Name: $($profileData.ProfileName)" -ForegroundColor White
                }
            }
        }
    }
}

# 5. Check TCPIP Parameters Interface
Write-Host "`n--- TCP/IP Interface Parameters ---" -ForegroundColor Cyan
$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$adapterGuid"
if (Test-Path $tcpipPath) {
    $tcpipConfig = Get-ItemProperty $tcpipPath
    Write-Host "Current Adapter Configuration:" -ForegroundColor Yellow
    $tcpipConfig | Format-List EnableDHCP, DhcpIPAddress, IPAddress, SubnetMask, DefaultGateway, NameServer
}

# 6. Search for Windows 11 Per-Network Settings
Write-Host "`n--- Searching for Per-Network IP Settings ---" -ForegroundColor Cyan
Write-Host "Looking in user profile settings..." -ForegroundColor Gray

# Windows 11 might store this in CurrentUser for per-network settings
$userNetworkPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Network"
if (Test-Path $userNetworkPath) {
    Write-Host "Found user network settings path" -ForegroundColor Green
    Get-ChildItem $userNetworkPath -Recurse | ForEach-Object {
        Write-Host "  $($_.PSPath)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Research Complete ===" -ForegroundColor Cyan
Write-Host "Please review the output above to identify where Windows stores per-network IP configurations." -ForegroundColor Yellow
