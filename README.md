# Automatic WiFi IP Configuration for Windows 11

This solution automatically manages your IP configuration based on the connected WiFi network.
- **Company Networks:** Automatically applies a Static IP (No DHCP requests sent).
- **Other Networks:** Automatically switches to DHCP (Automatic IP).
- **Instant Response:** Uses event triggers to apply settings immediately upon connection or disconnection.

## 🎯 Why This Solution?

This solution was implemented to address critical IT infrastructure challenges:

### **DHCP Pool Conservation**
- **Problem:** Company WiFi networks using DHCP exhaust the available IP pool quickly
- **Solution:** Static IPs for employees prevent DHCP lease consumption
- **Benefit:** DHCP pool remains available for guests and temporary devices

### **Network Segmentation & Management**
- **Problem:** Employees were getting IPs from the general DHCP pool (e.g., `192.168.1.0/24`)
- **Solution:** All company devices now use a dedicated static IP range (e.g., `192.168.10.0/24`)
- **Benefits:**
  - **Easier troubleshooting:** IT can instantly identify employee devices by IP range
  - **Better security:** Network policies can target the static range specifically
  - **Simplified monitoring:** Traffic analysis and bandwidth management by subnet
  - **Consistent addressing:** Employees always get the same IP configuration

### **IT Admin Perspective**
From an IT administration standpoint, this approach provides:
- ✅ **Predictable IP allocation** - No more random DHCP assignments
- ✅ **Reduced DHCP server load** - Fewer lease requests and renewals
- ✅ **Faster network diagnostics** - IP range immediately identifies device type
- ✅ **Centralized control** - Update all employee IPs by editing one config file

### **Seamless Remote Work Experience**
When employees work from home or travel:
- **Automatic DHCP switching:** Connecting to non-company WiFi (home, hotel, café) automatically enables DHCP
- **Zero user intervention:** No manual configuration needed - it "just works"
- **No IT support tickets:** Eliminates help desk calls for "can't connect at home" issues
- **Instant connectivity:** Users get network access immediately, no waiting for IT response
- **Business continuity:** Employees remain productive regardless of location

This intelligent switching ensures users have the right configuration for every environment - static IP in the office, DHCP everywhere else.



## 📂 File Structure

### **Essential Files (Keep these)**
*   `Setup-NetworkEventTrigger.ps1` - **RUN THIS FIRST.** Installs the scheduled tasks and WiFi profiles.
*   `NetworkEventHandler.ps1` - The core logic script run by the scheduled task.
*   `NetworkConfig.ps1` - **EDIT THIS.** Contains all your network settings (IPs, DNS, WiFi passwords).
*   `Add-WiFiProfiles.ps1` - Helper script to add WiFi profiles (called by Setup).
*   `Uninstall-NetworkEventTrigger.ps1` - Removes the scheduled tasks.

### **Utility / Debug Files (Optional)**
*   `Check-WiFiConfig.ps1` - Run this to see your current IP status.
*   `Apply-IP-Now.ps1` - Manually triggers the logic without waiting for an event.
*   `Connect-CompanyWiFi.ps1` - Manually connects to a company network (Safe Mode).
*   `Force-DHCP-Disabled.ps1` - Emergency script to kill DHCP.
*   `NetworkEventHandler.log` - Log file created during execution.

---

## ⚙️ Configuration

All settings are stored in **`NetworkConfig.ps1`**. You can edit this file to change:

1.  **Default Static IP Settings:**
    ```powershell
    $DefaultSubnetMask = "255.255.255.0"
    $DefaultPrimaryDNS = "192.168.10.1"    # Your internal DNS
    $DefaultGateway = "192.168.10.1"       # Your gateway
    $DefaultStaticIP = "192.168.10.100"    # Your static IP
    ```

2.  **Company WiFi Networks:**
    Add or remove networks in the `$CompanyWiFiNetworks` list.
    ```powershell
    @{
        Name     = "Company-WiFi-Main"     # WiFi Profile Name
        SSID     = "Company-WiFi-SSID"     # SSID to match
        Password = "YourPasswordHere"      # WiFi Password
    }
    ```

### 🔧 Advanced Configuration

#### Enable Auto-Connect for WiFi Profiles

By default, **all WiFi profiles are set to manual connection only** to prevent signal-jumping issues and script spam. If you want to enable auto-connect for specific networks:

**Option 1: Edit Setup-NetworkEventTrigger.ps1**
1. Open `Setup-NetworkEventTrigger.ps1`
2. Go to **Line 97**
3. Change:
   ```powershell
   $autoConnect = $false  # Manual connection only
   ```
   To:
   ```powershell
   $autoConnect = ($network.SSID -eq "Your-Network-Name")
   ```
4. Replace `"Your-Network-Name"` with the SSID you want to auto-connect to
5. Re-run the setup script

**Option 2: Edit Add-WiFiProfiles.ps1**
1. Open `Add-WiFiProfiles.ps1`
2. Go to **Line 110**
3. Make the same change as above
4. Run `Add-WiFiProfiles.ps1` to update profiles

> [!WARNING]
> Enabling auto-connect can cause issues if signal is weak:
> - Repeated connect/disconnect loops
> - Script spam in logs
> - Network instability
> 
> Only enable for networks with strong, stable signals.

### 📋 Log Management

The script automatically manages log files to prevent unlimited growth. Configure logging behavior in **`NetworkConfig.ps1`**:

**1. Enable/Disable Logging**
```powershell
$EnableLogging = $true  # Set to $false to completely disable logging
```

**2. Log Retention Period (Automatic Cleanup)**
```powershell
$LogRetentionDays = 7  # Keep logs for 7 days (1 week)
# Examples:
#   7  = Keep 1 week of logs
#   30 = Keep 1 month of logs
#   0  = Keep all logs forever (no automatic cleanup)
```

**3. Maximum Log File Size (Automatic Rotation)**
```powershell
$MaxLogSizeMB = 5  # Rotate log when it exceeds 5 MB
# Examples:
#   1  = Rotate at 1 MB
#   5  = Rotate at 5 MB (default)
#   10 = Rotate at 10 MB
#   0  = No size limit (unlimited growth)
```

**How Log Rotation Works:**
- When `NetworkEventHandler.log` exceeds the max size, it's automatically renamed to `NetworkEventHandler_YYYYMMDD_HHMMSS.log`
- A new `NetworkEventHandler.log` is created
- Old rotated logs are kept based on `$LogRetentionDays` setting
- Logs older than the retention period are automatically deleted

**Recommended Settings:**
- **Home/Personal Use:** `$LogRetentionDays = 7`, `$MaxLogSizeMB = 5`
- **Office/Managed:** `$LogRetentionDays = 30`, `$MaxLogSizeMB = 10`
- **Troubleshooting:** `$LogRetentionDays = 0`, `$MaxLogSizeMB = 0` (keep everything)

---

## 🚀 Installation & Setup

### 1. Clone the Repository
```powershell
git clone https://github.com/yourusername/your-repo.git
cd your-repo
```

### 2. Configure Network Settings (CRITICAL)
This project uses a configuration file to store your sensitive network details (SSIDs, Passwords, IPs).
**You must create this file before running the scripts.**

1.  Copy the example configuration:
    ```powershell
    Copy-Item NetworkConfig.example.ps1 NetworkConfig.ps1
    ```
2.  Edit `NetworkConfig.ps1` with your actual details:
    *   **CompanyWiFiNetworks**: Add your company SSIDs and passwords.
    *   **DefaultStaticIP**: Set your desired static IP.
    *   **DefaultGateway**: Set your network gateway.
    *   **DefaultPrimaryDNS**: Set your internal DNS server.

> [!IMPORTANT]
> `NetworkConfig.ps1` is ignored by git to keep your secrets safe. Never commit this file to a public repository.

### 3. Run the Setup Script
1.  Open PowerShell as **Administrator**.
2.  Run the setup script:
    ```powershell
    .\Setup-NetworkEventTrigger.ps1
    ```
    *   This will add WiFi profiles from your config.
    *   It will register the "Connect" and "Disconnect" scheduled tasks.
    *   It will disable DHCP on your WiFi adapter by default.

## 🗑️ Uninstalling

To remove the automation and restore default Windows settings:

1.  Open PowerShell as **Administrator**.
2.  Run the uninstall script:
    ```powershell
    .\Uninstall-NetworkEventTrigger.ps1
    ```
3.  This will:
    *   Remove the "WiFi-AutoConfig" scheduled tasks.
    *   Execute a **safe DHCP reset sequence**:
        1. **Disable** Wi-Fi adapter (forces immediate disconnect)
        2. **Reset** to DHCP (while offline - no risk of DHCP lease)
        3. Wait 2 seconds (clean state)
        4. **Re-enable** Wi-Fi adapter

**Final State After Uninstall:**
- ✅ Wi-Fi adapter is **ON** (enabled)
- ✅ **NOT connected** to any network
- ✅ DHCP enabled (automatic IP)
- ✅ No risk of DHCP lease consumption

> [!NOTE]
> **Why this sequence?**
> The disable→reset→enable sequence ensures that when we switch from Static to DHCP, the adapter is offline. This prevents Windows from immediately requesting a DHCP lease if you were connected to a company network.
> 
> Since auto-connect is disabled for company networks, the adapter will not reconnect without manual intervention.




## ❓ Troubleshooting

**Issue: Script doesn't run or "Access Denied"**
*   Ensure you are running PowerShell as **Administrator**.
*   Check execution policy: `Set-ExecutionPolicy RemoteSigned -Scope Process`

**Issue: "You cannot run this script on the current system" (UnauthorizedAccess)**
*   **Error:**
    ```text
    CategoryInfo          : SecurityError: (:) [], PSSecurityException
    FullyQualifiedErrorId : UnauthorizedAccess
    ```
*   **Solution:** PowerShell execution policy is blocking the script. Run this command to allow scripts:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
    (Select 'Y' or 'A' to confirm if prompted)

**Issue: Wi-Fi disconnects repeatedly**
*   If you enabled "Auto-Connect" for a weak signal, disable it in `Setup-NetworkEventTrigger.ps1` or `Add-WiFiProfiles.ps1`.

**Issue: IP didn't change after connecting**
*   Check the log file: `NetworkEventHandler.log`.
*   Run `.\Check-WiFiConfig.ps1` to see current status.
*   Run `.\Apply-IP-Now.ps1` to force a refresh.

**Issue: "No Company Network Found" but I am at the office**
*   Ensure the SSID in `NetworkConfig.ps1` matches exactly (case-sensitive).

## 📦 Portability

This script is **fully portable**. You can move the entire folder to any location (e.g., `C:\Scripts\WiFiConfig`).
*   The scripts use relative paths (`$PSScriptRoot`), so they automatically detect where they are running from.
*   Just remember to re-run `Setup-NetworkEventTrigger.ps1` if you move the folder, so the Scheduled Tasks are updated with the new path.
