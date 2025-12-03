# Ethernet IP Automation (Device-Centric)

This module provides automatic IP configuration for Ethernet adapters based on the **Device Hostname**, ensuring consistent connectivity across docks, dongles, and built-in ports.

## 🎯 Features
- **Device-Centric Static IP:** Assigns a Static IP to the *computer* (via Hostname), regardless of which Ethernet adapter (Dock/USB) is used.
- **Zero-DHCP Strategy:** Pre-disables DHCP on all Ethernet adapters to prevent accidental IP leases before the script runs.
- **VLAN Switching Support:** "Extended Validation" logic forces the Static IP first, waits for the switch to adapt, and only reverts to DHCP if both Gateway and WAN are unreachable.
- **WiFi Auto-Switch:** Automatically disables WiFi when a stable Ethernet connection is detected.
- **Conflict Resolution:** "First-Come-First-Serve" logic ensures only one adapter gets the Static IP at a time.

## 📂 File Structure
*   `Setup-EthernetEventTrigger.ps1` - **RUN THIS FIRST.** Installs the scheduled task and performs Zero-DHCP initialization.
*   `EthernetConfig.example.ps1` - **EDIT THIS.** Template for your configuration.
*   `EthernetEventHandler.ps1` - The core logic script.
*   `Uninstall-EthernetEventTrigger.ps1` - Removes the scheduled task.

## 🚀 Setup Instructions

### 1. Configure
1.  Copy `EthernetConfig.example.ps1` to `EthernetConfig.ps1`:
    ```powershell
    Copy-Item EthernetConfig.example.ps1 EthernetConfig.ps1
    ```
2.  Edit `EthernetConfig.ps1`:
    *   Add your **Computer Name** (Hostname).
    *   Define the desired IP, Subnet, Gateway, and DNS.
    *   Configure WiFi Auto-Switch settings (`$EnableWiFiAutoSwitch`).

### 2. Install
Run the setup script as **Administrator**:
```powershell
.\Setup-EthernetEventTrigger.ps1
```
*This will register the task and immediately disable DHCP on all Ethernet adapters.*

### 3. Verify
*   Plug in your Ethernet cable.
*   Check the log file: `EthernetEventHandler.log`.
*   Verify your IP address using `ipconfig`.

## ⚙️ Configuration Details

### Device Map (Hostname Based)
```powershell
$DeviceEthernetMap = @{
    "L-Jacky-01" = @{
        IPAddress   = "10.10.216.50"
        Gateway     = "10.10.216.1"
        # ...
    }
}
```

### WiFi Auto-Switch
```powershell
$EnableWiFiAutoSwitch = $true
$WanTestTargets = @("8.8.8.8", "1.1.1.1")
```

## ❓ Troubleshooting
*   **"Travel Mode" Active:** If the script reverts to DHCP in the office, check your Gateway IP and physical switch port VLAN configuration.
*   **Access Denied:** Always run setup/maintenance scripts as Administrator.
*   **Logs:** Check `logs/Ethernet-EventHandler.log` for detailed execution history.
