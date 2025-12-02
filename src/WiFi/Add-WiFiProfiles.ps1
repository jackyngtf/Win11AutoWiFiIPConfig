# ============================================================================
# Add WiFi Profiles Only - No IP Configuration
# This script adds WiFi network profiles to Windows
# ============================================================================

# Load configuration
$scriptPath = $PSScriptRoot
$configFile = Join-Path $scriptPath "NetworkConfig.ps1"

if (-not (Test-Path $configFile)) {
    Write-Host "[ERROR] Configuration file not found: $configFile" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

. $configFile

# Function to create WiFi profile XML
function New-WiFiProfileXML {
    param (
        [string]$SSID,
        [string]$Password,
        [string]$AuthType,
        [string]$Encryption,
        [string]$Name,
        [bool]$AutoConnect = $false
    )

    $SSIDHex = [System.Text.Encoding]::UTF8.GetBytes($SSID) | ForEach-Object { "{0:X2}" -f $_ }
    $SSIDHexString = $SSIDHex -join ''

    $connectionMode = if ($AutoConnect) { "auto" } else { "manual" }

    $xmlContent = @(
        '<?xml version="1.0"?>'
        '<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">'
        "    <name>$Name</name>"
        '    <SSIDConfig>'
        '        <SSID>'
        "            <hex>$SSIDHexString</hex>"
        "            <name>$SSID</name>"
        '        </SSID>'
        '        <nonBroadcast>false</nonBroadcast>'
        '    </SSIDConfig>'
        '    <connectionType>ESS</connectionType>'
        "    <connectionMode>$connectionMode</connectionMode>"
        '    <MSM>'
        '        <security>'
        '            <authEncryption>'
        "                <authentication>$AuthType</authentication>"
        "                <encryption>$Encryption</encryption>"
        '                <useOneX>false</useOneX>'
        '            </authEncryption>'
        '            <sharedKey>'
        '                <keyType>passPhrase</keyType>'
        '                <protected>false</protected>'
        "                <keyMaterial>$Password</keyMaterial>"
        '            </sharedKey>'
        '        </security>'
        '    </MSM>'
        '</WLANProfile>'
    )
    
    return $xmlContent -join "`r`n"
}

# Function to check if profile exists
function Test-WiFiProfileExists {
    param ([string]$ProfileName)
    try {
        $profiles = netsh wlan show profiles | Out-String
        return $profiles -like "*$ProfileName*"
    }
    catch {
        return $false
    }
}

Write-Host "+----------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "|   Add WiFi Profiles                                          |" -ForegroundColor Cyan
Write-Host "+----------------------------------------------------------------+" -ForegroundColor Cyan

# Check admin privileges
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n[*] Adding WiFi Profiles..." -ForegroundColor Cyan
Write-Host "---------------------------------------------" -ForegroundColor Yellow

foreach ($network in $CompanyWiFiNetworks) {
    Write-Host "`n[*] Processing: $($network.Name)" -ForegroundColor Cyan

    if (Test-WiFiProfileExists -ProfileName $network.Name) {
        Write-Host "    -- Profile already exists, skipping..." -ForegroundColor Yellow
        continue
    }

    try {
        if ($network.Password) { $password = $network.Password } else { $password = $DefaultPassword }
        if ($network.AuthType) { $authType = $network.AuthType } else { $authType = $DefaultAuthType }
        if ($network.Encryption) { $encryption = $network.Encryption } else { $encryption = $DefaultEncryption }

        # Manual connection only - prevents signal jumping
        $autoConnect = $false

        $profileXML = New-WiFiProfileXML -SSID $network.SSID `
            -Password $password `
            -AuthType $authType `
            -Encryption $encryption `
            -Name $network.Name `
            -AutoConnect $autoConnect

        $tempPath = "$env:TEMP\wifi_$($network.Name)_$([System.Guid]::NewGuid()).xml"
        $profileXML | Out-File -FilePath $tempPath -Encoding UTF8 -Force

        Write-Host "    +- Adding profile to Windows..." -ForegroundColor Gray
        netsh wlan add profile filename="$tempPath" user=current | Out-Null

        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue

        if ($autoConnect) {
            Write-Host "    +- Auto-connect: ENABLED" -ForegroundColor Green
        }
        else {
            Write-Host "    +- Auto-connect: Disabled (manual only)" -ForegroundColor Gray
        }

        Write-Host "    -- Profile added successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "    -- Error adding profile: $_" -ForegroundColor Red
    }
}

Write-Host "`n+----------------------------------------------------------------+" -ForegroundColor Green
Write-Host "|    WiFi Profiles Added                                       |" -ForegroundColor Green
Write-Host "+----------------------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "Note: All networks require manual connection (auto-connect disabled)." -ForegroundColor Cyan
Write-Host "This prevents signal-jumping issues and script spam." -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"
