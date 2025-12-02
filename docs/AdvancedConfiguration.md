# Advanced Configuration Guide

This document covers advanced configuration options for power users and IT administrators.

---

## 🔧 WiFi Auto-Connect Configuration

By default, **all WiFi profiles are set to manual connection only** to prevent signal-jumping issues and script spam. If you want to enable auto-connect for specific networks:

### Option 1: Edit Setup Script

1. Open `src/WiFi/Setup-NetworkEventTrigger.ps1`
2. Navigate to the WiFi profile creation section (around line 97)
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

### Option 2: Manual Profile Edit

Use `netsh` to enable auto-connect for existing profiles:

```powershell
netsh wlan set profileparameter name="YourNetworkName" connectionmode=auto
```

> [!WARNING]
> Enabling auto-connect can cause issues if signal is weak:
> - Repeated connect/disconnect loops
> - Script spam in logs
> - Network instability
> 
> Only enable for networks with strong, stable signals.

---

## 📋 Log Management Configuration

Both WiFi and Ethernet modules support advanced log rotation and retention. Configure in the respective `Config.ps1` files:

### Enable/Disable Logging
```powershell
$EnableLogging = $true  # Set to $false to completely disable logging
```

### Log Retention Period (Auto Cleanup)
```powershell
$LogRetentionDays = 7  # Keep logs for 7 days (1 week)
```

**Examples:**
- `7` = Keep 1 week of logs
- `30` = Keep 1 month of logs
- `0` = Keep all logs forever (no automatic cleanup)

### Maximum Log File Size (Auto Rotation)
```powershell
$MaxLogSizeMB = 5  # Rotate log when it exceeds 5 MB
```

**Examples:**
- `1` = Rotate at 1 MB
- `5` = Rotate at 5 MB (default)
- `10` = Rotate at 10 MB
- `0` = No size limit (unlimited growth)

### How Log Rotation Works

1. When `EventHandler.log` exceeds the max size, it's renamed to `EventHandler_YYYYMMDD_HHMMSS.log`
2. A new `EventHandler.log` is created
3. Old rotated logs are kept based on `$LogRetentionDays`
4. Logs older than the retention period are automatically deleted

### Recommended Settings

| Use Case | Retention Days | Max Size MB |
|----------|----------------|-------------|
| **Home/Personal** | 7 | 5 |
| **Office/Managed** | 30 | 10 |
| **Troubleshooting** | 0 (keep all) | 0 (no limit) |

---

## 🌐 Interface Priority Configuration

When both WiFi and Ethernet are connected, Windows uses interface metrics to determine routing priority. Lower metric = higher priority.

### Check Current Metrics
```powershell
Get-NetIPInterface -AddressFamily IPv4 | Select-Object InterfaceAlias, InterfaceMetric | Sort-Object InterfaceMetric
```

### Set Interface Metrics

**Prioritize Ethernet over WiFi:**
```powershell
Set-NetIPInterface -InterfaceAlias "Ethernet" -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric 50
```

**Reset to Automatic:**
```powershell
Set-NetIPInterface -InterfaceAlias "Ethernet" -AutomaticMetric Enabled
Set-NetIPInterface -InterfaceAlias "Wi-Fi" -AutomaticMetric Enabled
```

---

## 🔒 Security Considerations

### Configuration File Protection

The `NetworkConfig.ps1` and `EthernetConfig.ps1` files contain sensitive data (WiFi passwords, IP addresses). Best practices:

1. **Never commit to public repos** - Both files are in `.gitignore`
2. **Set NTFS permissions** - Restrict read access to administrators only
3. **Use example files** - Share `*.example.ps1` files with sanitized data

### Example: Restrict File Access
```powershell
$configFile = "src\WiFi\NetworkConfig.ps1"
$acl = Get-Acl $configFile
$acl.SetAccessRuleProtection($true, $false)
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")
$acl.SetAccessRule($adminRule)
Set-Acl $configFile $acl
```

---

## 📦 Portability and Deployment

### Moving the Scripts

This solution is **fully portable**. You can move the entire folder to any location:

```
C:\Scripts\NetworkAutomation\
D:\Tools\WiFiConfig\
\\SharedDrive\IT\NetworkScripts\
```

**After moving:**
1. The scripts use `$PSScriptRoot`, so they automatically detect their location
2. **Re-run the setup scripts** to update scheduled task paths:
   ```powershell
   .\src\WiFi\Setup-NetworkEventTrigger.ps1
   .\src\Ethernet\Setup-EthernetEventTrigger.ps1
   ```

### Deploying to Multiple Machines

For IT admins deploying to multiple machines:

1. **Prepare the package:**
   - Keep only essential files (`src/`, `.gitignore`, `README.md`)
   - Remove logs and temporary files
   - Use `.example.ps1` config files

2. **Deploy via:**
   - Group Policy startup scripts
   - SCCM/Intune deployment
   - Network share with scheduled task

3. **Per-machine configuration:**
   - Script the creation of `NetworkConfig.ps1` from `.example.ps1`
   - Use environment variables or AD attributes to customize IPs

**Example deployment script:**
```powershell
# Copy package
Copy-Item -Recurse "\\server\share\NetworkAutomation" "C:\Scripts\" -Force

# Generate config from template
$username = $env:USERNAME
$ipLast = ([int][char]$username[0]) + 100  # Simple IP assignment
$config = Get-Content "C:\Scripts\NetworkAutomation\src\WiFi\NetworkConfig.example.ps1" -Raw
$config = $config -replace '192.168.10.100', "192.168.10.$ipLast"
$config | Set-Content "C:\Scripts\NetworkAutomation\src\WiFi\NetworkConfig.ps1"

# Run setup
& "C:\Scripts\NetworkAutomation\src\WiFi\Setup-NetworkEventTrigger.ps1"
```

---

## 🔍 Debugging and Diagnostics

### Enable Verbose Logging

Temporarily modify the handler scripts to add verbose output:

```powershell
# At the top of EthernetEventHandler.ps1 or NetworkEventHandler.ps1
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
```

### Manual Script Execution

Test scripts manually to bypass event triggers:

**WiFi:**
```powershell
.\src\WiFi\NetworkEventHandler.ps1 -TriggerEvent "Auto"
```

**Ethernet:**
```powershell
.\src\Ethernet\EthernetEventHandler.ps1
```

### Check Scheduled Tasks

View task status:
```powershell
Get-ScheduledTask -TaskPath "\WiFi-AutoConfig\" | Format-List *
Get-ScheduledTask -TaskPath "\Ethernet-AutoConfig\" | Format-List *
```

View task history:
```powershell
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=100,102,103,107} -MaxEvents 20
```

---

## 🧪 Testing Scenarios

### Test WiFi Switching

1. Connect to corporate WiFi → Verify static IP
2. Disconnect → Verify safe mode IP
3. Connect to home WiFi → Verify DHCP
4. Check logs for each transition

### Test Ethernet Detection

1. Unplug cable → Check logs
2. Plug in cable → Verify IP assignment
3. Check `EthernetEventHandler.log` for errors

### Test Conflict Scenarios

1. Connect both WiFi and Ethernet to same subnet
2. Check routing table: `route print`
3. Verify interface metrics: `Get-NetIPInterface`
4. Test connectivity: `Test-NetConnection google.com`
