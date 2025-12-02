# Network Automation Suite 🌐

A professional PowerShell automation suite for managing network configurations on Windows. This project provides intelligent, automated IP management for both WiFi and Ethernet adapters, ensuring seamless connectivity in corporate environments.

## 🚀 Features

### 📶 WiFi Automation (`src/WiFi`)
- **Zero-DHCP Strategy**: Prevents DHCP leaks on corporate networks.
- **Auto-Detection**: Identifies corporate SSIDs and applies static IPs automatically.
- **Safe Mode**: Reverts to safe settings when disconnected.
- **Log Rotation**: Built-in logging with automatic rotation and cleanup.

### 🔌 Ethernet Automation (`src/Ethernet`)
- **MAC-Based Config**: Assigns static IPs based on the physical adapter's MAC address.
- **Plug-and-Play**: Automatically detects when an Ethernet cable is plugged in.
- **Conflict Prevention**: Cleans up old routes and IPs before applying new settings.

## 📂 Project Structure

```
/
├── src/
│   ├── WiFi/          # WiFi automation scripts
│   ├── Ethernet/      # Ethernet automation scripts
│   └── GUI/           # (Coming Soon) User Interface
├── docs/              # Documentation and test results
└── README.md          # This file
```

## 🛠️ Getting Started

### Prerequisites
- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges

### Installation

1. **Clone the repository**
   ```powershell
   git clone <repo-url>
   cd Network-Automation-Suite
   ```

2. **Setup WiFi**
   Navigate to `src/WiFi` and run the setup script (if available) or configure `NetworkConfig.ps1`.

3. **Setup Ethernet**
   Navigate to `src/Ethernet`, edit `EthernetConfig.ps1` with your MAC address, and run:
   ```powershell
   .\Setup-EthernetEventTrigger.ps1
   ```

## 🤝 Contributing

1. Create a new branch: `git checkout -b feature/amazing-feature`
2. Commit your changes: `git commit -m 'Add amazing feature'`
3. Push to the branch: `git push origin feature/amazing-feature`
4. Open a Pull Request

## 📄 License

[MIT License](LICENSE)
