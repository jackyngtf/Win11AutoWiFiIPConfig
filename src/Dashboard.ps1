# ============================================================================
# Network Automation Dashboard
# A GUI to manage Ethernet and WiFi automation scripts.
# ============================================================================

# 1. Self-Elevation Logic
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# 2. Load WPF Assembly
Add-Type -AssemblyName PresentationFramework

# 3. Define XAML UI
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Network Automation Manager" Height="500" Width="700"
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
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,20">
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

        <!-- Footer -->
        <TextBlock Grid.Row="2" Text="v1.0 - Zero DHCP Strategy" HorizontalAlignment="Center" Foreground="#555555" FontSize="10"/>
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

$cmbInterface = $Window.FindName("cmbInterface")
$cmbDuration = $Window.FindName("cmbDuration")
$btnApplyOverride = $Window.FindName("btnApplyOverride")
$btnClearOverride = $Window.FindName("btnClearOverride")
$txtOverrideStatus = $Window.FindName("txtOverrideStatus")

# 6. Helper Functions
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

function Run-Script ($ScriptPath, $Args = "") {
    $FullScriptPath = Join-Path $PSScriptRoot $ScriptPath
    if (Test-Path $FullScriptPath) {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$FullScriptPath`" $Args" -Wait
        Update-Status
    }
    else {
        [System.Windows.MessageBox]::Show("Script not found: $FullScriptPath", "Error", "OK", "Error")
    }
}

# 7. Event Handlers
$btnInstallEthernet.Add_Click({
        Run-Script "Ethernet\Setup-EthernetEventTrigger.ps1"
    })

$btnUninstallEthernet.Add_Click({
        Run-Script "Ethernet\Uninstall-EthernetEventTrigger.ps1"
    })

$btnInstallWiFi.Add_Click({
        Run-Script "WiFi\Setup-NetworkEventTrigger.ps1"
    })

$btnUninstallWiFi.Add_Click({
        Run-Script "WiFi\Uninstall-NetworkEventTrigger.ps1"
    })

$btnApplyOverride.Add_Click({
        $Interface = $cmbInterface.Text
        $DurationStr = $cmbDuration.Text.Split(" ")[0] # Extract number
        $Duration = [int]$DurationStr
    
        Run-Script "Set-DhcpOverride.ps1" "-Interface $Interface -Days $Duration"
        $txtOverrideStatus.Text = "Override applied for $Interface ($Duration Days)"
    })

$btnClearOverride.Add_Click({
        $Interface = $cmbInterface.Text
        Run-Script "Set-DhcpOverride.ps1" "-Interface $Interface -Clear"
        $txtOverrideStatus.Text = "Override cleared for $Interface"
    })

# 8. Initialize and Show
Update-Status
$Window.ShowDialog() | Out-Null
