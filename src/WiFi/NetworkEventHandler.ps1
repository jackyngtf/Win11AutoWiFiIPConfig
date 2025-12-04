# ============================================================================
# Network Event Handler - Automatic IP Configuration
# Triggered by Windows network connection events
# ============================================================================

param (
    [string]$TriggerEvent = "Auto"  # "Connect", "Disconnect", or "Auto"
)

# Log file for troubleshooting (centralized logs folder)
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)  # Go up 2 levels: src/WiFi -> src -> root
$logPath = Join-Path $projectRoot "logs\WiFi-NetworkEventHandler.log"

# Configuration - Load from main script
$scriptPath = $PSScriptRoot
$configFile = Join-Path $scriptPath "NetworkConfig.ps1"

if (-not (Test-Path $configFile)) {
    # If config is missing, log anyway but with defaults
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - [ERROR] Configuration file not found: $configFile" | Out-File -FilePath $logPath -Append
    exit 1
}

# Load configuration
. $configFile

# Enhanced logging function with rotation and size management
function Write-Log {
    param([string]$Message)
    
    # Check if logging is enabled
    if (-not $EnableLogging) {
        return
    }
    
    try {
        # Rotate log if it exceeds max size
        if ($MaxLogSizeMB -gt 0 -and (Test-Path $logPath)) {
            $logSizeMB = (Get-Item $logPath).Length / 1MB
            if ($logSizeMB -gt $MaxLogSizeMB) {
                $archivePath = $logPath -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                Move-Item -Path $logPath -Destination $archivePath -Force
                Write-Host "Log rotated: $archivePath" -ForegroundColor Yellow
            }
        }
        
        # Clean old log files based on retention policy
        if ($LogRetentionDays -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
            Get-ChildItem -Path (Join-Path $projectRoot "logs") -Filter "WiFi-NetworkEventHandler_*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force
        }
        
        # Write log entry
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - [$TriggerEvent] $Message" | Out-File -FilePath $logPath -Append
    }
    catch {
        # Silent fail - don't break the script if logging fails
    }
}

# ===========================================================================
# CHECK FOR TEMPORARY DHCP OVERRIDE
# ===========================================================================
$StateFile = Join-Path (Split-Path -Parent $PSScriptRoot) "DhcpOverride.state.json"
if (Test-Path $StateFile) {
    try {
        $State = Get-Content $StateFile | ConvertFrom-Json
        if ($State.'Wi-Fi') {
            $Expiry = [DateTime]::Parse($State.'Wi-Fi')
            if ((Get-Date) -lt $Expiry) {
                Write-Log "TEMPORARY DHCP OVERRIDE ACTIVE (Expires: $Expiry)"
                Write-Log "  Skipping Static IP enforcement. Ensuring DHCP is enabled..."
                
                # Ensure DHCP is enabled
                Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Dhcp Enabled -ErrorAction SilentlyContinue
                Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses -ErrorAction SilentlyContinue
                
                Write-Log "  [OK] DHCP Enforced (Override Mode)."
                exit # EXIT SCRIPT
            }
            else {
                Write-Log "DHCP Override Expired ($Expiry). Reverting to normal logic."
                # Cleanup expired entry
                $State.PSObject.Properties.Remove('Wi-Fi')
                $State | ConvertTo-Json | Set-Content $StateFile
            }
        }
    }
    catch {
        Write-Log "Error reading override state: $_"
    }
}
# ===========================================================================

# Function to get current WiFi SSID
function Get-CurrentWiFiSSID {
    try {
        $netshOutput = netsh wlan show interfaces
        
        # Parse line by line to handle wrapping issues
        foreach ($line in $netshOutput) {
            # Look for Profile field
            if ($line -match '^\s*Profile\s*:\s*(.+)') {
                $ssid = $matches[1].Trim()
                if ($ssid -and $ssid -ne "") {
                    return $ssid
                }
            }
            # Fallback to SSID field
            if ($line -match '^\s*SSID\s*:\s*(.+)') {
                $ssid = $matches[1].Trim()
                if ($ssid -and $ssid -ne "" -and $ssid -notlike "*BSSID*") {
                    return $ssid
                }
            }
        }
    }
    catch {
        Write-Log "[ERROR] Failed to get current WiFi SSID: $_"
    }
    return $null
}

# Function to convert subnet mask to prefix
function Convert-SubnetMaskToPrefix {
    param ([string]$SubnetMask)
    $ip = [System.Net.IPAddress]$SubnetMask
    # Get bytes in correct order (big-endian)
    $bytes = $ip.GetAddressBytes()
    $binary = -join ($bytes | ForEach-Object { [Convert]::ToString($_, 2).PadLeft(8, '0') })
    $prefix = $binary.IndexOf('0')
    if ($prefix -eq -1) { return 32 } else { return $prefix }
}

# Function to apply static IP configuration
function Set-StaticIPConfiguration {
    param (
        [string]$SSID,
        [string]$StaticIP,
        [string]$SubnetMask,
        [string]$Gateway,
        [string]$PrimaryDNS,
        [string]$SecondaryDNS
    )

    try {
        Write-Log "[INFO] Applying static IP configuration for SSID: $SSID"

        # Get WiFi adapter (Relaxed check to find it even if disconnected)
        $wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.Name -like "*Wi-Fi*" }
        if (-not $wifiAdapter) {
            # Fallback to any physical adapter if specific Wi-Fi name not found (risky but fallback)
            $wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq "802.3" -or $_.MediaType -eq "Native 802.11" } | Select-Object -First 1
        }

        if (-not $wifiAdapter) {
            Write-Log "[ERROR] No WiFi adapter found"
            return $false
        }

        $interfaceIndex = $wifiAdapter.ifIndex
        $interfaceName = $wifiAdapter.Name

        Write-Log "  WiFi Adapter: $interfaceName (Index: $interfaceIndex) Status: $($wifiAdapter.Status)"

        # NEW: Check if adapter is disabled and enable it
        if ($wifiAdapter.Status -eq "Disabled") {
            Write-Log "[!] WiFi adapter is disabled (possibly by Ethernet auto-switch). Enabling it for configuration..."
            Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
            Start-Sleep -Seconds 2
            # Refresh adapter object
            $wifiAdapter = Get-NetAdapter -Name $wifiAdapter.Name
            Write-Log "  Adapter enabled: $($wifiAdapter.Status)"
        }

        # !! CRITICAL: Disable DHCP FIRST to prevent ANY DHCP requests !!
        Write-Log "  [PRIORITY] Disabling DHCP immediately to block DHCP requests..."
        try {
            # Check current DHCP state first (with better error handling)
            $currentDhcpState = (Get-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp
            
            # Handle case where interface state can't be retrieved (adapter initializing)
            if ($null -eq $currentDhcpState) {
                Write-Log "  [WARNING] Could not get DHCP state (adapter may be initializing). Attempting to disable DHCP anyway..."
                Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction SilentlyContinue
                return $false
            }
            
            if ($currentDhcpState -eq "Enabled") {
                Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
                Write-Log "  [OK] DHCP disabled - no DHCP requests will be sent"
            }
            else {
                Write-Log "  [OK] DHCP already disabled"
            }
        }
        catch {
            Write-Log "  [WARNING] DHCP disable check: $_"
        }

        # Remove existing IPv4 address
        try {
            $existingIP = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($existingIP) {
                Write-Log "  Removing existing IP addresses..."
                Remove-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction Stop
                Start-Sleep -Milliseconds 300
            }
        }
        catch {
            Write-Log "  No existing IP to remove: $_"
        }

        # Remove existing routes
        try {
            $existingRoutes = Get-NetRoute -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($existingRoutes) {
                Write-Log "  Removing existing routes..."
                foreach ($route in $existingRoutes) {
                    if ($route.DestinationPrefix -ne "255.255.255.255/32") {
                        Remove-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix $route.DestinationPrefix -Confirm:$false -ErrorAction SilentlyContinue
                    }
                }
                Start-Sleep -Milliseconds 300
            }
        }
        catch {
            Write-Log "  No existing routes to remove: $_"
        }

        # Convert subnet mask to prefix length
        $prefix = Convert-SubnetMaskToPrefix -SubnetMask $SubnetMask
        Write-Log "  Setting static IP: $StaticIP/$prefix"

        # Set static IP address
        try {
            New-NetIPAddress -InterfaceIndex $interfaceIndex `
                -IPAddress $StaticIP `
                -PrefixLength $prefix `
                -ErrorAction Stop | Out-Null
            
            # Add Default Gateway separately to avoid PolicyStore conflicts
            if ($Gateway) {
                New-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix "0.0.0.0/0" -NextHop $Gateway -ErrorAction Stop | Out-Null
            }
        }
        catch {
            if ($_.Exception.Message -like "*already exists*") {
                Write-Log "  [INFO] IP address $StaticIP already exists, skipping creation."
            }
            else {
                throw $_
            }
        }

        Start-Sleep -Milliseconds 500

        # Configure DNS servers
        $dnsServers = @($PrimaryDNS)
        if (![string]::IsNullOrWhiteSpace($SecondaryDNS)) { 
            $dnsServers += $SecondaryDNS 
        }
        
        Write-Log "  Configuring DNS: $($dnsServers -join ', ')"
        Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex `
            -ServerAddresses $dnsServers `
            -ErrorAction Stop

        # Disable IPv6
        try {
            Disable-NetAdapterBinding -Name $interfaceName -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
        }
        catch {
            Write-Log "  IPv6 already disabled"
        }

        Write-Log "  Configuration applied successfully!"
        return $true
    }
    catch {
        # Check if IP was actually applied despite error (common with PolicyStore issues)
        $currentIP = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $StaticIP }
        
        if ($currentIP) {
            Write-Log "  [WARNING] Static IP applied successfully, but reported error: $_"
            Write-Host "  [WARNING] Static IP applied successfully, but reported error: $_" -ForegroundColor Yellow
            return $true
        }
        else {
            Write-Log "  [ERROR] Failed to apply static IP: $_"
            Write-Host "  [ERROR] Failed to apply static IP: $_" -ForegroundColor Red
            return $false
        }
        return $false
    }
}

# Function to request DHCP IP WITHOUT enabling DHCP (Zero-DHCP Strategy)
function Set-DHCPConfiguration {
    try {
        Write-Log "[INFO] Requesting DHCP IP (DHCP remains disabled to prevent race condition)..."

        # Get WiFi adapter
        $wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.Name -like "*Wi-Fi*" }
        if (-not $wifiAdapter) {
            $wifiAdapter = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq "802.3" -or $_.MediaType -eq "Native 802.11" } | Select-Object -First 1
        }

        if (-not $wifiAdapter) {
            Write-Log "[ERROR] No active WiFi adapter found"
            return $false
        }

        $interfaceIndex = $wifiAdapter.ifIndex
        $interfaceName = $wifiAdapter.Name

        Write-Log "  WiFi Adapter: $interfaceName (Index: $interfaceIndex) Status: $($wifiAdapter.Status)"
        
        # STEP 1: Ensure DHCP is DISABLED (this prevents race conditions)
        Write-Log "  [CRITICAL] Ensuring DHCP is DISABLED (prevents race condition)..."
        try {
            $currentDhcpState = (Get-NetIPInterface -InterfaceIndex $interfaceIndex -AddressFamily IPv4).Dhcp
            if ($currentDhcpState -eq "Enabled") {
                Set-NetIPInterface -InterfaceIndex $interfaceIndex -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop
                Write-Log "  [OK] DHCP disabled on adapter"
            }
            else {
                Write-Log "  [OK] DHCP already disabled on adapter"
            }
        }
        catch {
            Write-Log "  DHCP disable check: $_"
        }

        # STEP 2: Remove all existing static IP addresses
        try {
            $existingIPs = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($existingIPs) {
                Write-Log "  Removing existing static IP addresses..."
                foreach ($ip in $existingIPs) {
                    Remove-NetIPAddress -InterfaceIndex $interfaceIndex -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
                }
                Start-Sleep -Milliseconds 500
            }
        }
        catch {
            Write-Log "  No existing IPs to remove: $_"
        }

        # STEP 3: Remove all existing routes (including gateway)
        try {
            $existingRoutes = Get-NetRoute -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($existingRoutes) {
                Write-Log "  Removing existing routes (including gateway)..."
                foreach ($route in $existingRoutes) {
                    if ($route.DestinationPrefix -ne "255.255.255.255/32") {
                        Remove-NetRoute -InterfaceIndex $interfaceIndex -DestinationPrefix $route.DestinationPrefix -Confirm:$false -ErrorAction SilentlyContinue
                    }
                }
                Start-Sleep -Milliseconds 500
            }
        }
        catch {
            Write-Log "  No existing routes to remove: $_"
        }

        # STEP 4: Use netsh to set DHCP mode WITHOUT enabling it in PowerShell
        # This requests a DHCP lease while keeping the interface in "disabled" state
        Write-Log "  Requesting DHCP IP via netsh (DHCP still disabled)..."
        try {
            netsh interface ip set address name="$interfaceName" source=dhcp | Out-Null
            Start-Sleep -Milliseconds 500
            
            # Force renewal
            Write-Log "  Forcing DHCP lease renewal..."
            ipconfig /renew "$interfaceName" | Out-Null
        }
        catch {
            Write-Log "  [ERROR] Failed to request DHCP via netsh: $_"
        }

        # STEP 5: Reset DNS to automatic
        Write-Log "  Resetting DNS servers to automatic..."
        try {
            netsh interface ip set dns name="$interfaceName" source=dhcp | Out-Null
        }
        catch {
            Write-Log "  [ERROR] Failed to set DNS: $_"
        }

        Write-Log "  [OK] DHCP IP requested (DHCP remains DISABLED on adapter)"
        return $true
    }
    catch {
        Write-Log "  [ERROR] Failed to configure DHCP: $_"
        Write-Host "  [ERROR] Failed to configure DHCP: $_" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "=== Network Event Handler Triggered (Event: $TriggerEvent) ==="

# ----------------------------------------------------------------------------
# LOGIC FOR DISCONNECT EVENT (Event ID 8003)
# ----------------------------------------------------------------------------
if ($TriggerEvent -eq "Disconnect") {
    Write-Log "[!] DISCONNECT EVENT DETECTED"
    Write-Log "[*] IMMEDIATE ACTION: Applying Default Company Static IP (Safe Mode)"
    
    # Apply default company static IP configuration immediately
    # NO DELAYS allowed here!
    $result = Set-StaticIPConfiguration -SSID "DISCONNECTED-SAFE-MODE" `
        -StaticIP $DefaultStaticIP `
        -SubnetMask $DefaultSubnetMask `
        -Gateway $DefaultGateway `
        -PrimaryDNS $DefaultPrimaryDNS `
        -SecondaryDNS $DefaultSecondaryDNS

    if ($result) {
        Write-Log "[OK] Safe Mode configuration applied!"
        Write-Host "[OK] Safe Mode configuration applied!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Log "[X] Failed to apply Safe Mode."
        Write-Host "[X] Failed to apply Safe Mode." -ForegroundColor Red
        exit 1
    }
}

# ----------------------------------------------------------------------------
# LOGIC FOR CONNECT EVENT (Event ID 8001/10000) or AUTO
# ----------------------------------------------------------------------------

# If triggered by Connect, we might need to wait for SSID to populate
if ($TriggerEvent -eq "Connect" -or $TriggerEvent -eq "Auto") {
    Write-Log "[*] Connect event detected - waiting for SSID..."
    
    $maxRetries = 5
    $retryCount = 0
    $currentSSID = $null

    while (-not $currentSSID -and $retryCount -lt $maxRetries) {
        $currentSSID = Get-CurrentWiFiSSID
        if (-not $currentSSID) {
            $retryCount++
            Write-Log "  Attempt ${retryCount}/${maxRetries}: No SSID yet, waiting..."
            Start-Sleep -Seconds 1
        }
    }
}
else {
    # Fallback for unknown triggers
    $currentSSID = Get-CurrentWiFiSSID
}

if (-not $currentSSID) {
    Write-Log "[!] No WiFi network detected after retries"
    Write-Log "[*] Assuming Disconnected/Unknown State -> Applying Safe Mode"
    
    # Fallback to Safe Mode if we can't determine SSID
    # Fallback to Safe Mode if we can't determine SSID
    $result = Set-StaticIPConfiguration -SSID "UNKNOWN-SAFE-MODE" `
        -StaticIP $DefaultStaticIP `
        -SubnetMask $DefaultSubnetMask `
        -Gateway $DefaultGateway `
        -PrimaryDNS $DefaultPrimaryDNS `
        -SecondaryDNS $DefaultSecondaryDNS
        
    if ($result) {
        exit 0
    }
    else {
        exit 1
    }
}

Write-Log "[*] Current WiFi SSID: $currentSSID"

# Check if this is a known company network
$matchingNetwork = $CompanyWiFiNetworks | Where-Object { $_.SSID -eq $currentSSID }

if ($matchingNetwork) {
    Write-Log "[OK] SSID is a known company network"

    # Get configuration values with defaults
    if ($matchingNetwork.SubnetMask) { $subnetMask = $matchingNetwork.SubnetMask } else { $subnetMask = $DefaultSubnetMask }
    if ($matchingNetwork.StaticIP) { $staticIP = $matchingNetwork.StaticIP } else { $staticIP = $DefaultStaticIP }
    if ($matchingNetwork.PrimaryDNS) { $primaryDNS = $matchingNetwork.PrimaryDNS } else { $primaryDNS = $DefaultPrimaryDNS }
    if ($matchingNetwork.SecondaryDNS) { $secondaryDNS = $matchingNetwork.SecondaryDNS } else { $secondaryDNS = $DefaultSecondaryDNS }
    if ($matchingNetwork.Gateway) { $gateway = $matchingNetwork.Gateway } else { $gateway = $DefaultGateway }

    # Apply static IP configuration
    $result = Set-StaticIPConfiguration -SSID $currentSSID `
        -StaticIP $staticIP `
        -SubnetMask $subnetMask `
        -Gateway $gateway `
        -PrimaryDNS $primaryDNS `
        -SecondaryDNS $secondaryDNS

    if ($result) {
        Write-Log "[OK] Configuration completed successfully!"
    }
    else {
        Write-Log "[X] Configuration encountered errors!"
    }
}
else {
    Write-Log "[!] SSID is NOT in known company networks"
    Write-Log "[*] Enabling DHCP for this network..."
    $result = Set-DHCPConfiguration
    
    if (-not $result) {
        Write-Host "[X] Failed to enable DHCP configuration" -ForegroundColor Red
        exit 1
    }
}

Write-Log "=== Event Handler Completed ===`n"
