# Configuration Guide

## Overview
DeployWorkstation supports flexible configuration through JSON files that define deployment profiles for different use cases.

## Configuration Structure

### Basic Profile Format
```json
{
  "deployment_profile": "profile_name",
  "description": "Profile description",
  "bloatware_removal": {
  "enabled": true,
  "aggressive_mode": false,
  "preserve_apps": [
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsCamera"
  ],
  "custom_removal": [
    "CustomApp.Name"
  ],
  "core_applications": [
  "Google.Chrome",
  "7zip.7zip",
  "Adobe.Acrobat.Reader.64-bit"
],
"optional_applications": [
  "Microsoft.Teams",
  "Zoom.Zoom"
],
  "security_settings": {
  "enable_windows_defender": true,
  "disable_consumer_features": true,
  "configure_update_settings": true,
  "enable_firewall": true,
  "disable_autorun": true
}
  "network_settings": {
}

