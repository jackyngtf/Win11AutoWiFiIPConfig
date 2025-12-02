# ============================================================================
# Ethernet Network Configuration
# ============================================================================

# Define specific IP configurations based on MAC Address.
# Format: "MAC-Address" = @{ Settings }
# MAC Address format: XX-XX-XX-XX-XX-XX (dashes)

$EthernetConfigs = @{
    # Example 1: Office Desktop
    "00-15-5D-00-01-02" = @{
        IPAddress   = "192.168.10.50"
        SubnetMask  = "255.255.255.0"
        Gateway     = "192.168.10.1"
        DNS         = @("192.168.10.1", "8.8.8.8")
        Description = "Primary Office Desktop"
    }

    # Example 2: Lab Machine
    "AA-BB-CC-DD-EE-FF" = @{
        IPAddress   = "10.0.0.100"
        SubnetMask  = "255.0.0.0"
        Gateway     = "10.0.0.1"
        DNS         = @("10.0.0.1")
        Description = "Lab Test Machine"
    }
}

# ============================================================================
# Global Settings
# ============================================================================

# Action for unknown MAC addresses (adapters not in the list above)
# Options:
#   "DHCP"     - Force DHCP (Automatic IP) - RECOMMENDED
#   "Nothing"  - Do not change settings
$UnknownMacAction = "DHCP"

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
