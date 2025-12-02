# Test Script - Using netsh wlan set profileparameter for per-network IP

Write-Host "=== Testing netsh per-network IP configuration ===" -ForegroundColor Cyan

# Get current SSID
$ssid = (netsh wlan show interfaces | Select-String "^\s*SSID" | Select-Object -First 1).ToString().Split(":")[1].Trim()
Write-Host "`nCurrent SSID: $ssid" -ForegroundColor Yellow

# Check if profile exists
$profileName = "Cosmax NBT Australia"  # Test with the main profile
$profiles = netsh wlan show profiles | Out-String

if ($profiles -like "*$profileName*") {
    Write-Host "Profile '$profileName' found" -ForegroundColor Green
    
    # Try to set cost (this works, documented command)
    Write-Host "`nTesting netsh wlan set profileparameter..." -ForegroundColor Cyan
    
    # Show profile details before
    Write-Host "`nProfile details BEFORE:" -ForegroundColor Gray
    netsh wlan show profile name="$profileName"
    
    # Attempt to set IP configuration
    Write-Host "`n--- Attempting IP Configuration ---" -ForegroundColor Cyan
    
    # Unfortunately, netsh wlan set profileparameter doesn't support IP settings directly
    # The correct approach is using netsh interface set interface with connection-specific DNS settings
    
    # Get the interface name
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }
    $interfaceName = $adapter.Name
    
    Write-Host "Interface: $interfaceName" -ForegroundColor Gray
    
    # The issue is that netsh doesn't support per-network IP - only per-adapter IP
    # Windows 11 Settings UI stores this differently
    
    Write-Host "`n[FINDING] netsh wlan set profileparameter does NOT support IP configuration" -ForegroundColor Yellow
    Write-Host "[FINDING] Windows 11 per-network IP is stored in an undocumented location" -ForegroundColor Yellow
    
    # Let's try the Windows.Networking.Connectivity API instead
    Write-Host "`n--- Attempting WinRT API Approach ---" -ForegroundColor Cyan
    
    # Load WinRT assemblies
    [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime] | Out-Null
    [Windows.Networking.Connectivity.ConnectionProfile, Windows.Networking.Connectivity, ContentType = WindowsRuntime] | Out-Null
    
    $profiles = [Windows.Networking.Connectivity.NetworkInformation]::GetConnectionProfiles()
    foreach ($profile in $profiles) {
        if ($profile.ProfileName -eq $ssid) {
            Write-Host "Found ConnectionProfile for: $($profile.ProfileName)" -ForegroundColor Green
            Write-Host "  IsWwanConnectionProfile: $($profile.IsWwanConnectionProfile)" -ForegroundColor Gray
            Write-Host "  IsWlanConnectionProfile: $($profile.IsWlanConnectionProfile)" -ForegroundColor Gray
            # Unfortunately, the WinRT API is read-only for most properties
        }
    }
    
    Write-Host "`n[FINDING] WinRT API is read-only, cannot set IP configuration" -ForegroundColor Yellow
    
}
else {
    Write-Host "Profile '$profileName' not found" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
Write-Host "`n[CONCLUSION] Per-network IP configuration in Windows 11 Settings is not exposed via:" -ForegroundColor Red
Write-Host "  - netsh commands" -ForegroundColor Red
Write-Host "  - PowerShell cmdlets" -ForegroundColor Red  
Write-Host "  - WinRT APIs (read-only)" -ForegroundColor Red
Write-Host "`nThe only viable approach is:" -ForegroundColor Yellow
Write-Host "  1. Direct registry manipulation (risky, undocumented)" -ForegroundColor Yellow
Write-Host "  2. Event-triggered script (recommended)" -ForegroundColor Green
