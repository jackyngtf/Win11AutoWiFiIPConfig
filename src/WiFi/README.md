# WiFi IP Automation (SSID-Based)

This module provides automatic IP configuration for WiFi adapters based on the connected network's SSID.

## 🎯 Features
- **SSID-Based Static IP:** Automatically applies static IP when connecting to known corporate WiFi networks
- **Zero-DHCP Strategy:** Prevents DHCP requests on corporate networks entirely
- **Safe Mode Fallback:** Reverts to a default static IP when disconnected (prevents DHCP leaks)
- **Auto-DHCP:** Automatically switches to DHCP for non-corporate networks (home, café, hotel)
- **Event-Driven:** Triggered instantly by Windows network connection/disconnection events

## 📂 File Structure
*   `Setup-NetworkEventTrigger.ps1` - **RUN THIS FIRST.** Installs the scheduled tasks and WiFi profiles
*   `NetworkEventHandler.ps1` - The core logic script run by scheduled tasks
*   `NetworkConfig.ps1` - **EDIT THIS.** Contains all your network settings (IPs, DNS, WiFi passwords)
*   `NetworkConfig.example.ps1` - Template for configuration
*   `Uninstall-NetworkEventTrigger.ps1` - Removes the scheduled tasks

### Utility / Debug Files (Optional)
*   `Add-WiFiProfiles.ps1` - Helper script to add WiFi profiles
*   `Check-WiFiConfig.ps1` - See current IP status
*   `Apply-IP-Now.ps1` - Manually trigger the logic
*   `Connect-CompanyWiFi.ps1` - Manually connect to company network
*   `Force-DHCP-Disabled.ps1` - Emergency script to disable DHCP

## 🚀 Setup Instructions

### 1. Configure
1.  Copy `NetworkConfig.example.ps1` to `NetworkConfig.ps1`:
    ```powershell
    Copy-Item NetworkConfig.example.ps1 NetworkConfig.ps1
    ```
2.  Edit `NetworkConfig.ps1`:
    *   Add your corporate WiFi SSIDs and passwords
    *   Define the desired static IP, subnet, gateway, and DNS
    *   Configure logging preferences

### 2. Install
Run the setup script as **Administrator**:
```powershell
.\\Setup-NetworkEventTrigger.ps1
```

This will:
- Add WiFi profiles from your config
- Register "Connect" and "Disconnect" scheduled tasks
- Disable DHCP on your WiFi adapter by default

### 3. Verify
*   Connect to your corporate WiFi

*   Verify your IP address using `ipconfig`

## ⚙️ Configuration

Edit `NetworkConfig.ps1` to customize:

### Company WiFi Networks
```powershell
$CompanyWiFiNetworks = @(
    @{
        SSID        = "CorpWiFi-Office"
        StaticIP    = "10.10.216.100"
        SubnetMask  = "255.255.255.0"
        Gateway     = "10.10.216.1"
        PrimaryDNS  = "10.10.216.28"
        SecondaryDNS = "8.8.8.8"
    }
)
```

### Logging Settings
```powershell
$EnableLogging = $true
$LogRetentionDays = 7
$MaxLogSizeMB = 5
```

For advanced configuration (auto-connect, log rotation details), see [Advanced Configuration](../../docs/AdvancedConfiguration.md).

## ❓ Troubleshooting
*   **Script doesn't trigger:** Check Event Viewer for Event IDs 8001/8003/10000
*   **Wrong IP:** Verify SSID name matches exactly (case-sensitive)
*   **DHCP still active:** Check: `Get-NetIPInterface -InterfaceAlias "Wi-Fi" | Select Dhcp`
*   **Logs:** Check `NetworkEventHandler.log` for execution details

## 🗑️ Uninstalling
```powershell
.\\Uninstall-NetworkEventTrigger.ps1
```

See [Uninstallation Guide](../../docs/Uninstallation.md) for detailed removal procedures.
