# ============================================================================
# Ethernet Event Handler
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
    
    # Check if logging is enabled
    if (-not $EnableLogging) {
        return
    }

    try {
        # Rotate log if it exceeds max size
        if ($MaxLogSizeMB -gt 0 -and (Test-Path $LogFile)) {
            $logSizeMB = (Get-Item $LogFile).Length / 1MB
            if ($logSizeMB -gt $MaxLogSizeMB) {
                $archivePath = $LogFile -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $LogFile -Destination $archivePath -Force
                Write-Host "Log rotated: $archivePath" -ForegroundColor Yellow
            }
        }
        
        # Clean old log files based on retention policy
        if ($LogRetentionDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
            Get-ChildItem -Path (Join-Path $ProjectRoot "logs") -Filter "Ethernet-EventHandler_*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force
        }

        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$Timestamp] [$Type] $Message"
        
        # Write to file
        Add-Content -Path $LogFile -Value $LogEntry
        
        # Write to console with color
        if ($Type -eq "ERROR") {
            Write-Host $LogEntry -ForegroundColor Red
        }
        else {
            Write-Host $LogEntry -ForegroundColor Cyan
        }
    }
    catch {
        # Silent fail - don't break the script if logging fails
        Write-Host "Logging failed: $_" -ForegroundColor Red
    }
}

# ============================================================================
# Main Execution
# ============================================================================

try {
    Write-Log "Ethernet Event Handler Started"

    # 1. Load Configuration
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Configuration file not found: $ConfigFile" "ERROR"
        exit
    }
    . $ConfigFile

    # 2. Get Connected Ethernet Adapters
    # We look for adapters that are Up and are Ethernet (Type 6)
    $Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3" }

    if (-not $Adapters) {
        Write-Log "No active Ethernet adapters found."
        exit
    }

    foreach ($Adapter in $Adapters) {
        $MacAddress = $Adapter.MacAddress -replace "-", "-" # Ensure format matches config (dashes)
        Write-Log "Checking Adapter: $($Adapter.Name) | MAC: $MacAddress"

        if ($EthernetConfigs.ContainsKey($MacAddress)) {
            # Match Found - Apply Static IP
            $Config = $EthernetConfigs[$MacAddress]
            Write-Log "MATCH FOUND! Applying configuration for: $($Config.Description)"

            # Check if already configured to avoid redundant re-application
            $CurrentIP = (Get-NetIPAddress -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
            
            if ($CurrentIP -eq $Config.IPAddress) {
                Write-Log "IP $CurrentIP is already active. Skipping."
            }
            else {
                Write-Log "Applying Static IP: $($Config.IPAddress)"
                
                try {
                    # Step 1: Remove all existing routes (including default gateway)
                    Write-Log "Removing existing routes..."
                    Get-NetRoute -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Log "Routes removed successfully"
                    
                    # Step 2: Disable DHCP
                    Write-Log "Disabling DHCP..."
                    Set-NetIPInterface -InterfaceAlias $Adapter.Name -Dhcp Disabled -ErrorAction Stop
                    Write-Log "DHCP disabled successfully"

                    # Step 3: Remove all existing IPs
                    Write-Log "Removing existing IP addresses..."
                    Get-NetIPAddress -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
                    Write-Log "IP addresses removed successfully"
                    
                    # Wait for Windows to process the removal
                    Start-Sleep -Milliseconds 500

                    # Step 4: Set New IP (without gateway first to avoid conflict)
                    Write-Log "Setting new IP address: $($Config.IPAddress)..."
                    New-NetIPAddress -InterfaceAlias $Adapter.Name -IPAddress $Config.IPAddress -PrefixLength 24 -Confirm:$false -ErrorAction Stop | Out-Null
                    Write-Log "IP address set successfully"
                    
                    # Wait before adding gateway
                    Start-Sleep -Milliseconds 500
                    
                    # Step 5: Add default gateway separately
                    Write-Log "Adding default gateway: $($Config.Gateway)..."
                    New-NetRoute -InterfaceAlias $Adapter.Name -DestinationPrefix "0.0.0.0/0" -NextHop $Config.Gateway -Confirm:$false -ErrorAction Stop | Out-Null
                    Write-Log "Gateway added successfully"

                    # Step 6: Set DNS
                    Write-Log "Setting DNS servers..."
                    Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ServerAddresses $Config.DNS -ErrorAction Stop
                    Write-Log "DNS servers set successfully"
                    
                    Write-Log "Configuration Applied Successfully."
                }
                catch {
                    Write-Log "Failed at step: $($_.InvocationInfo.Line.Trim())" "ERROR"
                    Write-Log "Error details: $($_.Exception.Message)" "ERROR"
                    throw
                }
            }

        }
        else {
            # No Match - Check Unknown Action
            Write-Log "No configuration found for MAC: $MacAddress"
            
            if ($UnknownMacAction -eq "DHCP") {
                Write-Log "Enforcing DHCP (Default Action)"
                
                # Check if DHCP is already enabled
                $IsDhcpEnabled = (Get-NetIPInterface -InterfaceAlias $Adapter.Name -AddressFamily IPv4).Dhcp

                if ($IsDhcpEnabled -eq "Enabled") {
                    Write-Log "DHCP is already enabled. Skipping."
                }
                else {
                    Write-Log "Enabling DHCP..."
                    
                    # Clean up existing routes and IPs first
                    Get-NetRoute -InterfaceAlias $Adapter.Name -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
                    Remove-NetIPAddress -InterfaceAlias $Adapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                    
                    Set-NetIPInterface -InterfaceAlias $Adapter.Name -Dhcp Enabled -ErrorAction Stop
                    Set-DnsClientServerAddress -InterfaceAlias $Adapter.Name -ResetServerAddresses -ErrorAction Stop
                    Write-Log "DHCP Enabled."
                }
            }
        }
    }

}
catch {
    Write-Log "An error occurred: $($_.Exception.Message)" "ERROR"
}
finally {
    Write-Log "Ethernet Event Handler Completed"
}
