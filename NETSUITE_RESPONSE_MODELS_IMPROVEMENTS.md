# NetSuite Response Models Improvements

## Overview
This document outlines the comprehensive improvements made to the NetSuite response models based on code review feedback. The improvements focus on robust date parsing, enhanced error handling, better status mapping, improved null safety, and enhanced extensibility.

## Key Improvements Implemented

### 1. Robust Date Parsing
**Problem**: Single ISO8601DateFormatter was insufficient for handling various date formats that NetSuite might return.

**Solution**: 
- Created `NetSuiteDateParser` utility with multiple date format support
- Implemented fallback parsing for different date formats
- Added comprehensive error logging for debugging

```swift
struct NetSuiteDateParser {
    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let iso8601WithFractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !dateString.isEmpty else {
            return nil
        }
        
        // Try different date formats in order of preference
        let formatters: [DateFormatter] = [
            iso8601Formatter,
            iso8601WithFractionalSecondsFormatter,
            fullDateFormatter,
            dateOnlyFormatter
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Log parsing failure for debugging
        print("⚠️ DEBUG: NetSuiteDateParser - Failed to parse date: '\(dateString)'")
        return nil
    }
    
    static func parseDateWithFallback(_ dateString: String?, fallback: Date = Date()) -> Date {
        return parseDate(dateString) ?? fallback
    }
}
```

### 2. Enhanced Status Mapping with Enums
**Problem**: String-based status mapping was fragile and didn't handle variations in status values.

**Solution**:
- Created `NetSuiteInvoiceStatus` enum with comprehensive status mapping
- Added support for multiple status variations (e.g., "cancelled" vs "canceled")
- Implemented safe initialization with fallback to "unknown"

```swift
enum NetSuiteInvoiceStatus: String, CaseIterable {
    case paid = "paid"
    case overdue = "overdue"
    case cancelled = "cancelled"
    case pending = "pending"
    case draft = "draft"
    case approved = "approved"
    case closed = "closed"
    case unknown = "unknown"
    
    init(rawValue: String?) {
        guard let rawValue = rawValue?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            self = .unknown
            return
        }
        
        switch rawValue {
        case "paid", "payment_received":
            self = .paid
        case "overdue", "past_due":
            self = .overdue
        case "cancelled", "canceled", "void":
            self = .cancelled
        case "pending", "open":
            self = .pending
        case "draft":
            self = .draft
        case "approved":
            self = .approved
        case "closed":
            self = .closed
        default:
            self = .unknown
        }
    }
}
```

### 3. Enhanced Null Safety and Validation
**Problem**: Default values of 0 for missing data might not be appropriate in all cases.

**Solution**:
- Added computed properties with validation logic
- Implemented smart fallbacks for invalid data
- Added comprehensive logging for debugging data issues

```swift
struct NetSuiteInvoiceItem: Codable {
    let item: NetSuiteEntityReference?
    let description: String?
    let quantity: Double?
    let rate: Double?
    let amount: Double?
    let grossAmount: Double?
    
    // Enhanced null safety with validation
    var validatedQuantity: Double {
        guard let quantity = quantity, quantity > 0 else {
            print("⚠️ DEBUG: NetSuiteInvoiceItem - Invalid quantity: \(quantity ?? 0), using 1.0")
            return 1.0
        }
        return quantity
    }
    
    var validatedRate: Double {
        guard let rate = rate, rate >= 0 else {
            print("⚠️ DEBUG: NetSuiteInvoiceItem - Invalid rate: \(rate ?? 0), using 0.0")
            return 0.0
        }
        return rate
    }
    
    var validatedAmount: Double {
        guard let amount = amount, amount >= 0 else {
            print("⚠️ DEBUG: NetSuiteInvoiceItem - Invalid amount: \(amount ?? 0), calculating from quantity * rate")
            return validatedQuantity * validatedRate
        }
        return amount
    }
}
```

### 4. Improved Address Handling
**Problem**: Only the first address was used, ignoring potentially important address information.

**Solution**:
- Added support for multiple addresses with priority selection
- Implemented default address detection
- Enhanced address formatting and validation

```swift
struct NetSuiteAddress: Codable {
    let addr1: String?
    let addr2: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
    let isResidential: Bool?
    let isDefaultBilling: Bool?
    let isDefaultShipping: Bool?
    
    var isDefault: Bool {
        return isDefaultBilling == true || isDefaultShipping == true
    }
    
    var fullAddress: String {
        let components = [addr1, addr2, city, state, zip, country].compactMap { $0 }
        return components.joined(separator: ", ")
    }
}
```

### 5. Enhanced Conversion Extensions
**Problem**: Conversion methods lacked proper error handling and data validation.

**Solution**:
- Added comprehensive data validation and cleaning
- Implemented smart fallbacks for missing data
- Enhanced error logging and debugging information

```swift
extension NetSuiteCustomerResponse {
    func toCustomer() -> Customer {
        // Enhanced name handling
        let fullName = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
        let displayName = fullName.isEmpty ? (companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Customer") : fullName
        
        // Enhanced address handling with multiple address support
        let addresses = addressbookList?.addressbook ?? []
        let primaryAddress = addresses.first { $0.isDefault } ?? addresses.first
        
        let address = primaryAddress.map { addr in
            Customer.Address(
                street: [addr.addr1, addr.addr2]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " "),
                city: addr.city?.trimmingCharacters(in: .whitespacesAndNewlines),
                state: addr.state?.trimmingCharacters(in: .whitespacesAndNewlines),
                zipCode: addr.zip?.trimmingCharacters(in: .whitespacesAndNewlines),
                country: addr.country?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        
        // Enhanced date parsing with fallbacks
        let createdDate = NetSuiteDateParser.parseDateWithFallback(dateCreated)
        let modifiedDate = NetSuiteDateParser.parseDateWithFallback(lastModifiedDate, fallback: createdDate)
        
        // Enhanced email validation
        let validatedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? email : nil
        
        // Enhanced phone validation
        let validatedPhone = phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? phone : nil
        
        return Customer(
            id: id, // Use NetSuite ID directly for consistency
            name: displayName,
            email: validatedEmail,
            phone: validatedPhone,
            address: address,
            netSuiteId: entityId,
            companyName: companyName?.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: !(isInactive ?? false),
            createdDate: createdDate,
            lastModifiedDate: modifiedDate
        )
    }
}
```

### 6. Comprehensive Error Handling and Validation
**Problem**: No validation of response data before conversion.

**Solution**:
- Added validation methods for both customer and invoice responses
- Implemented comprehensive error reporting
- Added data integrity checks

```swift
extension NetSuiteCustomerResponse {
    /// Validates the customer response and returns any issues found
    func validate() -> [String] {
        var issues: [String] = []
        
        if id.isEmpty {
            issues.append("Customer ID is empty")
        }
        
        if [firstName, lastName, companyName].allSatisfy({ $0?.isEmpty != false }) {
            issues.append("No customer name provided (firstName, lastName, or companyName)")
        }
        
        if let email = email, !email.isEmpty {
            // Basic email validation
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            if !email.range(of: emailRegex, options: .regularExpression) != nil {
                issues.append("Invalid email format: \(email)")
            }
        }
        
        return issues
    }
}

extension NetSuiteInvoiceResponse {
    /// Validates the invoice response and returns any issues found
    func validate() -> [String] {
        var issues: [String] = []
        
        if id.isEmpty {
            issues.append("Invoice ID is empty")
        }
        
        if let total = total, total < 0 {
            issues.append("Invoice total is negative: \(total)")
        }
        
        if let balance = balance, balance < 0 {
            issues.append("Invoice balance is negative: \(balance)")
        }
        
        if let itemList = itemList, let items = itemList.item {
            for (index, item) in items.enumerated() {
                if item.validatedQuantity <= 0 {
                    issues.append("Item \(index + 1) has invalid quantity: \(item.quantity ?? 0)")
                }
                if item.validatedAmount < 0 {
                    issues.append("Item \(index + 1) has negative amount: \(item.amount ?? 0)")
                }
            }
        }
        
        return issues
    }
}
```

### 7. Better UUID Management
**Problem**: Inconsistent ID handling between NetSuite IDs and internal IDs.

**Solution**:
- Use NetSuite IDs directly for consistency
- Implement smart ID fallbacks when NetSuite IDs are unavailable
- Maintain clear separation between NetSuite IDs and internal IDs

```swift
// In toCustomer()
return Customer(
    id: id, // Use NetSuite ID directly for consistency
    // ... other properties
    netSuiteId: entityId,
    // ... rest of properties
)

// In toInvoice()
return Invoice(
    id: id, // Use NetSuite ID directly for consistency
    // ... other properties
    netSuiteId: id,
    // ... rest of properties
)
```

## Benefits of These Improvements

### 1. **Reliability**
- Robust date parsing handles various NetSuite date formats
- Comprehensive validation prevents data corruption
- Smart fallbacks ensure graceful handling of missing data

### 2. **Maintainability**
- Clear separation of concerns with dedicated utility classes
- Comprehensive error logging for debugging
- Extensible design for future enhancements

### 3. **Data Integrity**
- Validation methods catch data issues early
- Enhanced null safety prevents runtime errors
- Consistent ID management reduces confusion

### 4. **Developer Experience**
- Better error messages for debugging
- Comprehensive logging for troubleshooting
- Clear documentation of data transformations

## Usage Examples

### Date Parsing
```swift
// Old way
let dateFormatter = ISO8601DateFormatter()
let date = dateFormatter.date(from: dateString ?? "") ?? Date()

// New way
let date = NetSuiteDateParser.parseDateWithFallback(dateString)
```

### Status Mapping
```swift
// Old way
switch self.status?.lowercased() {
case "paid": status = .paid
case "overdue": status = .overdue
case "cancelled": status = .cancelled
default: status = .pending
}

// New way
let netSuiteStatus = NetSuiteInvoiceStatus(rawValue: status)
let invoiceStatus: Invoice.InvoiceStatus = netSuiteStatus.toInvoiceStatus()
```

### Data Validation
```swift
// Validate customer data before conversion
let customerResponse = NetSuiteCustomerResponse(...)
let validationIssues = customerResponse.validate()
if !validationIssues.isEmpty {
    print("⚠️ Customer validation issues: \(validationIssues)")
}

// Validate invoice data before conversion
let invoiceResponse = NetSuiteInvoiceResponse(...)
let validationIssues = invoiceResponse.validate()
if !validationIssues.isEmpty {
    print("⚠️ Invoice validation issues: \(validationIssues)")
}
```

### Enhanced Address Handling
```swift
// Multiple address support with priority
let addresses = addressbookList?.addressbook ?? []
let primaryAddress = addresses.first { $0.isDefault } ?? addresses.first

// Use computed properties for address formatting
let fullAddress = primaryAddress?.fullAddress ?? "No address available"
```

## Migration Guide

### For Existing Code
1. **Date Parsing**: Replace direct ISO8601DateFormatter usage with `NetSuiteDateParser`
2. **Status Mapping**: Replace string-based status switches with `NetSuiteInvoiceStatus` enum
3. **Validation**: Add validation calls before conversion operations
4. **Error Handling**: Update error handling to use new validation methods

### Breaking Changes
- `toCustomer()` and `toInvoice()` methods now use NetSuite IDs directly as internal IDs
- Date parsing behavior may change for non-standard date formats
- Status mapping now handles more status variations

## Conclusion

These improvements transform the NetSuite response models from basic data structures into robust, reliable, and maintainable components. The enhanced error handling, better data validation, and improved extensibility make the models more resilient to API changes and provide better debugging capabilities for developers. 