# Uninstallation Guide

This document provides detailed information about safely uninstalling the Network Automation Suite.

---

## 🗑️ WiFi Module Uninstallation

### Quick Uninstall

1. Open PowerShell as **Administrator**
2. Navigate to the WiFi module:
   ```powershell
   cd C:\Scripts\NetworkAutomation\src\WiFi
   ```
3. Run the uninstall script:
   ```powershell
   .\Uninstall-NetworkEventTrigger.ps1
   ```

### What Happens During Uninstall

The uninstall script performs the following actions:

1. **Removes Scheduled Tasks:**
   - Deletes `WiFi-AutoConfig-Connect` task
   - Deletes `WiFi-AutoConfig-Disconnect` task
   - Task path: `\WiFi-AutoConfig\`

2. **Executes Safe DHCP Reset Sequence:**
   1. **Disable** Wi-Fi adapter (forces immediate disconnect)
   2. **Reset** to DHCP (while offline - no risk of DHCP lease)
   3. Wait 2 seconds (clean state)
   4. **Re-enable** Wi-Fi adapter

### Final State After Uninstall

- ✅ Wi-Fi adapter is **ON** (enabled)
- ✅ **NOT connected** to any network
- ✅ DHCP enabled (automatic IP)
- ✅ No risk of DHCP lease consumption

> [!NOTE]
> **Why this sequence?**
> 
> The disable→reset→enable sequence ensures that when we switch from Static to DHCP, the adapter is offline. This prevents Windows from immediately requesting a DHCP lease if you were connected to a company network.
> 
> Since auto-connect is disabled for company networks, the adapter will not reconnect without manual intervention.

### Verifying WiFi Uninstall

```powershell
# Check scheduled tasks are removed
Get-ScheduledTask -TaskPath "\WiFi-AutoConfig\" -ErrorAction SilentlyContinue

# Check DHCP is enabled
Get-NetIPInterface -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 | Select-Object Dhcp

# Should return: Dhcp = Enabled
```

---

## 🔌 Ethernet Module Uninstallation

### Quick Uninstall

1. Open PowerShell as **Administrator**
2. Navigate to the Ethernet module:
   ```powershell
   cd C:\Scripts\NetworkAutomation\src\Ethernet
   ```
3. Run the uninstall script:
   ```powershell
   .\Uninstall-EthernetEventTrigger.ps1
   ```

### What Happens During Uninstall

1. **Removes Scheduled Task:**
   - Deletes `Ethernet-AutoConfig` task
   - Task path: `\Ethernet-AutoConfig\`

2. **Resets Network Configuration:**
   - Removes all static IP addresses
   - Removes all static routes
   - Enables DHCP
   - Resets DNS to automatic

### Verifying Ethernet Uninstall

```powershell
# Check scheduled task is removed
Get-ScheduledTask -TaskName "Ethernet-AutoConfig" -ErrorAction SilentlyContinue

# Check DHCP is enabled
Get-NetIPInterface -InterfaceAlias "Ethernet" -AddressFamily IPv4 | Select-Object Dhcp

# Should return: Dhcp = Enabled
```

---

## 🔄 Complete System Uninstall

To completely remove all components:

### Step 1: Uninstall Modules

```powershell
# WiFi
cd C:\Scripts\NetworkAutomation\src\WiFi
.\Uninstall-NetworkEventTrigger.ps1

# Ethernet
cd C:\Scripts\NetworkAutomation\src\Ethernet
.\Uninstall-EthernetEventTrigger.ps1
```

### Step 2: Remove WiFi Profiles (Optional)

If you want to remove the company WiFi profiles added by the setup:

```powershell
# List all WiFi profiles
netsh wlan show profiles

# Delete specific profile
netsh wlan delete profile name="CompanyWiFi-SSID"
```

### Step 3: Delete Script Files (Optional)

```powershell
# Remove the entire directory
Remove-Item -Path "C:\Scripts\NetworkAutomation" -Recurse -Force
```

> [!CAUTION]
> Make sure you have a backup of your `NetworkConfig.ps1` and `EthernetConfig.ps1` files before deleting, in case you need to reinstall later.

---

## 🔧 Partial Uninstall Scenarios

### Uninstall WiFi Only (Keep Ethernet)

```powershell
cd C:\Scripts\NetworkAutomation\src\WiFi
.\Uninstall-NetworkEventTrigger.ps1
```

Ethernet automation will continue to function normally.

### Uninstall Ethernet Only (Keep WiFi)

```powershell
cd C:\Scripts\NetworkAutomation\src\Ethernet
.\Uninstall-EthernetEventTrigger.ps1
```

WiFi automation will continue to function normally.

---

## ⚠️ Troubleshooting Uninstall Issues

### Issue: Uninstall script fails

**Symptoms:**
- Error messages during uninstall
- Scheduled tasks still present
- DHCP not enabled

**Solutions:**

1. **Run as Administrator:**
   ```powershell
   # Verify you're running as admin
   $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
   Write-Host "Running as Admin: $isAdmin"
   ```

2. **Manually remove scheduled tasks:**
   ```powershell
   # WiFi
   Unregister-ScheduledTask -TaskName "WiFi-AutoConfig-Connect" -Confirm:$false
   Unregister-ScheduledTask -TaskName "WiFi-AutoConfig-Disconnect" -Confirm:$false

   # Ethernet
   Unregister-ScheduledTask -TaskName "Ethernet-AutoConfig" -Confirm:$false
   ```

3. **Manually enable DHCP:**
   ```powershell
   # WiFi
   Set-NetIPInterface -InterfaceAlias "Wi-Fi" -Dhcp Enabled
   Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses

   # Ethernet
   Set-NetIPInterface -InterfaceAlias "Ethernet" -Dhcp Enabled
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses
   ```

### Issue: Adapter won't connect after uninstall

**Solution:**

1. **Reset network adapter:**
   ```powershell
   # Disable and re-enable
   Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false
   Start-Sleep -Seconds 3
   Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false
   ```

2. **Reset network stack:**
   ```powershell
   netsh winsock reset
   netsh int ip reset
   # Restart required
   ```

3. **Reconnect manually:**
   - Open WiFi settings
   - Select network
   - Click "Connect"

---

## 🔄 Reinstallation After Uninstall

If you need to reinstall after uninstalling:

1. **Wait 5 minutes** after uninstall (allows Windows to fully reset network state)
2. **Verify network adapters are working normally:**
   ```powershell
   Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}
   ```
3. **Run setup scripts again:**
   ```powershell
   .\src\WiFi\Setup-NetworkEventTrigger.ps1
   .\src\Ethernet\Setup-EthernetEventTrigger.ps1
   ```

---

## 📝 Uninstall Checklist

Use this checklist to ensure complete removal:

### WiFi Module
- [ ] Uninstall script executed successfully
- [ ] Scheduled tasks removed
- [ ] DHCP enabled
- [ ] WiFi adapter functional
- [ ] Can connect to networks manually

### Ethernet Module
- [ ] Uninstall script executed successfully
- [ ] Scheduled task removed
- [ ] DHCP enabled
- [ ] Ethernet adapter functional
- [ ] Can connect with cable

### Optional Cleanup
- [ ] WiFi profiles removed
- [ ] Script directory deleted
- [ ] Configuration backups saved
- [ ] Log files archived (if needed)

---

## 🆘 Emergency Reset

If uninstall scripts fail and you need to manually reset everything:

```powershell
# NUCLEAR OPTION - Use only if uninstall scripts fail

# Remove all tasks
Get-ScheduledTask | Where-Object {$_.TaskPath -like "*AutoConfig*"} | Unregister-ScheduledTask -Confirm:$false

# Reset all network adapters to DHCP
Get-NetAdapter -Physical | ForEach-Object {
    $name = $_.Name
    Set-NetIPInterface -InterfaceAlias $name -Dhcp Enabled -ErrorAction SilentlyContinue
    Set-DnsClientServerAddress -InterfaceAlias $name -ResetServerAddresses -ErrorAction SilentlyContinue
}

# Restart network stack
Restart-Service -Name "NetMan" -Force
```

**After emergency reset:**
- Restart the computer
- Verify network connectivity
- Manually reconnect to WiFi if needed
