Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Text = "Debug Tray Icon"
$NotifyIcon.Visible = $true

# Attempt 1: Standard Application Icon
try {
    Write-Host "Attempt 1: Loading SystemIcons.Application..."
    $NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    $NotifyIcon.ShowBalloonTip(1000, "Debug", "Attempt 1: Application Icon", [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 5
}
catch {
    Write-Host "Error: $_"
}

# Attempt 2: Shield Icon
try {
    Write-Host "Attempt 2: Loading SystemIcons.Shield..."
    $NotifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
    $NotifyIcon.ShowBalloonTip(1000, "Debug", "Attempt 2: Shield Icon", [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 5
}
catch {
    Write-Host "Error: $_"
}

# Attempt 3: PowerShell Executable Icon
try {
    Write-Host "Attempt 3: Extracting PowerShell Icon..."
    $PSExe = (Get-Process -Id $PID).Path
    $NotifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSExe)
    $NotifyIcon.ShowBalloonTip(1000, "Debug", "Attempt 3: PowerShell Icon", [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 5
}
catch {
    Write-Host "Error: $_"
}

$NotifyIcon.Dispose()
Write-Host "Test Complete."
