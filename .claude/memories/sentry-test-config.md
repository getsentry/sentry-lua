# Sentry Test Configuration

## Default Test Organization and Project

For all Sentry MCP testing and validation:
- **Organization**: `bruno-garcia`
- **Project**: `playground`

This configuration is used for:
- End-to-end testing with real Sentry events
- MCP server validation of SDK functionality
- Integration testing across all platforms (Love2D, Roblox, etc.)

## Usage

When validating events reach Sentry, always use:
```
organizationSlug: bruno-garcia
projectSlug: playground
```