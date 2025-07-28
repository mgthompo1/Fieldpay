# Windcave Tap to Pay Integration Setup

This guide explains how to set up and use the Windcave Tap to Pay SDK in your FieldPay iOS app.

## Overview

The Windcave Tap to Pay SDK allows you to accept contactless payments directly on iPhone without additional hardware. This integration provides a seamless payment experience for your field service business.

## Requirements

- iOS 17+
- Active Windcave account with Tap to Pay on iPhone functionality enabled
- Tap to Pay on iPhone entitlement from Apple
- Compatible iPhone device (iPhone XS or later)

## Setup Instructions

### 1. Windcave Account Setup

1. Sign up for a Windcave account at [windcave.com](https://windcave.com)
2. Request Tap to Pay on iPhone functionality from Windcave support
3. Obtain your account credentials:
   - Account ID
   - Username
   - Password

### 2. Apple Entitlement

1. Request the "Tap to Pay on iPhone" entitlement from Apple
2. Add the entitlement to your app's capabilities in Xcode
3. Configure the entitlement with your Windcave account details

### 3. SDK Configuration

The Tap to Pay SDK is already integrated into your project. To configure it:

1. Open `fieldpay/Networking/TapToPayManager.swift`
2. Replace the placeholder credentials with your actual Windcave account details:

```swift
let configuration = TapToPayConfiguration(
    accountId: "YOUR_WINDCAVE_ACCOUNT_ID",
    username: "YOUR_WINDCAVE_USERNAME", 
    password: "YOUR_WINDCAVE_PASSWORD"
)
```

### 4. Usage

The Tap to Pay functionality is accessible through:

1. **Dashboard**: Tap the "Tap to Pay" quick action button
2. **Programmatic**: Use `TapToPayManager.shared.processPayment(amount:description:)`

## Features

### TapToPayManager

The main manager class provides:

- **SDK Initialization**: Automatically initializes on app launch
- **Payment Processing**: Process contactless payments
- **Device Compatibility**: Check if device supports Tap to Pay
- **Status Monitoring**: Real-time payment status updates

### TapToPayView

A complete UI for processing payments:

- Amount input with validation
- Payment description
- Real-time status updates
- Success/error handling
- Transaction result display

## API Reference

### TapToPayManager

```swift
// Initialize the SDK
await tapToPayManager.initializeSDK()

// Process a payment
await tapToPayManager.processPayment(
    amount: Decimal(100.00),
    description: "Field service payment"
)

// Check device compatibility
let isCompatible = tapToPayManager.checkDeviceCompatibility()

// Get device status
let status = tapToPayManager.getDeviceStatus()
```

### Published Properties

- `isInitialized`: SDK initialization status
- `isProcessingPayment`: Current payment processing state
- `lastPaymentResult`: Result of the last payment attempt
- `errorMessage`: Any error messages

## Payment Flow

1. **Initialization**: SDK initializes on app launch
2. **User Input**: User enters amount and description
3. **Payment Processing**: SDK handles contactless payment
4. **Result Handling**: Success/error feedback to user
5. **Transaction Recording**: Payment result stored for reporting

## Error Handling

The SDK provides comprehensive error handling:

- **Initialization Errors**: Network, credential, or entitlement issues
- **Payment Errors**: Declined cards, network issues, timeout
- **Device Errors**: Incompatible device or missing permissions

## Security

- All payment data is encrypted in transit
- No sensitive card data is stored on device
- Secure token-based authentication with Windcave
- PCI DSS compliant processing

## Testing

### Simulator Testing

- Use the iOS Simulator for UI testing
- Payment processing will be simulated
- Test error scenarios and edge cases

### Device Testing

- Test on physical iPhone device
- Use test cards provided by Windcave
- Verify real payment processing

## Support

For issues with the Tap to Pay integration:

1. Check the debug console for detailed error messages
2. Verify Windcave account credentials
3. Ensure device compatibility
4. Contact Windcave support for SDK-specific issues

## Additional Resources

- [Windcave Tap to Pay SDK Documentation](https://github.com/Windcave/windcave-taptopay-sdk-ios)
- [Apple Tap to Pay on iPhone Guide](https://developer.apple.com/documentation/taptopay)
- [Windcave Developer Portal](https://developer.windcave.com) 