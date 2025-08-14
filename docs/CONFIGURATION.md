# Configuration Guide

## Overview
DeployWorkstation supports flexible configuration through JSON files that define deployment profiles for different use cases.

## Configuration Structure
Available Profiles
Corporate: Standard business workstation
Developer: Programming and development tools
Home User: Personal computer setup
Educational: School/training environment
Kiosk: Limited functionality public computer

##Configuration Options
Bloatware Removal
{
  "bloatware_removal": {
    "enabled": true,
    "aggressive_mode": false,
    "preserve_apps": [
      "Microsoft.WindowsCalculator",
      "Microsoft.WindowsCamera"
    ],
    "custom_removal": [
      "CustomApp.Name"
    ]
  }
}

Core Applications
{
  "core_applications": [
    "Google.Chrome",
    "7zip.7zip",
    "Adobe.Acrobat.Reader.64-bit",
    "VideoLAN.VLC"
  ]
}

Security Settings
{
  "security_settings": {
    "enable_windows_defender": true,
    "disable_consumer_features": true,
    "enable_developer_mode": false,
    "configure_update_settings": true
  }
}

Network Settings
{
  "network_settings": {
    "disable_onedrive": true,
    "configure_proxy": false,
    "domain_join": false
  }
}

Example Profiles
Corporate
{
  "deployment_profile": "corporate",
  "description": "Standard corporate workstation deployment",
  "bloatware_removal": {
    "enabled": true,
    "aggressive_mode": true,
    "preserve_apps": ["Microsoft.WindowsCalculator", "Microsoft.WindowsCamera"]
  },
  "core_applications": [
    "Google.Chrome",
    "7zip.7zip",
    "Adobe.Acrobat.Reader.64-bit",
    "VideoLAN.VLC",
    "Malwarebytes.Malwarebytes"
  ],
  "business_applications": [
    "Microsoft.Teams",
    "Microsoft.Office",
    "Zoom.Zoom"
  ],
  "security_settings": {
    "enable_windows_defender": true,
    "disable_consumer_features": true,
    "configure_update_settings": true
  },
  "network_settings": {
    "disable_onedrive": true,
    "configure_proxy": false,
    "domain_join": false
  }
}

Developer
{
  "deployment_profile": "developer",
  "description": "Developer workstation with programming tools",
  "bloatware_removal": {
    "enabled": true,
    "aggressive_mode": false,
    "preserve_apps": [
      "Microsoft.WindowsCalculator",
      "Microsoft.WindowsCamera",
      "Microsoft.ScreenSketch"
    ]
  },
  "core_applications": [
    "Google.Chrome",
    "7zip.7zip",
    "Adobe.Acrobat.Reader.64-bit",
    "VideoLAN.VLC"
  ],
  "development_tools": [
    "Microsoft.VisualStudioCode",
    "Git.Git",
    "Microsoft.WindowsTerminal",
    "Docker.DockerDesktop",
    "Python.Python.3.11",
    "OpenJS.NodeJS",
    "Postman.Postman"
  ],
  "developer_utilities": [
    "Microsoft.PowerToys",
    "JetBrains.Toolbox",
    "Notepad++.Notepad++",
    "WinSCP.WinSCP"
  ],
  "security_settings": {
    "enable_windows_defender": true,
    "disable_consumer_features": false,
    "enable_developer_mode": true
  }
}

Tips

Keep keys consistent across profiles (e.g., always bloatware_removal, not remove_bloatware).

Validate JSON before committing (e.g., with jq or an online validator).

Use PRs to review config changes and catch mistakes early.
EOF

git add docs/CONFIGURATION.md
git commit -m "docs: add CONFIGURATION.md with structure and examples"
git push

### Basic Profile Format
```json
{
  "deployment_profile": "profile_name",
  "description": "Profile description",
  "bloatware_removal": {},
  "core_applications": [],
  "security_settings": {},
  "network_settings": {}
}

