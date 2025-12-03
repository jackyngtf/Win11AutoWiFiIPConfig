# ============================================================================
# Ethernet Event Handler (Device-Centric)
# Triggered by Network Profile Events (Event ID 10000)
# ============================================================================

$ScriptPath = $PSScriptRoot
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptPath)  # Go up 2 levels: src/Ethernet -> src -> root
$LogFile = Join-Path $ProjectRoot "logs\Ethernet-EventHandler.log"
$ConfigFile = Join-Path $ScriptPath "EthernetConfig.ps1"

# ============================================================================
# Logging Function
# ============================================================================
function Write-Log {
    param ([string]$Message, [string]$Type = "INFO")
    
    # Check if logging is enabled (default to true if variable missing)
    if ($null -ne $EnableLogging -and -not $EnableLogging) { return }

    try {
        # Rotate log if it exceeds max size
        if ($MaxLogSizeMB -gt 0 -and (Test-Path $LogFile)) {
            $logSizeMB = (Get-Item $LogFile).Length / 1MB
            if ($logSizeMB -gt $MaxLogSizeMB) {
                $archivePath = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $LogFile -Destination $archivePath -Force
            }
        }
        
        # Clean old log files
        if ($LogRetentionDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
            Get-ChildItem -Path (Join-Path $ProjectRoot "logs") -Filter "Ethernet-EventHandler_*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force
        }

        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$Timestamp] [$Type] $Message"
        Add-Content -Path $LogFile -Value $LogEntry
        
        $Color = if ($Type -eq "ERROR") { "Red" } elseif ($Type -eq "WARNING") { "Yellow" } else { "Cyan" }
        Write-Host $LogEntry -ForegroundColor $Color
    }
    catch {
        Write-Host "Logging failed: $_" -ForegroundColor Red
    }
}

# ============================================================================
# Helper Functions
# ============================================================================

function Set-DhcpMode {
    param ($InterfaceAlias, $Metric = 20)
    Write-Log "  Enforcing DHCP on $InterfaceAlias (Metric: $Metric)..."
    try {
        # Enable DHCP
        Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled -InterfaceMetric $Metric -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction SilentlyContinue
        Write-Log "  [OK] DHCP Enabled on $InterfaceAlias"
    }
    catch {
        Write-Log "  [ERROR] Failed to set DHCP on $InterfaceAlias: $_" "ERROR"
    }
}

function Test-Connectivity {
    param ($Targets, $Threshold = 1)
    $SuccessCount = 0
    foreach ($Target in $Targets) {
        if (Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $SuccessCount++
        }
    }
    return ($SuccessCount -ge $Threshold)
}

# ============================================================================
# Main Execution
# ============================================================================

try {
    Write-Log "Ethernet Event Handler Started (Device-Centric Mode)"

    # 1. Load Configuration
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Configuration file not found: $ConfigFile" "ERROR"
        exit
    }
    . $ConfigFile

    # 2. Identify Device & Config
    $Hostname = $env:COMPUTERNAME
    $TargetConfig = $null
    
    # Case-insensitive lookup
    foreach ($Key in $DeviceEthernetMap.Keys) {
        if ($Key -eq $Hostname) {
            $TargetConfig = $DeviceEthernetMap[$Key]
            break
        }
    }

    if ($TargetConfig) {
        Write-Log "Device Identified: $Hostname (Config Found: $($TargetConfig.Description))"
    }
    else {
        Write-Log "Device Identified: $Hostname (No Static IP Configured)"
    }

    # 3. Get Connected Adapters & Select Winner
    $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3" }
    
    if (-not $Adapters) {
        Write-Log "No active Ethernet adapters found."
        # Ensure WiFi is enabled if no Ethernet
        if ($EnableWiFiAutoSwitch) { Enable-NetAdapter -Name "Wi-Fi" -ErrorAction SilentlyContinue }
        exit
    }

    # Sort: LinkSpeed Descending, then InterfaceIndex Ascending
    $SortedAdapters = $Adapters | Sort-Object LinkSpeed -Descending | Sort-Object InterfaceIndex
    $Winner = $SortedAdapters[0]
    $Losers = $SortedAdapters | Select-Object -Skip 1

    Write-Log "Winner Selected: $($Winner.Name) ($($Winner.LinkSpeed))"
    if ($Losers) { Write-Log "Losers (Forced DHCP): $($Losers.Name -join ', ')" }

    # 4. Handle Losers (Conflict Resolution)
    foreach ($Loser in $Losers) {
        Set-DhcpMode -InterfaceAlias $Loser.Name -Metric 50
    }

    # 5. Handle Winner
    if ($TargetConfig) {
        # Try to apply Static IP
        Write-Log "Applying Static IP to Winner: $($TargetConfig.IPAddress)"
        
        try {
            # Check if already set correctly
            $CurrentIP = (Get-NetIPAddress -InterfaceAlias $Winner.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
            
            if ($CurrentIP -ne $TargetConfig.IPAddress) {
                # Reset & Apply
                New-NetIPAddress -InterfaceAlias $Winner.Name -IPAddress $TargetConfig.IPAddress -PrefixLength 24 -ErrorAction SilentlyContinue | Out-Null
                
                # Add Gateway (Separate Route to avoid PolicyStore error)
                if ($TargetConfig.Gateway) {
                    New-NetRoute -InterfaceAlias $Winner.Name -DestinationPrefix "0.0.0.0/0" -NextHop $TargetConfig.Gateway -ErrorAction SilentlyContinue | Out-Null
                }
                
                # Set DNS
                Set-DnsClientServerAddress -InterfaceAlias $Winner.Name -ServerAddresses $TargetConfig.DNS -ErrorAction SilentlyContinue
                
                # Set Metric (High Priority)
                Set-NetIPInterface -InterfaceAlias $Winner.Name -InterfaceMetric 5 -ErrorAction SilentlyContinue
                
                Write-Log "  [OK] Static IP Configuration Applied"
            }
            else {
                Write-Log "  [OK] Static IP already active"
            }

            # 6. Connectivity Validation (Travel Mode)
            Write-Log "Validating Connectivity (Ping Gateway: $($TargetConfig.Gateway))..."
            Start-Sleep -Seconds 2 # Wait for link to settle
            
            if (Test-Connection -ComputerName $TargetConfig.Gateway -Count 2 -Quiet) {
                Write-Log "  [SUCCESS] Gateway reachable. We are in the Office."
            }
            else {
                Write-Log "  [FAIL] Gateway unreachable. Assuming Travel/Home Mode."
                Write-Log "  Reverting Winner to DHCP..."
                Set-DhcpMode -InterfaceAlias $Winner.Name -Metric 20
            }

        }
        catch {
            Write-Log "  [ERROR] Failed to apply Static IP: $_" "ERROR"
            Write-Log "  Fallback to DHCP..."
            Set-DhcpMode -InterfaceAlias $Winner.Name -Metric 20
        }
    }
    else {
        # No config for this device -> DHCP
        Write-Log "No Static IP for this device. Using DHCP."
        Set-DhcpMode -InterfaceAlias $Winner.Name -Metric 20
    }

    # 7. WiFi Auto-Switch Logic
    if ($EnableWiFiAutoSwitch) {
        Write-Log "Checking Internet Connectivity for WiFi Auto-Switch..."
        
        # Check if Winner has Internet access
        if (Test-Connectivity -Targets $WanTestTargets -Threshold $WanSuccessThreshold) {
            Write-Log "  [STABLE] Ethernet has Internet access. Disabling WiFi..."
            Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
        }
        else {
            Write-Log "  [UNSTABLE] Ethernet has NO Internet. Enabling WiFi..."
            Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

}
catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
}
finally {
    Write-Log "Ethernet Event Handler Completed"
}
