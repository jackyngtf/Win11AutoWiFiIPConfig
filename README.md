# Network Automation Suite 🌐

**Intelligent, Event-Driven Network Configuration for Windows**

A professional PowerShell automation suite that eliminates manual IP configuration for corporate environments. This project provides intelligent, automated IP management for both WiFi and Ethernet adapters, ensuring seamless connectivity without DHCP conflicts or manual intervention.

---

## 🎯 Why This Solution?

### DHCP Pool Conservation
- Corporate networks often have limited DHCP pools
- Manual static IPs are error-prone and time-consuming
- This suite automatically assigns static IPs based on network context (SSID for WiFi, MAC for Ethernet)

### Zero-DHCP Strategy
- Prevents DHCP requests on corporate networks entirely
- No race conditions between script execution and Windows DHCP
- Guarantees that corporate devices never consume DHCP leases

### Seamless Remote Work Experience
- Automatically detects corporate WiFi SSIDs
- Applies correct static IP configurations instantly
- Reverts to DHCP when connecting to home/public networks

---

## 🚀 Features

### 📶 WiFi Automation (`src/WiFi`)
- **SSID-Based Configuration**: Automatically applies static IPs when connecting to known corporate SSIDs
- **Zero-DHCP Mode**: DHCP remains disabled on the adapter; uses `netsh` to request IPs for non-corporate networks
- **Safe Mode Fallback**: Reverts to a default static IP when disconnected (prevents DHCP leaks during reconnection)
- **Event-Driven**: Triggered by Windows network connection/disconnection events (Event IDs 8001, 8003, 10000)
- **Log Rotation**: Built-in logging with automatic size-based rotation and retention policies

### 🔌 Ethernet Automation (`src/Ethernet`)
- **MAC-Based Configuration**: Assigns static IPs based on the physical adapter's MAC address
- **Plug-and-Play**: Automatically detects when an Ethernet cable is connected
- **Auto-DHCP for Unknown Adapters**: Reverts to DHCP for unrecognized MAC addresses (e.g., USB dongles, visitor machines)
- **Conflict Prevention**: Intelligently removes old routes and IPs before applying new settings
- **Event-Driven**: Triggered by Network Profile events (Event ID 10000)

---

## 📂 Project Structure

```
/
├── src/
│   ├── WiFi/                  # WiFi automation module
│   │   ├── NetworkEventHandler.ps1
│   │   ├── NetworkConfig.ps1
│   │   └── Setup-NetworkEventTrigger.ps1
│   ├── Ethernet/              # Ethernet automation module
│   │   ├── EthernetEventHandler.ps1
│   │   ├── EthernetConfig.ps1
│   │   ├── Setup-EthernetEventTrigger.ps1
│   │   └── README.md
│   └── GUI/                   # (Coming Soon) User Interface
├── docs/                      # Documentation and test results
└── README.md                  # This file
```

---

## 🛠️ Getting Started

### Prerequisites
- **Windows 10/11**
- **PowerShell 5.1 or later**
- **Administrator privileges** (required for network configuration)

### Quick Start

#### Option 1: WiFi Setup

1. **Clone the repository**
   ```powershell
   git clone https://github.com/jackyngtf/Win11AutoWiFiIPConfig.git
   cd Win11AutoWiFiIPConfig
   ```

2. **Configure WiFi Settings**
   ```powershell
   cd src/WiFi
   # Copy the example config
   Copy-Item NetworkConfig.example.ps1 NetworkConfig.ps1
   
   # Edit NetworkConfig.ps1 with your corporate SSID and IP settings
   notepad NetworkConfig.ps1
   ```

3. **Run the Setup Script** (as Administrator)
   ```powershell
   .\Setup-NetworkEventTrigger.ps1
   ```

4. **Verify**
   - Connect to your corporate WiFi
   - Check `NetworkEventHandler.log` for execution details
   - Run `ipconfig` to verify your static IP

#### Option 2: Ethernet Setup

1. **Navigate to Ethernet Module**
   ```powershell
   cd src/Ethernet
   ```

2. **Configure Ethernet Settings**
   ```powershell
   # Copy the example config
   Copy-Item EthernetConfig.example.ps1 EthernetConfig.ps1
   
   # Edit with your adapter's MAC address and IP settings
   notepad EthernetConfig.ps1
   ```

3. **Find Your MAC Address**
   ```powershell
   Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object Name, MacAddress
   ```

4. **Run the Setup Script** (as Administrator)
   ```powershell
   .\Setup-EthernetEventTrigger.ps1
   ```

5. **Verify**
   - Plug in your Ethernet cable
   - Check `EthernetEventHandler.log`
   - Run `ipconfig` to verify your static IP

---

## ⚙️ Configuration

### WiFi Configuration (`src/WiFi/NetworkConfig.ps1`)

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

### Ethernet Configuration (`src/Ethernet/EthernetConfig.ps1`)

```powershell
$EthernetConfigs = @{
    "00-D8-61-07-4B-D6" = @{
        IPAddress   = "10.10.216.253"
        SubnetMask  = "255.255.255.0"
        Gateway     = "10.10.216.1"
        DNS         = @("10.10.216.28", "8.8.8.8")
        Description = "Primary Office NIC"
    }
}
```

### Logging Configuration

Both modules support advanced logging:

```powershell
# Enable/Disable Logging
$EnableLogging = $true

# Log Retention (days) - 0 means keep all logs
$LogRetentionDays = 7  # Keep 1 week of logs

# Maximum Log File Size (MB) - 0 means no size limit
$MaxLogSizeMB = 5  # Rotate at 5 MB
```

---

## ❓ Troubleshooting

### WiFi Issues
- **Script doesn't trigger**: Check Event Viewer → Windows Logs → System for Event IDs 8001/8003/10000
- **Wrong IP assigned**: Verify SSID name matches exactly (case-sensitive)
- **DHCP still being used**: Check if DHCP is disabled: `Get-NetIPInterface -InterfaceAlias "Wi-Fi" | Select Dhcp`

### Ethernet Issues
- **Script doesn't run**: Ensure Execution Policy is set to `RemoteSigned` or `Unrestricted`
- **Wrong IP**: Verify MAC address format (use dashes: `00-11-22-33-44-55`)
- **No response to cable plug**: Check scheduled task in Task Scheduler → Microsoft → Windows → NCSI

### General
- **Logs**: Check the respective `.log` files for detailed execution history
- **Permissions**: All setup scripts require Administrator privileges
- **Test manually**: Run the handler scripts directly to test configuration

---

## 🗑️ Uninstalling

### WiFi
```powershell
cd src/WiFi
.\Uninstall-NetworkEventTrigger.ps1
```

### Ethernet
```powershell
cd src/Ethernet
.\Uninstall-EthernetEventTrigger.ps1
```

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

1. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Commit your changes**
   ```bash
   git commit -m 'Add amazing feature'
   ```

3. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```

4. **Open a Pull Request**

---

## 📄 License

[MIT License](LICENSE)

---

## 🔮 Roadmap

- [x] WiFi SSID-based automation
- [x] Ethernet MAC-based automation
- [x] Log rotation and management
- [ ] **GUI Interface** (in progress)
- [ ] Multi-language support
- [ ] Config import/export via JSON

---

## 💡 Tips

- **Use different subnets** for WiFi and Ethernet to avoid routing conflicts when both are connected
- **Set interface metrics** to prioritize Ethernet over WiFi:
  ```powershell
  Set-NetIPInterface -InterfaceAlias "Ethernet" -InterfaceMetric 10
  Set-NetIPInterface -InterfaceAlias "Wi-Fi" -InterfaceMetric 50
  ```
- **Disable auto-connect** for non-corporate WiFi profiles to prevent unnecessary script executions
