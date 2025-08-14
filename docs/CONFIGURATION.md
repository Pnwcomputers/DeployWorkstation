# Configuration Guide

## Overview
DeployWorkstation supports flexible configuration through JSON files that define deployment profiles for different use cases.

## Configuration Structure

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

