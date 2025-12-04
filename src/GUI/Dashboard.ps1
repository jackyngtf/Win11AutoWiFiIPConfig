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
        Title="Network Automation Manager" Height="650" Width="750"
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
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,10">
            <TextBlock Text="Network Automation Manager" FontSize="24" FontWeight="Bold" Foreground="#00CED1"/>
        </StackPanel>

        <!-- Main Content -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Ethernet Section -->
            <GroupBox Header="Ethernet Automation" Grid.Row="0" Grid.Column="0">
                <StackPanel Margin="10">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Status: " FontWeight="Bold"/>
                        <TextBlock Name="txtEthernetStatus" Text="Checking..." Foreground="Gray"/>
                    </StackPanel>
                    <Button Name="btnInstallEthernet" Content="Install Automation"/>
                    <Button Name="btnUninstallEthernet" Content="Uninstall Automation"/>
                </StackPanel>
            </GroupBox>

            <!-- WiFi Section -->
            <GroupBox Header="WiFi Automation" Grid.Row="0" Grid.Column="1">
                <StackPanel Margin="10">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                        <TextBlock Text="Status: " FontWeight="Bold"/>
                        <TextBlock Name="txtWiFiStatus" Text="Checking..." Foreground="Gray"/>
                    </StackPanel>
                    <Button Name="btnInstallWiFi" Content="Install Automation"/>
                    <Button Name="btnUninstallWiFi" Content="Uninstall Automation"/>
                </StackPanel>
            </GroupBox>

            <!-- DHCP Override Section -->
            <GroupBox Header="Temporary DHCP Override" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2">
                <StackPanel Margin="10">
                    <Grid Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <TextBlock Text="Interface:" Grid.Column="0" Margin="0,0,10,0"/>
                        <ComboBox Name="cmbInterface" Grid.Column="1" Margin="0,0,20,0" Height="25">
                            <ComboBoxItem Content="Ethernet"/>
                            <ComboBoxItem Content="Wi-Fi"/>
                            <ComboBoxItem Content="All" IsSelected="True"/>
                        </ComboBox>

                        <TextBlock Text="Duration:" Grid.Column="2" Margin="0,0,10,0"/>
                        <ComboBox Name="cmbDuration" Grid.Column="3" Height="25">
                            <ComboBoxItem Content="1 Day" IsSelected="True"/>
                            <ComboBoxItem Content="3 Days"/>
                            <ComboBoxItem Content="7 Days"/>
                            <ComboBoxItem Content="30 Days"/>
                        </ComboBox>
                    </Grid>
                    
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                        <Button Name="btnApplyOverride" Content="Apply Override" Width="150" Background="#008B8B"/>
                        <Button Name="btnClearOverride" Content="Clear Override" Width="150" Background="#8B0000"/>
                    </StackPanel>
                    <TextBlock Name="txtOverrideStatus" Text="" HorizontalAlignment="Center" Margin="0,10,0,0" Foreground="Yellow"/>
                </StackPanel>
            </GroupBox>
        </Grid>

        <!-- Output Panel -->
        <GroupBox Header="Output Log" Grid.Row="2" Margin="10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBox Name="txtOutput" Grid.Row="0" 
                         Background="#0C0C0C" Foreground="#00FF00" 
                         FontFamily="Consolas" FontSize="12"
                         IsReadOnly="True" TextWrapping="Wrap" 
                         VerticalScrollBarVisibility="Auto"
                         AcceptsReturn="True" Padding="5"/>
                <Button Name="btnClearOutput" Grid.Row="1" Content="Clear Log" 
        $Window.Show()
        $Window.WindowState = 'Normal'
        $Window.Activate()
        $script:NotifyIcon.Visible = $false
    })

# 7. Helper Functions
function Write-Output-Log ($Message) {
    $Window.Dispatcher.Invoke([action] {
            $Timestamp = Get-Date -Format "HH:mm:ss"
            $txtOutput.AppendText("[$Timestamp] $Message`r`n")
            $txtOutput.ScrollToEnd()
        })
}

function Update-Status {
    # Check Ethernet
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

    # Check WiFi
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

# ASYNC Script Execution using Runspaces
function Run-Script-Async ($ScriptPath, $Args = "") {
    $SrcRoot = Split-Path -Parent $PSScriptRoot
    $FullScriptPath = Join-Path $SrcRoot $ScriptPath
    
    if (-not (Test-Path $FullScriptPath)) {
        Write-Output-Log "ERROR: Script not found: $FullScriptPath"
        return
    }
    
    Write-Output-Log "Running: $ScriptPath $Args"
    Write-Output-Log "----------------------------------------"
    
    # Create runspace for async execution
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    
    # Share variables with runspace
    $Runspace.SessionStateProxy.SetVariable("FullScriptPath", $FullScriptPath)
    $Runspace.SessionStateProxy.SetVariable("Args", $Args)
    $Runspace.SessionStateProxy.SetVariable("Window", $Window)
    $Runspace.SessionStateProxy.SetVariable("txtOutput", $txtOutput)
    
    # Create PowerShell command
    $PowerShell = [powershell]::Create()
    $PowerShell.Runspace = $Runspace
    
    # Script to run in background
    [void]$PowerShell.AddScript({
            param($FullScriptPath, $Args, $Window, $txtOutput)
        
            function Write-Log ($Message) {
                $Window.Dispatcher.Invoke([action] {
                        $Timestamp = Get-Date -Format "HH:mm:ss"
                        $txtOutput.AppendText("[$Timestamp] $Message`r`n")
                        $txtOutput.ScrollToEnd()
                    })
            }
        
            try {
                # Build arguments
                if ($Args -and ($Args -is [string]) -and ($Args.Trim())) {
                    $ArgArray = $Args.Trim().Split(" ", [StringSplitOptions]::RemoveEmptyEntries)
                    $Output = & $FullScriptPath @ArgArray 2>&1
                }
                else {
                    $Output = & $FullScriptPath 2>&1
                }
            
                # Stream output in real-time
                foreach ($Line in $Output) {
                    Write-Log $Line.ToString()
                }
            
                Write-Log "----------------------------------------"
                Write-Log "Script completed successfully"
            }
            catch {
                Write-Log "ERROR: $_"
            }
        
            # Refresh status on UI thread
            $Window.Dispatcher.Invoke([action] {
                    # Update status
                    if (Get-ScheduledTask -TaskName "Ethernet-AutoConfig" -ErrorAction SilentlyContinue) {
                        $EthernetStatus = $Window.FindName("txtEthernetStatus")
                        $EthernetStatus.Text = "INSTALLED"
                        $EthernetStatus.Foreground = "LightGreen"
                        ($Window.FindName("btnInstallEthernet")).IsEnabled = $false
                        ($Window.FindName("btnUninstallEthernet")).IsEnabled = $true
                    }
                    else {
                        $EthernetStatus = $Window.FindName("txtEthernetStatus")
                        $EthernetStatus.Text = "NOT INSTALLED"
                        $EthernetStatus.Foreground = "Red"
                        ($Window.FindName("btnInstallEthernet")).IsEnabled = $true
                        ($Window.FindName("btnUninstallEthernet")).IsEnabled = $false
                    }
            
                    if (Get-ScheduledTask -TaskName "WiFi-AutoConfig-Connect" -ErrorAction SilentlyContinue) {
                        $WiFiStatus = $Window.FindName("txtWiFiStatus")
                        $WiFiStatus.Text = "INSTALLED"
                        $WiFiStatus.Foreground = "LightGreen"
                        ($Window.FindName("btnInstallWiFi")).IsEnabled = $false
                        ($Window.FindName("btnUninstallWiFi")).IsEnabled = $true
                    }
                    else {
                        $WiFiStatus = $Window.FindName("txtWiFiStatus")
                        $WiFiStatus.Text = "NOT INSTALLED"
                        $WiFiStatus.Foreground = "Red"
                        ($Window.FindName("btnInstallWiFi")).IsEnabled = $true
                        ($Window.FindName("btnUninstallWiFi")).IsEnabled = $false
                    }
                })
        }).AddArgument($FullScriptPath).AddArgument($Args).AddArgument($Window).AddArgument($txtOutput)
    
    # Start async execution
    [void]$PowerShell.BeginInvoke()
}

# 8. Event Handlers
$btnInstallEthernet.Add_Click({
        Run-Script-Async "Ethernet\Setup-EthernetEventTrigger.ps1"
    })

$btnUninstallEthernet.Add_Click({
        Run-Script-Async "Ethernet\Uninstall-EthernetEventTrigger.ps1"
    })

$btnInstallWiFi.Add_Click({
        Run-Script-Async "WiFi\Setup-NetworkEventTrigger.ps1"
    })

$btnUninstallWiFi.Add_Click({
        Run-Script-Async "WiFi\Uninstall-NetworkEventTrigger.ps1"
    })

$btnApplyOverride.Add_Click({
        $Interface = $cmbInterface.Text
        $DurationStr = $cmbDuration.Text.Split(" ")[0]
        $Duration = [int]$DurationStr
    
        Run-Script-Async "Set-DhcpOverride.ps1" "-Interface $Interface -Days $Duration"
        $txtOverrideStatus.Text = "Override applied for $Interface ($Duration Days)"
    })

$btnClearOverride.Add_Click({
        $Interface = $cmbInterface.Text
            $script:NotifyIcon.ShowBalloonTip(2000, "Network Automation Manager", "Running in background. Double-click to restore.", [System.Windows.Forms.ToolTipIcon]::Info)
        }
    })

$Window.Add_Closing({
        $script:NotifyIcon.Visible = $false
        $script:NotifyIcon.Dispose()
    })

# 10. Initialize and Show
Write-Output-Log "Dashboard initialized."
Write-Output-Log "Ready to manage network automation."
Update-Status
$Window.ShowDialog() | Out-Null
