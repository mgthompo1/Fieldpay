# Debug Logging Improvements

## Overview
This document describes the improvements made to reduce debug logging noise in the FieldPay application while maintaining the ability to enable detailed logging when needed for debugging.

## Problem
The application was generating excessive debug output, including:
- Repetitive token validation logs
- Verbose configuration loading messages
- Detailed SuiteQL response logging
- Customer initialization logs
- Keychain operation details

This made it difficult to identify actual errors and performance issues in the logs.

## Solution
Implemented a centralized debug logging configuration system with granular control over different logging categories.

## Debug Configuration

### Location
The debug configuration is centralized in `fieldpay/Networking/SystemManager.swift`:

```swift
struct DebugLogConfig {
    static let shared = DebugLogConfig()
    
    // Master debug logging toggle
    let debugLoggingEnabled = false  // Turn off all debug logging by default
    
    // Individual category toggles to reduce noise
    let logSystemManager = false      // Turn off system manager logging
    let logTokenValidation = false    // Reduce repetitive token validation logs
    let logConfigurationLoading = false // Reduce repetitive config loading logs
    let logConnectionStatus = false   // Turn off connection status logging
    let logAPIRequests = false        // Turn off API request logging
    let logErrorDetails = true        // Keep error logging for debugging
    let logSuiteQLResponses = false   // Turn off verbose SuiteQL response logging
    
    private init() {}
}
```

### Categories

| Category | Description | Default |
|----------|-------------|---------|
| `debugLoggingEnabled` | Master toggle for all debug logging | `false` |
| `logSystemManager` | System manager connection/disconnection logs | `false` |
| `logTokenValidation` | OAuth token validation and refresh logs | `false` |
| `logConfigurationLoading` | Keychain and configuration loading logs | `false` |
| `logConnectionStatus` | Connection status update logs | `false` |
| `logAPIRequests` | HTTP request/response details | `false` |
| `logErrorDetails` | Error messages and failure details | `true` |
| `logSuiteQLResponses` | NetSuite SuiteQL response logging | `false` |

## Usage

### Quick Toggle Script
Use the provided script to quickly toggle debug logging on/off:

```bash
# From project root directory
./toggle_debug_logging.swift
```

This script will:
- Check current debug logging state
- Toggle between enabled/disabled
- Provide clear feedback about the change

### Manual Configuration
To manually adjust specific logging categories, edit `SystemManager.swift`:

```swift
// Enable only error logging (recommended for production)
let debugLoggingEnabled = false
let logErrorDetails = true

// Enable verbose logging for debugging
let debugLoggingEnabled = true
let logTokenValidation = true
let logSuiteQLResponses = true
```

### Runtime Control
The configuration is read at compile time, so changes require a rebuild. For runtime control, you could extend the system to use UserDefaults or environment variables.

## Files Modified

### Core Configuration
- `fieldpay/Networking/SystemManager.swift` - Added DebugLogConfig and updated logging
- `fieldpay/Networking/NetSuiteAPI.swift` - Updated SuiteQL response logging
- `fieldpay/Networking/KeychainWrapper.swift` - Updated keychain operation logging

### View Models
- `fieldpay/ViewModels/CustomerViewModel.swift` - Added debug configuration extension
- `fieldpay/Views/CustomerListView.swift` - Added debug configuration extension

### Utilities
- `toggle_debug_logging.swift` - Quick toggle script

## Benefits

### Reduced Noise
- Eliminates repetitive token validation logs
- Removes verbose configuration loading messages
- Filters out customer initialization noise
- Reduces SuiteQL response verbosity

### Better Error Visibility
- Keeps important error messages visible
- Maintains failure details for debugging
- Preserves critical system state information

### Flexible Control
- Easy to enable specific logging categories
- Quick toggle between verbose and quiet modes
- Granular control over different system components

## Best Practices

### Development
- Enable `debugLoggingEnabled = true` for detailed debugging
- Use specific category toggles to focus on particular areas
- Keep `logErrorDetails = true` for error tracking

### Production
- Keep `debugLoggingEnabled = false` for minimal noise
- Ensure `logErrorDetails = true` for error monitoring
- Consider enabling specific categories only when troubleshooting

### Troubleshooting
1. Start with `logErrorDetails = true` to see errors
2. Enable `logTokenValidation = true` for OAuth issues
3. Use `logSuiteQLResponses = true` for NetSuite API problems
4. Enable `logConfigurationLoading = true` for keychain issues

## Example Output

### Quiet Mode (Default)
```
❌ SystemManager - Failed to connect to NetSuite: tokenValidationFailed
❌ NetSuiteAPI - Failed to fetch line items: requestFailed
```

### Verbose Mode
```
🔍 Debug: ===== validateTokenBeforeRequest() called =====
Debug: ===== NetSuiteAPI.isConfigured() called =====
Debug: KeychainWrapper - Loading NetSuite configuration from Keychain
Debug: NetSuiteAPI configuration status: true
Debug: Token expiry check. exp=2025-08-15 03:18:17 +0000 now=2025-08-15 02:39:21 +0000 expired=false
Debug: Request URL: https://tstdrv1870144.suitetalk.api.netsuite.com/services/rest/query/v1/suiteql
Debug: Response status: 200
❌ SystemManager - Failed to connect to NetSuite: tokenValidationFailed
```

## Future Enhancements

### Runtime Configuration
- Add UserDefaults-based configuration
- Support environment variable overrides
- Implement logging level system (DEBUG, INFO, WARN, ERROR)

### Log Persistence
- Save logs to files for analysis
- Implement log rotation
- Add log filtering and search capabilities

### Performance Monitoring
- Add timing information to operations
- Track API call frequencies
- Monitor memory usage patterns

## Support

For issues with debug logging configuration:
1. Check that `DebugLogConfig.shared` is accessible
2. Verify the configuration file path is correct
3. Ensure the toggle script has execute permissions
4. Rebuild the project after configuration changes
