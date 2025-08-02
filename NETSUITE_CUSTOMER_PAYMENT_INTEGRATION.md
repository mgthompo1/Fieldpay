# NetSuite Customer Payment Integration

## Overview

This document describes the implementation of automatic customer payment creation in NetSuite via the REST API when payments are processed through the FieldPay app.

## Implementation Summary

When a user completes a manual payment or quick payment in the app, the system now automatically POSTs the payment result to NetSuite as a new customer payment record via the NetSuite REST Web Services API.

## Key Components

### 1. NetSuite Customer Payment Record Models

**File:** `fieldpay/Models/NetSuiteResponseModels.swift`

#### `NetSuiteCustomerPaymentRecord`
- Converts app `Payment` objects to NetSuite-compatible format
- Maps payment methods to NetSuite payment method codes
- Handles customer references and applied payments
- Supports invoice application for payments

#### `AppliedPayment`
- Represents payments applied to specific invoices
- Links payment amounts to invoice documents

#### `NetSuiteCustomerPaymentResponse`
- Handles NetSuite API responses
- Converts NetSuite payment records back to app format

### 2. Payment Method Mapping

**Functions:** `mapPaymentMethodToNetSuite()` and `mapNetSuitePaymentMethodToApp()`

Maps app payment methods to NetSuite payment method codes:
- `tapToPay`, `manualCard`, `applePay`, `googlePay` → `"CREDIT_CARD"`
- `cash` → `"CASH"`
- `check` → `"CHECK"`
- `bankTransfer` → `"BANK_TRANSFER"`

### 3. Enhanced NetSuite API

**File:** `fieldpay/Networking/NetSuiteAPI.swift`

#### `createPayment()` Method
- Converts `Payment` objects to `NetSuiteCustomerPaymentRecord`
- POSTs to `/services/rest/record/v1/customerpayment` endpoint
- Handles authentication and token refresh
- Provides detailed error logging and debugging
- Returns created payment with NetSuite ID

### 4. Updated Payment ViewModel

**File:** `fieldpay/ViewModels/PaymentViewModel.swift`

#### Enhanced Payment Processing
- Updates payment status to "succeeded" after successful processing
- Automatically creates customer payment in NetSuite
- Provides detailed logging for debugging
- Handles NetSuite connection validation

## Payment Flow

### 1. Manual Card Payment
```
User Input → Payment Processing → Stripe Gateway → NetSuite Customer Payment
```

### 2. Tap to Pay Payment
```
User Input → Tap to Pay SDK → Payment Processing → NetSuite Customer Payment
```

### 3. Quick Payment
```
User Input → Payment Method Selection → Processing → NetSuite Customer Payment
```

## NetSuite API Integration

### Endpoint
```
POST /services/rest/record/v1/customerpayment
```

### Request Format
```json
{
  "entity": {
    "id": "customer_id",
    "refName": null,
    "type": "CUSTOMER"
  },
  "amount": 100.00,
  "status": "succeeded",
  "trandate": "2025-07-28T17:15:00.000Z",
  "memo": "Payment description",
  "paymentMethod": "CREDIT_CARD",
  "applied": [
    {
      "doc": "invoice_id",
      "amount": 100.00,
      "apply": true
    }
  ]
}
```

### Response Handling
- Parses NetSuite response into `NetSuiteCustomerPaymentResponse`
- Extracts NetSuite payment ID for future reference
- Updates local payment records with NetSuite IDs

## Error Handling

### Authentication
- Automatic OAuth token refresh on 401 responses
- Retry mechanism for failed requests
- Clear error messages for authentication issues

### Validation
- NetSuite connection validation before payment processing
- Payment data validation and sanitization
- Proper error logging for debugging

### Fallback Behavior
- Shows error message if NetSuite is not connected
- Prevents payment processing without NetSuite integration
- Maintains payment integrity

## Debugging and Logging

### Debug Messages
- Payment creation attempts: `"Debug: PaymentViewModel - Creating customer payment in NetSuite"`
- Success confirmations: `"Debug: PaymentViewModel - Successfully created customer payment in NetSuite with ID: {id}"`
- API request details: `"Debug: NetSuiteAPI - Creating customer payment with data: {json}"`

### Error Logging
- HTTP status codes and error responses
- Authentication failures
- Data validation errors
- Network connectivity issues

## Usage Examples

### Processing a Manual Card Payment
```swift
await viewModel.processManualCardPayment(
    amount: 150.00,
    customerId: "customer_123",
    invoiceId: "invoice_456",
    description: "Payment for services"
)
```

### Processing a Quick Payment
```swift
await viewModel.processPayment(
    amount: 75.50,
    paymentMethod: .tapToPay,
    customerId: "customer_789",
    description: "Quick payment"
)
```

## Configuration Requirements

### NetSuite Setup
1. OAuth 2.0 authentication configured
2. REST API access enabled
3. Customer payment record permissions
4. Proper account and subsidiary access

### App Configuration
1. NetSuite OAuth credentials in Settings
2. Valid customer and invoice IDs
3. Payment gateway integration (Stripe/Windcave)

## Testing

### Test Scenarios
1. **Successful Payment Creation**
   - Process payment with valid customer ID
   - Verify NetSuite customer payment record created
   - Confirm payment status and amounts

2. **Invoice Application**
   - Process payment with invoice ID
   - Verify applied payment in NetSuite
   - Check invoice balance updates

3. **Error Handling**
   - Test with invalid customer ID
   - Test with expired OAuth token
   - Test with network connectivity issues

4. **Payment Method Mapping**
   - Test all payment method types
   - Verify correct NetSuite payment method codes
   - Check payment method display in NetSuite

## Benefits

1. **Automatic Integration**: No manual data entry required
2. **Real-time Sync**: Payments appear immediately in NetSuite
3. **Audit Trail**: Complete payment history with NetSuite IDs
4. **Invoice Application**: Automatic invoice payment application
5. **Error Handling**: Robust error handling and user feedback
6. **Debugging**: Comprehensive logging for troubleshooting

## Future Enhancements

1. **Batch Processing**: Support for multiple payment creation
2. **Payment Updates**: Ability to update existing payments
3. **Refund Integration**: Automatic refund processing in NetSuite
4. **Advanced Filtering**: Customer-specific payment queries
5. **Reporting**: Enhanced payment reporting and analytics 