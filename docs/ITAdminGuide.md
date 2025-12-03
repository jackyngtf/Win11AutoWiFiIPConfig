# IT Administrator Guide

This document provides IT administrators with architectural insights, deployment strategies, and management best practices.

---

## 🏗️ Solution Architecture

### Why Static IPs for Corporate Networks?

This solution addresses critical IT infrastructure challenges:

#### DHCP Pool Conservation
- **Problem:** Company WiFi networks using DHCP exhaust available IP pools quickly
- **Solution:** Static IPs for employees prevent DHCP lease consumption
- **Benefit:** DHCP pool remains available for guests and temporary devices

#### Network Segmentation & Management
- **Problem:** Employees getting IPs from the general DHCP pool (e.g., `192.168.1.0/24`)
- **Solution:** Company devices use a dedicated static IP range (e.g., `10.10.216.0/24`)
- **Benefits:**
  - ✅ **Easier troubleshooting:** IT can instantly identify employee devices by IP range
  - ✅ **Better security:** Network policies can target the static range specifically
  - ✅ **Simplified monitoring:** Traffic analysis and bandwidth management by subnet
  - ✅ **Consistent addressing:** Employees always get the same IP configuration

#### IT Admin Perspective
From an IT administration standpoint, this approach provides:
- ✅ **Predictable IP allocation** - No more random DHCP assignments
- ✅ **Reduced DHCP server load** - Fewer lease requests and renewals
- ✅ **Faster network diagnostics** - IP range immediately identifies device type
- ✅ **Centralized control** - Update all employee IPs by editing one config file

---

## 🌍 Remote Work Support

### Seamless Remote Work Experience

When employees work from home or travel:
- **Automatic DHCP switching:** Connecting to non-company WiFi (home, hotel, café) automatically enables DHCP
- **Zero user intervention:** No manual configuration needed - it "just works"
- **No IT support tickets:** Eliminates help desk calls for "can't connect at home" issues
- **Instant connectivity:** Users get network access immediately, no waiting for IT response
- **Business continuity:** Employees remain productive regardless of location

This intelligent switching ensures users have the right configuration for every environment - static IP in the office, DHCP everywhere else.

---

## 📊 Deployment Models

### Small Office (1-50 Users)

**Recommended Approach:** Manual deployment with shared config

1. **Prepare master package:**
   ```
   \\fileserver\IT\NetworkAutomation\
   ├── src\
   ├── README.md
   └── NetworkConfig.ps1  (centralized config)
   ```

2. **User instructions:**
   - Copy folder to `C:\Scripts\NetworkAutomation`
   - Run setup scripts as Administrator
   - No per-user customization needed

**IP Assignment Strategy:**
- Use sequential static IPs (`10.10.216.100`, `.101`, `.102`, etc.)
- Document assignments in spreadsheet

### Medium Office (50-500 Users)

**Recommended Approach:** GPO-based deployment

1. **Create deployment package:**
   - Store in NETLOGON or DFS share
   - Create wrapper script for configuration

2. **Group Policy:**
   - Computer Configuration → Scripts → Startup
   - Run deployment script silently

3. **IP Assignment:**
   - Use AD attributes or computer name patterns
   - Generate `NetworkConfig.ps1` dynamically

**Example GPO startup script:**
```powershell
$source = "\\domain\netlogon\NetworkAutomation"
$dest = "C:\Scripts\NetworkAutomation"

# Copy package
Copy-Item $source $dest -Recurse -Force

# Generate config based on computer name
$computerNum = $env:COMPUTERNAME -replace '[^0-9]'
$ip = "10.10.216.$computerNum"

$config = @"
`$DefaultStaticIP = "$ip"
`$DefaultGateway = "10.10.216.1"
`$DefaultPrimaryDNS = "10.10.216.28"
# ... rest of config
"@

$config | Set-Content "$dest\src\WiFi\NetworkConfig.ps1"

# Run setup
& "$dest\src\WiFi\Setup-NetworkEventTrigger.ps1"
```

### Enterprise (500+ Users)

**Recommended Approach:** SCCM/Intune deployment with dynamic config

1. **Create SCCM/Intune package:**
   - Application deployment type
   - Detection method: Scheduled task existence

2. **IP Management:**
   - Integrate with IPAM (IP Address Management) system
   - Use database lookup for IP assignments
   - Reserve IP ranges for different departments

3. **Configuration Management:**
   - Store configs in database
   - Scripts query database for settings
   - Centralized updates without redeployment

**Example database-driven config:**
```powershell
# EthernetConfig.ps1 (dynamic version)
$hostname = $env:COMPUTERNAME
$apiUrl = "https://ipam.company.com/api/config?hostname=$hostname"
$config = Invoke-RestMethod -Uri $apiUrl

$DeviceEthernetMap = @{
    $hostname = @{
        IPAddress = $config.IP
        SubnetMask = $config.Subnet
        Gateway = $config.Gateway
        DNS = $config.DNS
        Description = "Managed Device: $hostname"
    }
}
```

---

## 🔐 Security Best Practices

### Network Security

1. **Static IP Range Isolation:**
   ```
   ACL: Block 10.10.216.0/24 → Guest VLAN
   ACL: Allow 10.10.216.0/24 → Corporate Resources
   ```

2. **DNS Security:**
   - Use internal DNS for static range
   - Filter external DNS for DHCP range

3. **Audit Logging:**
   - Monitor scheduled task executions
   - Alert on unauthorized config changes

### Credential Management

**Don't store WiFi passwords in scripts!**

Instead, use Windows Credential Manager:

```powershell
# Store password securely
cmdkey /generic:"CompanyWiFi-PSK" /user:"WiFi" /pass:"YourPassword"

# Retrieve in script
$cred = cmdkey /list:"CompanyWiFi-PSK"
```

Or use certificate-based authentication (WPA2-Enterprise).

---

## 📈 Monitoring and Maintenance

### Key Metrics to Track

1. **Deployment Status:**
   - Number of machines with scripts installed
   - Success rate of IP assignments
   - Scheduled task execution frequency

2. **Network Health:**
   - DHCP pool utilization before/after deployment
   - Static IP conflicts (should be zero)
   - User connectivity issues

3. **Script Performance:**
   - Average execution time
   - Error rates in logs
   - Log file sizes

### Monitoring Script Example

```powershell
# Check-NetworkAutomationStatus.ps1
$computers = Get-ADComputer -Filter * -SearchBase "OU=Workstations,DC=company,DC=com"

$results = foreach ($computer in $computers) {
    $session = New-PSSession -ComputerName $computer.Name -ErrorAction SilentlyContinue
    if ($session) {
        Invoke-Command -Session $session -ScriptBlock {
            [PSCustomObject]@{
                Computer = $env:COMPUTERNAME
                TaskInstalled = $null -ne (Get-ScheduledTask -TaskName "WiFi-AutoConfig*" -ErrorAction SilentlyContinue)
                CurrentIP = (Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4).IPAddress
                IsDHCP = (Get-NetIPInterface -InterfaceAlias "Wi-Fi").Dhcp
            }
        }
        Remove-PSSession $session
    }
}

$results | Export-Csv "NetworkAutomation-Status.csv" -NoTypeInformation
```

---

## 🛠️ Troubleshooting for IT Admins

### Common Deployment Issues

#### Issue: Script not running on some machines

**Check:**
1. Execution policy: `Get-ExecutionPolicy -List`
2. Scheduled task permissions: Task must run as SYSTEM or Admin
3. Event Viewer: Application and Services Logs → Microsoft → Windows → TaskScheduler

**Fix:**
```powershell
# Set execution policy via GPO
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Verify task exists
Get-ScheduledTask -TaskPath "\WiFi-AutoConfig\" -TaskName "*"
```

#### Issue: IP conflicts on the network

**Check:**
```powershell
# Scan for duplicate IPs
$range = 100..150
foreach ($i in $range) {
    $ip = "10.10.216.$i"
    $result = Test-Connection -ComputerName $ip -Count 1 -Quiet
    if ($result) {
        $mac = (arp -a $ip | Select-String "([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})").Matches.Value
        Write-Output "$ip is active (MAC: $mac)"
    }
}
```

**Fix:**
- Update IPAM database
- Reassign conflicting IPs
- Add IP conflict detection to scripts

#### Issue: Users can't connect at home

**Check logs on user's machine:**
```powershell
Get-Content "C:\Scripts\NetworkAutomation\logs\WiFi-NetworkEventHandler.log" -Tail 50
```

**Common causes:**
- DHCP not being enabled for non-company SSIDs
- WiFi profile issues
- Firewall blocking script execution

---

## 📋 Change Management

### Making Network-Wide Changes

1. **Update config template:**
   - Modify `NetworkConfig.example.ps1`
   - Test thoroughly on pilot group

2. **Deploy to production:**
   - Option A: Update central config share (small offices)
   - Option B: Push via GPO/SCCM (enterprises)
   - Option C: Use database backend (dynamic configs)

3. **Verify deployment:**
   - Check monitoring dashboard
   - Review error logs
   - Spot-check random machines

### Example: Change Gateway for All Users

**Small office (shared config):**
```powershell
# Update central config
$configPath = "\\fileserver\IT\NetworkAutomation\src\WiFi\NetworkConfig.ps1"
(Get-Content $configPath) -replace 'DefaultGateway = "10.10.216.1"', 'DefaultGateway = "10.10.216.254"' | Set-Content $configPath

# Force users to copy new config
Send-MailMessage -To "all-staff@company.com" -Subject "Network Config Update" -Body "Please run: Copy-Item \\fileserver\IT\NetworkAutomation\src\WiFi\NetworkConfig.ps1 C:\Scripts\NetworkAutomation\src\WiFi\ -Force"
```

**Enterprise (dynamic config):**
```sql
-- Update database
UPDATE NetworkConfigs
SET Gateway = '10.10.216.254'
WHERE Subnet = '10.10.216.0/24';

-- Scripts will pick up change on next execution
```

---

## 🔄 Upgrade Path

### From Manual IP to This Solution

1. **Document current assignments:**
   ```powershell
   Get-ADComputer -Filter * | ForEach-Object {
       $ip = (Test-Connection -ComputerName $_.Name -Count 1).IPV4Address.IPAddressToString
       [PSCustomObject]@{
           Computer = $_.Name
           CurrentIP = $ip
       }
   } | Export-Csv "CurrentIPs.csv"
   ```

2. **Match IPs to MACs:**
   - WiFi: SSID-based (no change needed)
   - Ethernet: Use current IP in config

3. **Deploy incrementally:**
   - Start with IT department
   - Expand to pilot group
   - Roll out department by department

---

## 📞 Support Escalation

### User-Facing Issues

**Tier 1 Support:**
- Check if scripts are installed
- Verify WiFi connection
- Review last 10 log entries

**Tier 2 Support:**
- Analyze full logs
- Test manual script execution
- Check for conflicts

**Tier 3 Support (IT Admin):**
- Modify configurations
- Update scheduled tasks
- Database/IPAM integration issues
