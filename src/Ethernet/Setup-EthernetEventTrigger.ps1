# ============================================================================
# Setup Ethernet Event Trigger
# Registers a Scheduled Task to run EthernetEventHandler.ps1 on Network Connect
# ============================================================================

$TaskName = "Ethernet-AutoConfig"
$ScriptPath = "$PSScriptRoot\EthernetEventHandler.ps1"

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
  Write-Error "Could not find EthernetEventHandler.ps1 at $ScriptPath"
  exit
}

# 1. Unregister existing task if it exists
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
  Write-Host "Removing existing task: $TaskName" -ForegroundColor Yellow
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Write-Host "`n[ZERO-DHCP INITIALIZATION]" -ForegroundColor Cyan
Write-Host "Disabling DHCP on ALL Ethernet adapters to prevent auto-DHCP..." -ForegroundColor Cyan

# Get all Ethernet adapters (even if no cable connected)
$AllEthernetAdapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "802.3" }

foreach ($Adapter in $AllEthernetAdapters) {
  $DhcpStatus = (Get-NetIPInterface -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
    
  if ($DhcpStatus -eq "Enabled") {
    try {
      Set-NetIPInterface -InterfaceAlias $Adapter.Name -Dhcp Disabled -ErrorAction Stop
      Write-Host "  [OK] DHCP disabled on: $($Adapter.Name)" -ForegroundColor Green
    }
    catch {
      Write-Host "  [WARNING] Failed to disable DHCP on: $($Adapter.Name)" -ForegroundColor Yellow
    }
  }
  else {
    Write-Host "  [OK] DHCP already disabled on: $($Adapter.Name)" -ForegroundColor Gray
  }
}

Write-Host "Zero-DHCP initialization complete.`n" -ForegroundColor Green


# 2. Define the Event Trigger XML
$EventTriggerXml = @"
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000 or EventID=10001)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
"@

# 3. Create Action
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# 4. Create Principal (Run as System/Admin)
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# 5. Create Settings
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

# 6. Register Task with a Dummy Trigger first
Write-Host "Registering initial task..." -ForegroundColor Cyan
$DummyTrigger = New-ScheduledTaskTrigger -AtLogOn
$Task = Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $Principal -Settings $Settings -Trigger $DummyTrigger -Force

# 7. Modify the Task XML to use the Event Trigger
Write-Host "Applying Event Trigger..." -ForegroundColor Cyan

# Get the XML of the registered task
$TaskXml = $Task | Export-ScheduledTask

# Replace the <LogonTrigger> block with our <EventTrigger>
# We use regex to be robust
$ModifiedXml = $TaskXml -replace '(?s)<LogonTrigger>.*?</LogonTrigger>', $EventTriggerXml

# Re-register the task with the modified XML
Register-ScheduledTask -TaskName $TaskName -Xml $ModifiedXml -User "SYSTEM" -Force | Out-Null

Write-Host "Setup Complete! The task '$TaskName' is now active." -ForegroundColor Green
Write-Host "It will run whenever a network connects."

# Run the handler immediately to apply settings now
Write-Host "Running initial configuration check..." -ForegroundColor Cyan
& PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "$ScriptPath"
Write-Host "Initial check complete. Check EthernetEventHandler.log for details." -ForegroundColor Green
