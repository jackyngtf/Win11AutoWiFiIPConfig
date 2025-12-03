# Network Automation Suite 🌐

**Intelligent, Event-Driven Network Configuration for Windows**

A PowerShell automation suite that eliminates manual IP configuration for corporate environments. This project provides intelligent, automated IP management for both WiFi and Ethernet adapters, ensuring seamless connectivity without DHCP conflicts or manual intervention.

---

## 🎯 Why This Solution?

### DHCP Pool Conservation
- Corporate networks often have limited DHCP pools
- Manual static IPs are error-prone and time-consuming
- This suite automatically assigns static IPs based on network context (SSID for WiFi, Hostname for Ethernet)

### Zero-DHCP Strategy
- **Security First:** Prevents DHCP requests on corporate networks entirely
- **No Leaks:** Guarantees that corporate devices never consume DHCP leases accidentally
- **Stateful Management:** Only assigns IPs when safe to do so

### Seamless Remote Work Experience
- **Smart Switching:** Automatically detects corporate vs. home networks
- **Travel Mode:** Reverts to DHCP when out of office (home, hotel, café)
- **VLAN Support:** Handles complex switching scenarios (e.g., forcing Static IP to switch VLANs)

---

## 🚀 Features

### 📶 WiFi Automation (`src/WiFi`)
- **SSID-Based Configuration**: Automatically applies static IPs when connecting to known corporate SSIDs
- **Zero-DHCP Mode**: DHCP remains disabled on the adapter; uses `netsh` to request IPs for non-corporate networks
- **Safe Mode Fallback**: Reverts to a default static IP when disconnected
- **Event-Driven**: Triggered by Windows network connection/disconnection events

### 🔌 Ethernet Automation (`src/Ethernet`)
- **Device-Centric Configuration**: Assigns Static IPs based on the **Hostname**, ensuring the device gets the right IP regardless of which dock/dongle is used
- **Zero-DHCP Strategy**: Pre-disables DHCP on all Ethernet adapters to prevent auto-DHCP
- **VLAN Switching Support**: Forces Static IP and validates connectivity (Gateway + WAN) before reverting
- **WiFi Auto-Switch**: Automatically disables WiFi when a stable Ethernet connection is detected
- **Conflict Prevention**: "First-Come-First-Serve" logic handles multiple adapters

---

## 📂 Project Structure

```
/
├── src/
│   ├── WiFi/                  # WiFi automation module
│   │   ├── NetworkEventHandler.ps1
│   │   ├── NetworkConfig.ps1
│   │   ├── Setup-NetworkEventTrigger.ps1
│   │   └── README.md
│   ├── Ethernet/              # Ethernet automation module
│   │   ├── EthernetEventHandler.ps1
│   │   ├── EthernetConfig.ps1
│   │   ├── Setup-EthernetEventTrigger.ps1
│   │   └── README.md
│   └── GUI/                   # (Coming Soon) User Interface
├── logs/                      # Centralized log files
│   ├── WiFi-NetworkEventHandler.log
│   └── Ethernet-EventHandler.log
├── docs/                      # Advanced documentation
│   ├── AdvancedConfiguration.md
│   ├── ITAdminGuide.md
│   ├── Uninstallation.md
│   └── Network-Test-Results.md
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

1. **Navigate to WiFi Module**
   ```powershell
   cd src/WiFi
   ```

2. **Configure Settings**
   ```powershell
   Copy-Item NetworkConfig.example.ps1 NetworkConfig.ps1
   notepad NetworkConfig.ps1
   # Add your corporate SSIDs and IP settings
   ```

3. **Run Setup** (as Administrator)
   ```powershell
   .\Setup-NetworkEventTrigger.ps1
   ```

#### Option 2: Ethernet Setup

1. **Navigate to Ethernet Module**
   ```powershell
   cd src/Ethernet
   ```

2. **Configure Settings**
   ```powershell
   Copy-Item EthernetConfig.example.ps1 EthernetConfig.ps1
   notepad EthernetConfig.ps1
   # Add your Hostname and IP settings
   ```

3. **Run Setup** (as Administrator)
   ```powershell
   .\Setup-EthernetEventTrigger.ps1
   ```
   *Note: This will immediately disable DHCP on all Ethernet adapters.*

---

## ⚙️ Configuration Examples

### WiFi (`src/WiFi/NetworkConfig.ps1`)

```powershell
$CompanyWiFiNetworks = @(
    @{
        SSID        = "CorpWiFi-Office"
        StaticIP    = "10.10.216.100"
        Gateway     = "10.10.216.1"
        # ...
    }
)
```

### Ethernet (`src/Ethernet/EthernetConfig.ps1`)

```powershell
$DeviceEthernetMap = @{
    "L-Jacky-01" = @{  # Your Hostname
        IPAddress   = "10.10.216.253"
        Gateway     = "10.10.216.1"
        Description = "Primary Laptop"
    }
}
```

---

## ❓ Troubleshooting

### WiFi Issues
- **Script doesn't trigger**: Check Event Viewer for Event IDs 8001/8003/10000
- **Wrong IP**: Verify SSID name matches exactly (case-sensitive)
- **Logs**: Check `logs/WiFi-NetworkEventHandler.log`

### Ethernet Issues
- **"Travel Mode" in Office**: Check if your Gateway IP is reachable. The script reverts to DHCP if Gateway AND WAN are unreachable.
- **Access Denied**: Ensure you run setup scripts as Administrator.
- **Logs**: Check `logs/Ethernet-EventHandler.log`

---

## 📚 Documentation

### User Documentation
- **[README.md](README.md)** - This file (quick start guide)
- **[Advanced Configuration](docs/AdvancedConfiguration.md)** - Auto-connect, logging, interface priorities, security
- **[Uninstallation Guide](docs/Uninstallation.md)** - Complete removal procedures

### IT Administrator Documentation
- **[IT Admin Guide](docs/ITAdminGuide.md)** - Architecture, deployment models, monitoring, enterprise deployment
- **[Test Results](docs/Network-Test-Results.md)** - Configuration verification and testing

---

## 🤝 Contributing

We welcome contributions! Please create a feature branch and submit a Pull Request.

---

## 📄 License

[MIT License](LICENSE)
