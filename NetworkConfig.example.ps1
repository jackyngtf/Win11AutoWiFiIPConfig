# ============================================================================
# Network Configuration - Shared Settings
# This file is loaded by both the main script and the event handler
# ============================================================================

# Default values
$DefaultSubnetMask = "255.255.255.0"
$DefaultAuthType = "WPA2PSK"
$DefaultEncryption = "AES"
$DefaultPrimaryDNS = "192.168.10.1"    # EXAMPLE: Your Company DNS
$DefaultSecondaryDNS = "8.8.8.8"      # Google DNS (public)
$DefaultGateway = "192.168.10.1"      # EXAMPLE: Your Gateway
$DefaultStaticIP = "192.168.10.100"   # EXAMPLE: Your Static IP
$DefaultPassword = "YourPasswordHere" # EXAMPLE: Default WiFi Password

# Company WiFi Networks
$CompanyWiFiNetworks = @(
    @{
        Name     = "Company WiFi Main"       # WiFi Profile Name
        SSID     = "Company-WiFi-SSID"       # SSID to match
        Password = "YourWifiPasswordHere"    # WiFi Password
    },
    @{ Name = "Office-Guest"; SSID = "Office-Guest" },
    @{ Name = "Warehouse"; SSID = "Warehouse-WiFi" }
)

# ============================================================================
# Logging Configuration
# ============================================================================

# Enable/Disable Logging
$EnableLogging = $true  # Set to $false to disable all logging

# Log Retention (days) - 0 means keep all logs
$LogRetentionDays = 7  # Keep logs for 7 days (1 week)
# Examples:
#   7  = Keep 1 week of logs
#   30 = Keep 1 month of logs
#   0  = Keep all logs (no automatic cleanup)

# Maximum Log File Size (MB) - 0 means no size limit
$MaxLogSizeMB = 5  # Rotate log when it exceeds 5 MB
# Examples:
#   1  = Rotate at 1 MB
#   5  = Rotate at 5 MB
#   10 = Rotate at 10 MB
#   0  = No size limit
