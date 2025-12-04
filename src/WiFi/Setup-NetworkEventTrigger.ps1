# ============================================================================
# Setup Event-Triggered Network Configuration
# Triggers INSTANTLY when WiFi connects/disconnects
# ============================================================================

Write-Host "=== Event-Triggered Network Configuration Setup ===" -ForegroundColor Cyan
Write-Host "This creates tasks that trigger on WiFi connection events" -ForegroundColor Gray
Write-Host ""

# Check admin
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Must run as Administrator!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Define file paths dynamically
$scriptDir = $PSScriptRoot
$handlerScript = Join-Path $scriptDir "NetworkEventHandler.ps1"
$wifiProfileScript = Join-Path $scriptDir "Add-WiFiProfiles.ps1"
$initAdapterScript = Join-Path $scriptDir "Initialize-WiFiAdapter.ps1"
$configFile = Join-Path $scriptDir "NetworkConfig.ps1"

if (-not (Test-Path $configFile)) {
    Write-Host "[ERROR] NetworkConfig.ps1 not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $handlerScript)) {
    Write-Host "[ERROR] NetworkEventHandler.ps1 not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

. $configFile

# ============================================================================
# ADD WIFI PROFILES
# ============================================================================

Write-Host "[STEP 1] Adding WiFi Profiles" -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Yellow

function New-WiFiProfileXML {
    param (
        [string]$SSID, [string]$Password, [string]$AuthType,
        [string]$Encryption, [string]$Name, [bool]$AutoConnect = $false
    )
    $SSIDHex = [System.Text.Encoding]::UTF8.GetBytes($SSID) | ForEach-Object { "{0:X2}" -f $_ }
    $SSIDHexString = $SSIDHex -join ''
    $connectionMode = if ($AutoConnect) { "auto" } else { "manual" }
    
    $xmlContent = @(
        '<?xml version="1.0"?>'
        '<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">'
        "    <name>$Name</name>"
        '    <SSIDConfig><SSID>'
        "        <hex>$SSIDHexString</hex>"
        "        <name>$SSID</name>"
        '    </SSID><nonBroadcast>false</nonBroadcast></SSIDConfig>'
        '    <connectionType>ESS</connectionType>'
        "    <connectionMode>$connectionMode</connectionMode>"
        '    <MSM><security><authEncryption>'
        "        <authentication>$AuthType</authentication>"
        "        <encryption>$Encryption</encryption>"
        '        <useOneX>false</useOneX>'
        '    </authEncryption><sharedKey>'
        '        <keyType>passPhrase</keyType>'
        '        <protected>false</protected>'
        "        <keyMaterial>$Password</keyMaterial>"
        '    </sharedKey></security></MSM>'
        '</WLANProfile>'
    )
    return $xmlContent -join "`r`n"
}

function Test-WiFiProfileExists {
    param ([string]$ProfileName)
    try { return (netsh wlan show profiles) -like "*$ProfileName*" }
    catch { return $false }
}

$added = 0
foreach ($network in $CompanyWiFiNetworks) {
    if (Test-WiFiProfileExists -ProfileName $network.Name) {
        Write-Host "  [OK] $($network.Name)" -ForegroundColor Gray
        continue
    }
    Write-Host "  [+] Adding: $($network.Name)" -ForegroundColor Cyan
    try {
        $password = if ($network.Password) { $network.Password } else { $DefaultPassword }
        $authType = if ($network.AuthType) { $network.AuthType } else { $DefaultAuthType }
        $encryption = if ($network.Encryption) { $network.Encryption } else { $DefaultEncryption }
        $autoConnect = $false  # Manual connection only - prevents signal jumping
        
        $profileXML = New-WiFiProfileXML -SSID $network.SSID -Password $password `
            -AuthType $authType -Encryption $encryption -Name $network.Name -AutoConnect $autoConnect
        
        $tempPath = "$env:TEMP\wifi_$($network.Name)_$([System.Guid]::NewGuid()).xml"
        $profileXML | Out-File -FilePath $tempPath -Encoding UTF8 -Force
        netsh wlan add profile filename="$tempPath" user=current | Out-Null
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        
        if ($autoConnect) {
            Write-Host "      Auto-connect: ENABLED" -ForegroundColor Green
        }
        $added++
    }
    catch {
        Write-Host "      Error: $_" -ForegroundColor Red
    }
}

if ($added -eq 0) {
    Write-Host "`n  All profiles exist" -ForegroundColor Green
}

# ============================================================================
# INITIALIZE WIFI ADAPTER - DISABLE DHCP BY DEFAULT
# ============================================================================

Write-Host "`n[STEP 2] Initializing WiFi Adapter" -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Yellow

# Get WiFi adapter (including disabled ones)
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" }

if ($wifiAdapter) {
    # Check if adapter is disabled (possibly by Ethernet auto-switch)
    if ($wifiAdapter.Status -eq "Disabled") {
        Write-Host "  [!] WiFi adapter is currently disabled (possibly by Ethernet auto-switch)" -ForegroundColor Yellow
        Write-Host "  [*] Enabling WiFi for setup..." -ForegroundColor Cyan
        Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
        Start-Sleep -Seconds 2
        # Refresh adapter status
        $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" }
    }
    
    $interfaceIndex = $wifiAdapter.ifIndex
    $interfaceName = $wifiAdapter.Name
    
    Write-Host "  Found: $interfaceName" -ForegroundColor Cyan
    Write-Host "  Disabling DHCP by default (prevents DHCP requests)..." -ForegroundColor Yellow
    
    try {
        Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
        Write-Host "  [OK] DHCP disabled on WiFi adapter" -ForegroundColor Green
        Write-Host "       This prevents ANY DHCP requests for company networks!" -ForegroundColor Gray
    }
    catch {
        Write-Host "  [!] Could not disable DHCP: $_" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  [!] WiFi adapter not found" -ForegroundColor Yellow
}

# ============================================================================
# CREATE EVENT-TRIGGERED TASKS
# ============================================================================

# ============================================================================
# CREATE EVENT-TRIGGERED TASKS
# ============================================================================

Write-Host "`n[STEP 3] Creating Event-Triggered Tasks" -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Yellow

# Remove old tasks
$oldTasks = @("AutoConfigureNetworkIP", "WiFi-AutoConfig-OnConnect", "WiFi-AutoConfig-Connect", "WiFi-AutoConfig-Disconnect")
foreach ($taskName in $oldTasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "  Removing old task: $taskName" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}

# Common settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$triggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler

# ----------------------------------------------------------------------------
# TASK 1: CONNECT EVENTS (8001, 10000, Logon)
# ----------------------------------------------------------------------------
$taskNameConnect = "WiFi-AutoConfig-Connect"
$taskDescConnect = "Configures IP when WiFi connects (Retries for SSID)"

Write-Host "  Creating task: $taskNameConnect" -ForegroundColor Cyan

# Action: Pass "-TriggerEvent Connect"
$actionConnect = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$handlerScript`" -TriggerEvent Connect"

# Trigger 1: Event ID 8001 (WiFi connected)
$triggerXml1 = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational">
    <Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational">
      *[System[(EventID=8001)]]
    </Select>
  </Query>
</QueryList>
"@

# Trigger 2: Event ID 10000 (Network profile connected)
$triggerXml2 = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">
      *[System[(EventID=10000)]]
    </Select>
  </Query>
</QueryList>
"@

$trigger1 = New-CimInstance -CimClass $triggerClass -ClientOnly
$trigger1.Enabled = $true
$trigger1.Subscription = $triggerXml1

$trigger2 = New-CimInstance -CimClass $triggerClass -ClientOnly
$trigger2.Enabled = $true
$trigger2.Subscription = $triggerXml2

$trigger3 = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask `
    -TaskName $taskNameConnect `
    -Description $taskDescConnect `
    -Action $actionConnect `
    -Trigger $trigger1, $trigger2, $trigger3 `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

Write-Host "  [OK] Connect Task created!" -ForegroundColor Green

# ----------------------------------------------------------------------------
# TASK 2: DISCONNECT EVENT (8003) - INSTANT EXECUTION (NETSH)
# ----------------------------------------------------------------------------
$taskNameDisconnect = "WiFi-AutoConfig-Disconnect"
$taskDescDisconnect = "Instantly disables DHCP when WiFi disconnects (Netsh)"

Write-Host "  Creating task: $taskNameDisconnect" -ForegroundColor Cyan

# Detect WiFi Adapter Name for Netsh
$wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.Name -like "*Wi-Fi*" }
if (-not $wifiAdapter) {
    $wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq "802.3" -or $_.MediaType -eq "Native 802.11" } | Select-Object -First 1
}

# Trigger: Event ID 8003 (WiFi disconnected)
$triggerXmlDisconnect = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational">
    <Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational">
      *[System[(EventID=8003)]]
    </Select>
  </Query>
</QueryList>
"@

$triggerDisconnect = New-CimInstance -CimClass $triggerClass -ClientOnly
$triggerDisconnect.Enabled = $true
$triggerDisconnect.Subscription = $triggerXmlDisconnect

# Define Netsh Actions for Instant Disconnect
$actionDisconnect1 = New-ScheduledTaskAction -Execute "netsh.exe" -Argument "interface ip set address name=`"$($wifiAdapter.Name)`" source=static addr=$DefaultStaticIP mask=$DefaultSubnetMask gateway=$DefaultGateway"
$actionDisconnect2 = New-ScheduledTaskAction -Execute "netsh.exe" -Argument "interface ip set dns name=`"$($wifiAdapter.Name)`" source=static addr=$DefaultPrimaryDNS"

Register-ScheduledTask `
    -TaskName $taskNameDisconnect `
    -Description $taskDescDisconnect `
    -Action $actionDisconnect1, $actionDisconnect2 `
    -Trigger $triggerDisconnect `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

Write-Host "  [OK] Disconnect Task created (Netsh Mode)!" -ForegroundColor Green
Write-Host "      Triggers:" -ForegroundColor Gray
Write-Host "        - WiFi Event 8003 (INSTANT - Direct Netsh)" -ForegroundColor Gray

# ============================================================================
# TEST NOW
# ============================================================================

Write-Host "`n[STEP 4] Applying Configuration Now" -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Yellow

try {
    & PowerShell.exe -ExecutionPolicy Bypass -File "$handlerScript"
    Write-Host "  [OK] WiFi Configuration applied!" -ForegroundColor Green
}
catch {
    Write-Host "  [!] Error running WiFi handler: $_" -ForegroundColor Yellow
}

# NEW: Trigger Ethernet Handler to re-evaluate Auto-Switch logic
$EthernetHandler = Join-Path (Split-Path -Parent $PSScriptRoot) "Ethernet\EthernetEventHandler.ps1"
if (Test-Path $EthernetHandler) {
    Write-Host "`n[STEP 5] Checking Ethernet State (Auto-Switch)" -ForegroundColor Yellow
    Write-Host "---------------------------------------------" -ForegroundColor Yellow
    Write-Host "  Triggering Ethernet Handler to check for active connection..." -ForegroundColor Cyan
    try {
        & PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$EthernetHandler"
        Write-Host "  [OK] Ethernet check complete." -ForegroundColor Green
    }
    catch {
        Write-Host "  [!] Failed to run Ethernet handler: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "+----------------------------------------------------------------+" -ForegroundColor Green
Write-Host "|    Setup Complete!                                           |" -ForegroundColor Green
Write-Host "+----------------------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "How it works:" -ForegroundColor Cyan
Write-Host "  1. Connect to WiFi -> Task triggers automatically (5s delay)" -ForegroundColor Gray
Write-Host "  2. Is it a company SSID? -> Apply static IP" -ForegroundColor Gray
Write-Host "  3. Is it unknown SSID? -> Enable DHCP" -ForegroundColor Gray
Write-Host "  4. No DHCP requests for company networks" -ForegroundColor Gray
Write-Host ""
Write-Host "Disconnect/reconnect to test!" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to exit"
