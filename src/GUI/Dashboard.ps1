# ============================================================================
# Network Automation Dashboard
# A GUI to manage Ethernet and WiFi automation scripts.
# ============================================================================

# 1. Self-Elevation Logic
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# 2. Load Assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 3. Define XAML UI
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Network Automation Manager" Height="450" Width="750"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#1E1E1E" Foreground="White">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#333333"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#555555"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#00CED1"/>
            <Setter Property="BorderBrush" Value="#444444"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="Bold"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#DDDDDD"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,10">
            <TextBlock Text="Network Automation Manager" FontSize="24" FontWeight="Bold" Foreground="#00CED1"/>
        </StackPanel>
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <GroupBox Header="Ethernet Automation" Name="gbEthernet" Grid.Column="0" Margin="5">
                <StackPanel Margin="10">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Status: " FontWeight="Bold"/>
                        <TextBlock Name="txtEthernetStatus" Text="CHECKING..." Foreground="Yellow" FontWeight="Bold"/>
                    </StackPanel>
                    
                    <Button Name="btnInstallEthernet" Content="Install Automation"/>
                    <Button Name="btnUninstallEthernet" Content="Uninstall Automation"/>
                    
                    <!-- Ethernet Override -->
                    <Grid Margin="0,10,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Name="pnlEthApply" Orientation="Horizontal" Grid.Column="0" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <TextBlock Text="Override for " FontSize="12"/>
                            <TextBox Name="txtEthDuration" Text="1" Width="30" Height="22" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
                            <TextBlock Text=" Days" FontSize="12"/>
                        </StackPanel>
                        <Button Name="btnEthApplyOverride" Content="Apply" Grid.Column="1" Width="60" Height="26" FontSize="12" Padding="0"/>
                        <Button Name="btnEthClearOverride" Content="CLEAR OVERRIDE" Grid.ColumnSpan="2" Height="26" Background="#8B0000" Visibility="Collapsed" FontSize="12" Padding="0"/>
                    </Grid>
                    <TextBlock Name="txtEthOverrideStatus" Text="" Foreground="Gray" FontSize="10" Margin="0,5,0,0" HorizontalAlignment="Right"/>
                </StackPanel>
            </GroupBox>

            <GroupBox Header="WiFi Automation" Name="gbWiFi" Grid.Column="1" Margin="5">
                <StackPanel Margin="10">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Status: " FontWeight="Bold"/>
                        <TextBlock Name="txtWiFiStatus" Text="CHECKING..." Foreground="Yellow" FontWeight="Bold"/>
                    </StackPanel>
                    
                    <Button Name="btnInstallWiFi" Content="Install Automation"/>
                    <Button Name="btnUninstallWiFi" Content="Uninstall Automation"/>
                    
                    <!-- WiFi Override -->
                    <Grid Margin="0,10,0,0">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Name="pnlWiFiApply" Orientation="Horizontal" Grid.Column="0" HorizontalAlignment="Left" VerticalAlignment="Center">
                            <TextBlock Text="Override for " FontSize="12"/>
                            <TextBox Name="txtWiFiDuration" Text="1" Width="30" Height="22" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
                            <TextBlock Text=" Days" FontSize="12"/>
                        </StackPanel>
                        <Button Name="btnWiFiApplyOverride" Content="Apply" Grid.Column="1" Width="60" Height="26" FontSize="12" Padding="0"/>
                        <Button Name="btnWiFiClearOverride" Content="CLEAR OVERRIDE" Grid.ColumnSpan="2" Height="26" Background="#8B0000" Visibility="Collapsed" FontSize="12" Padding="0"/>
                    </Grid>
                    <TextBlock Name="txtWiFiOverrideStatus" Text="" Foreground="Gray" FontSize="10" Margin="0,5,0,0" HorizontalAlignment="Right"/>
                </StackPanel>
            </GroupBox>
        </Grid>

        <GroupBox Header="Device Information" Grid.Row="2" Margin="5">
            <Grid Margin="10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                
                <TextBlock Text="Device Name:" Grid.Column="0" FontWeight="Bold" Margin="0,0,5,0"/>
                <TextBlock Name="txtDeviceName" Text="Loading..." Grid.Column="1" Margin="0,0,20,0"/>
                
                <TextBlock Text="Ethernet IP:" Grid.Column="2" FontWeight="Bold" Margin="0,0,5,0"/>
                <TextBlock Name="txtEthernetIP" Text="Loading..." Grid.Column="3" Margin="0,0,20,0" Foreground="#00FF00"/>
                
                <TextBlock Text="WiFi IP:" Grid.Column="4" FontWeight="Bold" Margin="0,0,5,0"/>
                <TextBlock Name="txtWiFiIP" Text="Loading..." Grid.Column="5" Margin="0,0,0,0" Foreground="#00FF00"/>
            </Grid>
        </GroupBox>

        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0">
            <TextBlock Text="v0.0.1 (Alpha) - Zero DHCP Strategy | " Foreground="#555555" FontSize="10"/>
            <TextBlock Name="txtTrayHint" Text="Minimize to move to system tray" Foreground="#555555" FontSize="10"/>
        </StackPanel>
    </Grid>
</Window>
"@

# 4. Parse XAML
$Reader = (New-Object System.Xml.XmlNodeReader $Xaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# 5. Find Controls
$txtEthernetStatus = $Window.FindName("txtEthernetStatus")
$btnInstallEthernet = $Window.FindName("btnInstallEthernet")
$btnUninstallEthernet = $Window.FindName("btnUninstallEthernet")
$txtWiFiStatus = $Window.FindName("txtWiFiStatus")
$btnInstallWiFi = $Window.FindName("btnInstallWiFi")
$btnUninstallWiFi = $Window.FindName("btnUninstallWiFi")
$pnlEthApply = $Window.FindName("pnlEthApply")
$txtEthDuration = $Window.FindName("txtEthDuration")
$btnEthApplyOverride = $Window.FindName("btnEthApplyOverride")
$btnEthClearOverride = $Window.FindName("btnEthClearOverride")
$txtEthOverrideStatus = $Window.FindName("txtEthOverrideStatus")

$pnlWiFiApply = $Window.FindName("pnlWiFiApply")
$txtWiFiDuration = $Window.FindName("txtWiFiDuration")
$btnWiFiApplyOverride = $Window.FindName("btnWiFiApplyOverride")
$btnWiFiClearOverride = $Window.FindName("btnWiFiClearOverride")
$txtWiFiOverrideStatus = $Window.FindName("txtWiFiOverrideStatus")
$txtDeviceName = $Window.FindName("txtDeviceName")
$txtEthernetIP = $Window.FindName("txtEthernetIP")
$txtWiFiIP = $Window.FindName("txtWiFiIP")

# 6. Create System Tray Icon
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = "Network Automation Manager"
$script:NotifyIcon.Visible = $false
try { $script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Information }
catch { $script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application }

$TrayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$TrayMenuOpen = $TrayMenu.Items.Add("Open Dashboard")
$TrayMenuExit = $TrayMenu.Items.Add("Exit")
$script:NotifyIcon.ContextMenuStrip = $TrayMenu

$TrayMenuOpen.Add_Click({
        $Window.Show()
        $Window.WindowState = 'Normal'
        $Window.Activate()
        $script:NotifyIcon.Visible = $false
    })

$TrayMenuExit.Add_Click({
        $script:NotifyIcon.Visible = $false
        $script:NotifyIcon.Dispose()
        $Window.Close()
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
    })

$script:NotifyIcon.Add_DoubleClick({
        $Window.Show()
        $Window.WindowState = 'Normal'
        $Window.Activate()
        $script:NotifyIcon.Visible = $false
    })

# 7. Helper Functions
$script:CachedOverrideState = $null

function Refresh-OverrideState {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $SrcDir = Split-Path -Parent $ScriptDir
    $StateFile = Join-Path $SrcDir "DhcpOverride.state.json"
    
    if (Test-Path $StateFile) {
        try {
            $script:CachedOverrideState = Get-Content $StateFile -Raw | ConvertFrom-Json
        }
        catch { $script:CachedOverrideState = $null }
    }
    else {
        $script:CachedOverrideState = $null
    }
}

function Update-EthernetUI {
    $State = $script:CachedOverrideState
    $Now = Get-Date
    $IsActive = $false
    $ExpiryText = ""

    if ($State -and $State.Ethernet) {
        try {
            $Expiry = [DateTime]$State.Ethernet
            if ($Expiry -gt $Now) {
                $IsActive = $true
                $TimeLeft = $Expiry - $Now
                if ($TimeLeft.TotalDays -ge 1) {
                    $ExpiryText = "Expires in $([math]::Round($TimeLeft.TotalDays, 1)) days"
                }
                else {
                    $ExpiryText = "Expires in $([math]::Round($TimeLeft.TotalHours, 1)) hours"
                }
            }
        }
        catch {}
    }

    if ($IsActive) {
        $pnlEthApply.Visibility = "Collapsed"
        $btnEthApplyOverride.Visibility = "Collapsed"
        $btnEthClearOverride.Visibility = "Visible"
        $txtEthOverrideStatus.Text = $ExpiryText
        $txtEthOverrideStatus.Foreground = "LightGreen"
    }
    else {
        $pnlEthApply.Visibility = "Visible"
        $btnEthApplyOverride.Visibility = "Visible"
        $btnEthClearOverride.Visibility = "Collapsed"
        if ($txtEthOverrideStatus.Text -notlike "Applying*" -and $txtEthOverrideStatus.Text -notlike "Clearing*") {
            $txtEthOverrideStatus.Text = ""
        }
    }
}

function Update-WiFiUI {
    $State = $script:CachedOverrideState
    $Now = Get-Date
    $IsActive = $false
    $ExpiryText = ""

    if ($State -and $State.'Wi-Fi') {
        try {
            $Expiry = [DateTime]$State.'Wi-Fi'
            if ($Expiry -gt $Now) {
                $IsActive = $true
                $TimeLeft = $Expiry - $Now
                if ($TimeLeft.TotalDays -ge 1) {
                    $ExpiryText = "Expires in $([math]::Round($TimeLeft.TotalDays, 1)) days"
                }
                else {
                    $ExpiryText = "Expires in $([math]::Round($TimeLeft.TotalHours, 1)) hours"
                }
            }
        }
        catch {}
    }

    if ($IsActive) {
        $pnlWiFiApply.Visibility = "Collapsed"
        $btnWiFiApplyOverride.Visibility = "Collapsed"
        $btnWiFiClearOverride.Visibility = "Visible"
        $txtWiFiOverrideStatus.Text = $ExpiryText
        $txtWiFiOverrideStatus.Foreground = "LightGreen"
    }
    else {
        $pnlWiFiApply.Visibility = "Visible"
        $btnWiFiApplyOverride.Visibility = "Visible"
        $btnWiFiClearOverride.Visibility = "Collapsed"
        if ($txtWiFiOverrideStatus.Text -notlike "Applying*" -and $txtWiFiOverrideStatus.Text -notlike "Clearing*") {
            $txtWiFiOverrideStatus.Text = ""
        }
    }
}

function Get-DeviceConfig {
    try {
        $ScriptDir = Split-Path -Parent $PSCommandPath
        $SrcDir = Split-Path -Parent $ScriptDir
        
        $txtDeviceName.Text = $env:COMPUTERNAME
        $txtDeviceName.Foreground = "White"
        
        # WiFi Config
        $WiFiConfigPath = Join-Path $SrcDir "WiFi\NetworkConfig.ps1"
        if (Test-Path $WiFiConfigPath) {
            try {
                $Content = Get-Content $WiFiConfigPath -Raw -ErrorAction Stop
                if ($Content -match '\$DefaultStaticIP\s*=\s*"([^"]+)"') {
                    $txtWiFiIP.Text = $matches[1]
                    $txtWiFiIP.Foreground = "#00FF00"
                }
                else {
                    $txtWiFiIP.Text = "Not Configured"
                    $txtWiFiIP.Foreground = "Gray"
                }
            }
            catch {
                $txtWiFiIP.Text = "Read Error: $_"
                $txtWiFiIP.Foreground = "Red"
            }
        }
        else {
            $txtWiFiIP.Text = "Config Not Found"
            $txtWiFiIP.Foreground = "Red"
        }
        
        # Ethernet Config
        $EthernetConfigPath = Join-Path $SrcDir "Ethernet\EthernetConfig.ps1"
        if (Test-Path $EthernetConfigPath) {
            try {
                $EthContent = Get-Content $EthernetConfigPath -Raw -ErrorAction Stop
                $ComputerName = $env:COMPUTERNAME
                if ($EthContent -match "`"$ComputerName`"\s*=\s*@\{[^}]*IPAddress\s*=\s*`"([^`"]+)`"") {
                    $txtEthernetIP.Text = $matches[1]
                    $txtEthernetIP.Foreground = "#00FF00"
                }
                else {
                    $txtEthernetIP.Text = "No Config for $ComputerName"
                    $txtEthernetIP.Foreground = "Yellow"
                }
            }
            catch {
                $txtEthernetIP.Text = "Read Error: $_"
                $txtEthernetIP.Foreground = "Red"
            }
        }
        else {
            $txtEthernetIP.Text = "Config Not Found"
            $txtEthernetIP.Foreground = "Red"
        }
        
        Refresh-OverrideState
        Update-EthernetUI
        Update-WiFiUI
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Get-DeviceConfig Error: $_", "Config Error")
    }
}

function Update-Status {
    if (Get-ScheduledTask -TaskName "Ethernet-AutoConfig" -ErrorAction SilentlyContinue) {
        $txtEthernetStatus.Text = "INSTALLED"
        $txtEthernetStatus.Foreground = "LightGreen"
        $btnInstallEthernet.IsEnabled = $false
        $btnUninstallEthernet.IsEnabled = $true
    }
    else {
        $txtEthernetStatus.Text = "NOT INSTALLED"
        $txtEthernetStatus.Foreground = "Red"
        $btnInstallEthernet.IsEnabled = $true
        $btnUninstallEthernet.IsEnabled = $false
    }
    if (Get-ScheduledTask -TaskName "WiFi-AutoConfig-Connect" -ErrorAction SilentlyContinue) {
        $txtWiFiStatus.Text = "INSTALLED"
        $txtWiFiStatus.Foreground = "LightGreen"
        $btnInstallWiFi.IsEnabled = $false
        $btnUninstallWiFi.IsEnabled = $true
    }
    else {
        $txtWiFiStatus.Text = "NOT INSTALLED"
        $txtWiFiStatus.Foreground = "Red"
        $btnInstallWiFi.IsEnabled = $true
        $btnUninstallWiFi.IsEnabled = $false
    }
}

function Run-Script-Async ($ScriptPath, $ScriptArgs = "", $StatusLabelName = "") {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $SrcRoot = Split-Path -Parent $ScriptDir
    $FullScriptPath = Join-Path $SrcRoot $ScriptPath
    
    if (-not (Test-Path $FullScriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script not found: $FullScriptPath", "Error")
        return
    }
    
    if ($StatusLabelName) {
        $Label = $Window.FindName($StatusLabelName)
        $Label.Text = "RUNNING..."
        $Label.Foreground = "Yellow"
    }
    
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("FullScriptPath", $FullScriptPath)
    $Runspace.SessionStateProxy.SetVariable("ScriptArgs", $ScriptArgs)
    $Runspace.SessionStateProxy.SetVariable("Window", $Window)
    
    $PowerShell = [powershell]::Create()
    $PowerShell.Runspace = $Runspace
    
    [void]$PowerShell.AddScript({
            param($FullScriptPath, $ScriptArgs, $Window)
            try {
                if ($ScriptArgs -and ($ScriptArgs -is [string]) -and ($ScriptArgs.Trim())) {
                    $ArgArray = $ScriptArgs.Trim().Split(" ", [StringSplitOptions]::RemoveEmptyEntries)
                    & $FullScriptPath @ArgArray 2>&1 | Out-Null
                }
                else {
                    & $FullScriptPath 2>&1 | Out-Null
                }
            }
            catch { }
        
            $Window.Dispatcher.Invoke([action] {
                    if (Get-ScheduledTask -TaskName "Ethernet-AutoConfig" -ErrorAction SilentlyContinue) {
                        ($Window.FindName("txtEthernetStatus")).Text = "INSTALLED"
                        ($Window.FindName("txtEthernetStatus")).Foreground = "LightGreen"
                        ($Window.FindName("btnInstallEthernet")).IsEnabled = $false
                        ($Window.FindName("btnUninstallEthernet")).IsEnabled = $true
                    }
                    else {
                        ($Window.FindName("txtEthernetStatus")).Text = "NOT INSTALLED"
                        ($Window.FindName("txtEthernetStatus")).Foreground = "Red"
                        ($Window.FindName("btnInstallEthernet")).IsEnabled = $true
                        ($Window.FindName("btnUninstallEthernet")).IsEnabled = $false
                    }
                    if (Get-ScheduledTask -TaskName "WiFi-AutoConfig-Connect" -ErrorAction SilentlyContinue) {
                        ($Window.FindName("txtWiFiStatus")).Text = "INSTALLED"
                        ($Window.FindName("txtWiFiStatus")).Foreground = "LightGreen"
                        ($Window.FindName("btnInstallWiFi")).IsEnabled = $false
                        ($Window.FindName("btnUninstallWiFi")).IsEnabled = $true
                    }
                    else {
                        ($Window.FindName("txtWiFiStatus")).Text = "NOT INSTALLED"
                        ($Window.FindName("txtWiFiStatus")).Foreground = "Red"
                        ($Window.FindName("btnInstallWiFi")).IsEnabled = $true
                        ($Window.FindName("btnUninstallWiFi")).IsEnabled = $false
                    }
                })
        }).AddArgument($FullScriptPath).AddArgument($ScriptArgs).AddArgument($Window)
    
    [void]$PowerShell.BeginInvoke()
}

function Run-Script-External ($ScriptPath, $ScriptArgs = "") {
    $ScriptDir = Split-Path -Parent $PSCommandPath
    $SrcRoot = Split-Path -Parent $ScriptDir
    $FullScriptPath = Join-Path $SrcRoot $ScriptPath
    
    if (-not (Test-Path $FullScriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script not found: $FullScriptPath", "Error")
        return
    }
    
    # Use Start-Process to run in a separate process (inherits elevation)
    # This avoids Runspace issues with modules/permissions
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$FullScriptPath`" $ScriptArgs" -WindowStyle Hidden
}

# 8. Event Handlers
$btnInstallEthernet.Add_Click({ Run-Script-Async "Ethernet\Setup-EthernetEventTrigger.ps1" "" "txtEthernetStatus" })
$btnUninstallEthernet.Add_Click({ Run-Script-Async "Ethernet\Uninstall-EthernetEventTrigger.ps1" "" "txtEthernetStatus" })
$btnInstallWiFi.Add_Click({ Run-Script-Async "WiFi\Setup-NetworkEventTrigger.ps1" "" "txtWiFiStatus" })
$btnUninstallWiFi.Add_Click({ Run-Script-Async "WiFi\Uninstall-NetworkEventTrigger.ps1" "" "txtWiFiStatus" })

$btnEthApplyOverride.Add_Click({
        if (Get-ScheduledTask -TaskName "Ethernet-AutoConfig" -ErrorAction SilentlyContinue) {
            $Duration = 1
            try { $Duration = [int]$txtEthDuration.Text; if ($Duration -lt 1) { $Duration = 1 } } catch { $Duration = 1; $txtEthDuration.Text = "1" }
            Run-Script-External "Set-DhcpOverride.ps1" "-Interface Ethernet -Days $Duration"
            $txtEthOverrideStatus.Text = "Applying override..."
            $txtEthOverrideStatus.Foreground = "Yellow"
        }
        else {
            $txtEthOverrideStatus.Text = "Install automation first!"
            $txtEthOverrideStatus.Foreground = "Red"
        }
    })

$btnEthClearOverride.Add_Click({
        Run-Script-External "Set-DhcpOverride.ps1" "-Interface Ethernet -Clear"
        $txtEthOverrideStatus.Text = "Clearing override..."
    })

$btnWiFiApplyOverride.Add_Click({
        if (Get-ScheduledTask -TaskName "WiFi-AutoConfig-Connect" -ErrorAction SilentlyContinue) {
            $Duration = 1
            try { $Duration = [int]$txtWiFiDuration.Text; if ($Duration -lt 1) { $Duration = 1 } } catch { $Duration = 1; $txtWiFiDuration.Text = "1" }
            Run-Script-External "Set-DhcpOverride.ps1" "-Interface Wi-Fi -Days $Duration"
            $txtWiFiOverrideStatus.Text = "Applying override..."
            $txtWiFiOverrideStatus.Foreground = "Yellow"
        }
        else {
            $txtWiFiOverrideStatus.Text = "Install automation first!"
            $txtWiFiOverrideStatus.Foreground = "Red"
        }
    })

$btnWiFiClearOverride.Add_Click({
        Run-Script-External "Set-DhcpOverride.ps1" "-Interface Wi-Fi -Clear"
        $txtWiFiOverrideStatus.Text = "Clearing override..."
    })

# 9. Window Events
$Window.Add_StateChanged({
        if ($Window.WindowState -eq 'Minimized') {
            try {
                $script:NotifyIcon.Visible = $true
                $Window.Hide()
                $script:NotifyIcon.ShowBalloonTip(2000, "Network Automation Manager", "Running in background.", [System.Windows.Forms.ToolTipIcon]::Info)
            }
            catch { }
        }
    })

$Window.Add_Closing({
        $script:NotifyIcon.Visible = $false
        $script:NotifyIcon.Dispose()
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
    })

$Window.Add_Activated({
        Update-Status
        Refresh-OverrideState
        Update-EthernetUI
        Update-WiFiUI
    })

# 10. Initialize and Show
Update-Status
Get-DeviceConfig
$Window.Show()
[System.Windows.Threading.Dispatcher]::Run()
