# ============================================================================
# Ethernet Network Configuration
# ============================================================================

# Define specific IP configurations based on DEVICE HOSTNAME.
# Format: "Hostname" = @{ Settings }
# Hostname is case-insensitive (matches $env:COMPUTERNAME)

$DeviceEthernetMap = @{
    # Example 1: Jacky's Laptop
    "L-Jacky-01" = @{
        IPAddress   = "192.168.10.50"
        SubnetMask  = "255.255.255.0"
        Gateway     = "192.168.10.1"
        DNS         = @("192.168.10.1", "8.8.8.8")
        Description = "Jacky's Primary Laptop"
    }

    # Example 2: Admin Workstation
    "W-Admin-02" = @{
        IPAddress   = "10.0.0.100"
        SubnetMask  = "255.0.0.0"
        Gateway     = "10.0.0.1"
        DNS         = @("10.0.0.1")
        Description = "IT Admin Station"
    }
}

# ============================================================================
# WiFi Auto-Switch Settings
# ============================================================================

# Automatically disable WiFi when stable Ethernet is detected
$EnableWiFiAutoSwitch = $true

# Targets to ping to verify Internet connectivity (WAN Check)
# Includes baidu.com for China region compatibility
$WanTestTargets = @("8.8.8.8", "1.1.1.1", "www.baidu.com")

# Minimum number of targets that must reply to consider WAN "Up"
$WanSuccessThreshold = 1

# Delay (in seconds) before re-enabling WiFi after Ethernet loss
# Useful to prevent WiFi flapping during short Ethernet blips
# Set to 0 for instant switching (default)
$WiFiAutoSwitchDelaySeconds = 0

# ============================================================================
# Global Settings
# ============================================================================

# Action for unknown Devices (Hostnames not in the list above)
# Options:
#   "DHCP"     - Force DHCP (Automatic IP) - RECOMMENDED
#   "Nothing"  - Do not change settings
$UnknownDeviceAction = "DHCP"

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
