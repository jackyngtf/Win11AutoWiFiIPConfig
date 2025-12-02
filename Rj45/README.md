# Ethernet IP Automation (MAC-Based)

This subproject provides automatic IP configuration for Ethernet adapters based on their MAC address.

## 🎯 Features
- **MAC-Based Static IP:** Automatically assigns a specific Static IP if the adapter's MAC address matches your configuration.
- **Auto-DHCP:** Automatically reverts to DHCP for any unknown Ethernet adapter (e.g., plugging into a different network or using a USB dongle).
- **Event-Driven:** Runs instantly when a network cable is plugged in (triggered by Network Profile events).

## 📂 File Structure
*   `Setup-EthernetEventTrigger.ps1` - **RUN THIS FIRST.** Installs the scheduled task.
*   `EthernetConfig.example.ps1` - **EDIT THIS.** Template for your configuration.
*   `EthernetEventHandler.ps1` - The core logic script.
*   `Uninstall-EthernetEventTrigger.ps1` - Removes the scheduled task.

## 🚀 Setup Instructions

### 1. Configure
1.  Copy `EthernetConfig.example.ps1` to `EthernetConfig.ps1`.
    ```powershell
    Copy-Item EthernetConfig.example.ps1 EthernetConfig.ps1
    ```
2.  Edit `EthernetConfig.ps1`:
    *   Add your Ethernet adapter's MAC address.
    *   Define the desired IP, Subnet, Gateway, and DNS.
    *   (Optional) Set `$UnknownMacAction` to "DHCP" (default) or "Nothing".

### 2. Install
Run the setup script as **Administrator**:
```powershell
.\Setup-EthernetEventTrigger.ps1
```

### 3. Verify
*   Plug in your Ethernet cable.
*   Check the log file: `EthernetEventHandler.log`.
*   Verify your IP address using `ipconfig`.

## ❓ Troubleshooting
*   **Script doesn't run:** Ensure Execution Policy is set to RemoteSigned or Unrestricted.
*   **Wrong IP:** Check `EthernetConfig.ps1` to ensure the MAC address matches exactly (dashes are required, e.g., `00-11-22...`).
*   **Logs:** Check `EthernetEventHandler.log` for detailed execution history.
