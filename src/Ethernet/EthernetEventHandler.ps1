# ===============================================================================
# Ethernet Event Handler (Zero-DHCP Strategy with State Management)
# Triggered by Network Profile Events (Event ID 10000)
# ===============================================================================

$ScriptPath = $PSScriptRoot
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptPath)
$LogFile = Join-Path $ProjectRoot "logs\Ethernet-EventHandler.log"
$ConfigFile = Join-Path $ScriptPath "EthernetConfig.ps1"

# ===============================================================================
# Logging Function
# ===============================================================================
function Write-Log {
    param ([string]$Message, [string]$Type = "INFO")
    if ($null -ne $EnableLogging -and -not $EnableLogging) { return }

    try {
        if ($MaxLogSizeMB -gt 0 -and (Test-Path $LogFile)) {
            $logSizeMB = (Get-Item $LogFile).Length / 1MB
            if ($logSizeMB -gt $MaxLogSizeMB) {
                $archivePath = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $LogFile -Destination $archivePath -Force
            }
        }
        
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
        Write-Host "Logging failed: ${_}" -ForegroundColor Red
    }
}

# ===============================================================================
# Helper Functions
# ===============================================================================

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

function Get-AdapterWithIP {
    param ($TargetIP)
    $AllAdapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "802.3" }
    foreach ($Adapter in $AllAdapters) {
        $CurrentIP = (Get-NetIPAddress -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($CurrentIP -eq $TargetIP) {
            return $Adapter
        }
    }
    return $null
}

# ===============================================================================
# Main Execution
# ===============================================================================

try {
    Write-Log "=========================================="
    Write-Log "Ethernet Event Handler Started (Zero-DHCP Mode)"
    Write-Log "=========================================="

    # 1. Load Configuration
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Configuration file not found: $ConfigFile" "ERROR"
        exit
    }
    . $ConfigFile

    # ===========================================================================
    # CHECK FOR TEMPORARY DHCP OVERRIDE
    # ===========================================================================
    $StateFile = Join-Path (Split-Path -Parent $ScriptPath) "DhcpOverride.state.json"
    if (Test-Path $StateFile) {
        try {
            $State = Get-Content $StateFile | ConvertFrom-Json
            if ($State.Ethernet) {
                $Expiry = [DateTime]::Parse($State.Ethernet)
                if ((Get-Date) -lt $Expiry) {
                    Write-Log "⚠️ TEMPORARY DHCP OVERRIDE ACTIVE (Expires: $($Expiry))" "WARNING"
                    Write-Log "  Skipping Static IP enforcement. Ensuring DHCP is enabled..."
                    
                    # Ensure DHCP is enabled on connected adapters
                    $ConnectedAdapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "802.3" -and $_.Status -eq "Up" }
                    foreach ($Adapter in $ConnectedAdapters) {
                        Set-NetIPInterface -InterfaceAlias $Adapter.Name -Dhcp Enabled -ErrorAction SilentlyContinue
                        Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ResetServerAddresses -ErrorAction SilentlyContinue
                    }
                    Write-Log "  [OK] DHCP Enforced (Override Mode)."
                    exit # EXIT SCRIPT
                }
                else {
                    Write-Log "ℹ️ DHCP Override Expired ($($Expiry)). Reverting to normal logic."
                    # Cleanup expired entry
                    $State.PSObject.Properties.Remove("Ethernet")
                    $State | ConvertTo-Json | Set-Content $StateFile
                }
            }
        }
        catch {
            Write-Log "Error reading override state: $_" "WARNING"
        }
    }
    # ===========================================================================

    # 2. Identify Device & Config
    $Hostname = $env:COMPUTERNAME
    $TargetConfig = $null
    
    foreach ($Key in $DeviceEthernetMap.Keys) {
        if ($Key -eq $Hostname) {
            $TargetConfig = $DeviceEthernetMap[$Key]
            break
        }
    }

    if ($TargetConfig) {
        Write-Log "Device: $Hostname | Target IP: $($TargetConfig.IPAddress)"
    }
    else {
        Write-Log "Device: $Hostname | No Static IP Configured (Unknown Device)"
    }

    # 3. Get ALL Ethernet Adapters (Connected or Not)
    $AllAdapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "802.3" }
    $ConnectedAdapters = $AllAdapters | Where-Object { $_.Status -eq "Up" }

    Write-Log "Total Ethernet Adapters: $($AllAdapters.Count) | Connected: $($ConnectedAdapters.Count)"

    # 4. If No Config for This Device -> Enable DHCP for Connected Adapters (Guest Support)
    if (-not $TargetConfig) {
        if ($UnknownDeviceAction -eq "DHCP") {
            Write-Log "Unknown device detected. Enabling DHCP for connected adapters..."
            foreach ($Adapter in $ConnectedAdapters) {
                $DhcpStatus = (Get-NetIPInterface -InterfaceAlias $Adapter.Name -AddressFamily IPv4).Dhcp
                if ($DhcpStatus -eq "Disabled") {
                    Set-NetIPInterface -InterfaceAlias $Adapter.Name -Dhcp Enabled -ErrorAction SilentlyContinue
                    Write-Log "  [GUEST MODE] DHCP enabled on: $($Adapter.Name)"
                }
            }
        }
        Write-Log "Exiting (Unknown Device)"
        exit
    }

    # 5. Check Current Holder (Who has the Static IP?)
    $CurrentHolder = Get-AdapterWithIP -TargetIP $TargetConfig.IPAddress
    
    if ($CurrentHolder) {
        Write-Log "Static IP is currently held by: $($CurrentHolder.Name) (Status: $($CurrentHolder.Status))"
        
        # If holder is disconnected, release the IP
        if ($CurrentHolder.Status -eq "Disconnected") {
            Write-Log "[DISCONNECT DETECTED] Releasing Static IP from: $($CurrentHolder.Name)"
            Remove-NetIPAddress -InterfaceAlias $CurrentHolder.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceAlias $CurrentHolder.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "  [OK] Static IP released. Adapter back to blank state (DHCP still disabled)."
            $CurrentHolder = $null
        }
    }

    # 6. Try to Assign IP to a Connected Adapter (if no holder exists)
    if (-not $CurrentHolder -and $ConnectedAdapters) {
        Write-Log "[FIRST-COME-FIRST-SERVE] No adapter has the Static IP. Assigning to first connected adapter..."
        
        $Winner = $ConnectedAdapters[0]
        Write-Log "Selected Adapter: $($Winner.Name) | Link Speed: $($Winner.LinkSpeed)"

        try {
            # Apply Static IP
            Write-Log "Applying Static IP: $($TargetConfig.IPAddress)"
            
            # Remove any existing IP first
            Remove-NetIPAddress -InterfaceAlias $Winner.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
            Remove-NetRoute -InterfaceAlias $Winner.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
            
            Start-Sleep -Milliseconds 500
            
            # Set new IP (without Gateway)
            New-NetIPAddress -InterfaceAlias $Winner.Name -IPAddress $TargetConfig.IPAddress -PrefixLength 24 -ErrorAction Stop | Out-Null
            
            # Add Gateway separately
            if ($TargetConfig.Gateway) {
                New-NetRoute -InterfaceAlias $Winner.Name -DestinationPrefix "0.0.0.0/0" -NextHop $TargetConfig.Gateway -ErrorAction Stop | Out-Null
            }
            
            # Set DNS
            if ($TargetConfig.DNS) {
                Set-DnsClientServerAddress -InterfaceAlias $Winner.Name -ServerAddresses $TargetConfig.DNS -ErrorAction Stop
            }
            
            # Set Metric
            Set-NetIPInterface -InterfaceAlias $Winner.Name -InterfaceMetric 5 -ErrorAction SilentlyContinue
            
            Write-Log "  [OK] Static IP Configuration Applied"

            # 7. Connectivity Validation (Office Check)
            Write-Log "Validating Connectivity..."
            
            # Give switch more time to adapt to new IP/VLAN (5 seconds)
            Start-Sleep -Seconds 5
            
            $GatewayReachable = Test-Connection -ComputerName $TargetConfig.Gateway -Count 4 -Quiet
            
            if ($GatewayReachable) {
                Write-Log "  [SUCCESS] Gateway reachable. We are in the Office."
            }
            else {
                Write-Log "  [WARNING] Gateway unreachable. Trying WAN targets..."
                
                # Fallback: Check Internet/WAN if Gateway ignores ICMP
                $WanReachable = $false
                if ($WanTestTargets) {
                    $WanReachable = Test-Connectivity -Targets $WanTestTargets -Threshold 1
                }
                
                if ($WanReachable) {
                    Write-Log "  [SUCCESS] WAN is reachable (Gateway ignored ping). Keeping Static IP."
                }
                else {
                    Write-Log "  [FAIL] Both Gateway and WAN unreachable. Assuming Travel/Home Mode." "WARNING"
                    Write-Log "  Enabling DHCP for this adapter only..."
                    
                    # Remove Static IP and enable DHCP for this adapter
                    Remove-NetIPAddress -InterfaceAlias $Winner.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                    Remove-NetRoute -InterfaceAlias $Winner.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                    Set-NetIPInterface -InterfaceAlias $Winner.Name -Dhcp Enabled -ErrorAction SilentlyContinue
                    Set-DnsClientServerAddress -InterfaceAlias $Winner.Name -ResetServerAddresses -ErrorAction SilentlyContinue
                    
                    Write-Log "  [TRAVEL MODE] DHCP enabled for $($Winner.Name)"
                }
            }
                


        }
        catch {
            Write-Log "  [ERROR] Failed to apply Static IP: ${_}" "ERROR"
        }
    }
    elseif ($CurrentHolder) {
        Write-Log "[ALREADY ASSIGNED] Static IP is active on: $($CurrentHolder.Name)"
    }
    else {
        Write-Log "[NO CABLE] No Ethernet adapters are connected."
    }

    # 8. WiFi Auto-Switch Logic
    if ($EnableWiFiAutoSwitch) {
        Write-Log "Checking Internet Connectivity for WiFi Auto-Switch..."
        
        if ($CurrentHolder -or ($ConnectedAdapters -and (Test-Connectivity -Targets $WanTestTargets -Threshold $WanSuccessThreshold))) {
            Write-Log "  [STABLE] Ethernet has connectivity. Disabling WiFi..."
            Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
        }
        else {
            # Debounce / Delay Logic
            if ($null -ne $WiFiAutoSwitchDelaySeconds -and $WiFiAutoSwitchDelaySeconds -gt 0) {
                Write-Log "  [WAIT] Ethernet down. Waiting $WiFiAutoSwitchDelaySeconds seconds before enabling WiFi..."
                Start-Sleep -Seconds $WiFiAutoSwitchDelaySeconds
                
                # Re-check Connectivity
                if ($ConnectedAdapters -and (Test-Connectivity -Targets $WanTestTargets -Threshold $WanSuccessThreshold)) {
                    Write-Log "  [RECOVERED] Ethernet connectivity restored. Keeping WiFi disabled."
                    Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
                    return
                }
            }

            Write-Log "  [UNSTABLE] Ethernet has NO connectivity. Enabling WiFi..."
            Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

}
catch {
    Write-Log "An error occurred: ${_}" "ERROR"
}
finally {
    Write-Log "=========================================="
    Write-Log "Ethernet Event Handler Completed"
    Write-Log "=========================================="
}
