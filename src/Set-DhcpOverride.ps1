# ============================================================================
# Set-DhcpOverride.ps1
# Allows temporary DHCP override for a specific duration.
# ============================================================================

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Wi-Fi", "Ethernet", "All")]
    [string]$Interface,

    [Parameter(Mandatory = $false)]
    [int]$Days = 0,

    [switch]$Clear
)

$ScriptPath = $PSScriptRoot
$StateFile = Join-Path $ScriptPath "DhcpOverride.state.json"

# Helper to get current state
function Get-State {
    if (Test-Path $StateFile) {
        return Get-Content $StateFile | ConvertFrom-Json
    }
    return @{}
}

# Helper to save state
function Save-State ($State) {
    $State | ConvertTo-Json | Set-Content $StateFile
}

# Helper to Enable DHCP immediately
function Enable-DhcpNow ($InterfaceAlias) {
    Write-Host "  Enabling DHCP on $InterfaceAlias..." -ForegroundColor Cyan
    try {
        # NEW: Check if adapter is disabled and enable it
        $Adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue
        if (-not $Adapter) {
            Write-Host "  [ERROR] Adapter '$InterfaceAlias' not found" -ForegroundColor Red
            return
        }
        
        if ($Adapter.Status -eq "Disabled") {
            Write-Host "    [!] Adapter is disabled (possibly by Ethernet auto-switch). Enabling..." -ForegroundColor Yellow
            Enable-NetAdapter -Name $InterfaceAlias -Confirm:$false
            Start-Sleep -Seconds 2
        }
        
        # STEP 1: Remove all existing static IP addresses
        Write-Host "    Removing static IPs..." -ForegroundColor Gray
        $ExistingIPs = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($IP in $ExistingIPs) {
            Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IP.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
        
        # STEP 2: Remove all existing routes (including gateway)
        Write-Host "    Removing static routes (including gateway)..." -ForegroundColor Gray
        $ExistingRoutes = Get-NetRoute -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($Route in $ExistingRoutes) {
            if ($Route.DestinationPrefix -ne "255.255.255.255/32") {
                Remove-NetRoute -InterfaceAlias $InterfaceAlias -DestinationPrefix $Route.DestinationPrefix -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        
        Start-Sleep -Milliseconds 500
        
        # STEP 3: Enable DHCP on the interface
        Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction SilentlyContinue
        
        # STEP 4: Force DHCP renewal
        Write-Host "    Requesting DHCP lease..." -ForegroundColor Gray
        ipconfig /renew "$InterfaceAlias" | Out-Null
        
        Write-Host "  [OK] DHCP Enabled and configured." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to enable DHCP: $_" -ForegroundColor Red
    }
}

# Main Logic
$State = Get-State

# Determine target interfaces
$Targets = @()
if ($Interface -eq "All") {
    $Targets += "Wi-Fi"
    $Targets += "Ethernet"
}
else {
    $Targets += $Interface
}

if ($Clear) {
    Write-Host "Clearing DHCP Override for: $Interface" -ForegroundColor Yellow
    foreach ($Target in $Targets) {
        if ($State.PSObject.Properties.Match($Target).Count) {
            $State.PSObject.Properties.Remove($Target)
            Write-Host "  Removed override for $Target."
        }
    }
    Save-State $State
    Write-Host "Done. Static IP logic will resume on next connection event." -ForegroundColor Green
}
else {
    if ($Days -le 0) {
        Write-Error "Please specify a valid number of days (e.g., -Days 1)."
        exit
    }

    $ExpiryDate = (Get-Date).AddDays($Days)
    Write-Host "Setting DHCP Override for: $Interface" -ForegroundColor Cyan
    Write-Host "  Duration: $Days days"
    Write-Host "  Expires:  $($ExpiryDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow

    foreach ($Target in $Targets) {
        # Update State
        if (-not $State.PSObject.Properties.Match($Target).Count) {
            $State | Add-Member -MemberType NoteProperty -Name $Target -Value $ExpiryDate.ToString("o")
        }
        else {
            $State.$Target = $ExpiryDate.ToString("o")
        }
        
        # Apply Immediately
        # Find actual adapter name (handle "Ethernet" vs "Ethernet 2" etc if needed, but usually alias is fixed)
        # For Ethernet, we might need to find all 802.3 adapters if "Ethernet" is generic.
        # But for simplicity, we assume standard aliases or we search.
        
        if ($Target -eq "Ethernet") {
            # Apply to ALL Ethernet adapters
            $Adapters = Get-NetAdapter | Where-Object { $_.PhysicalMediaType -eq "802.3" }
            foreach ($Adapter in $Adapters) {
                Enable-DhcpNow $Adapter.Name
            }
        }
        elseif ($Target -eq "Wi-Fi") {
            Enable-DhcpNow "Wi-Fi"
        }
    }
    
    Save-State $State
    Write-Host "Override Saved." -ForegroundColor Green
}
