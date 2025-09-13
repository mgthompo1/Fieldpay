# NetSuite BUILTIN.CF and BUILTIN.DF Functions Usage in FieldPay

## Overview

FieldPay now implements two critical NetSuite SuiteQL functions:

- **`BUILTIN.CF`** - Returns combined field values for composite key fields (e.g., `transaction.status`)
- **`BUILTIN.DF`** - Returns display values from related record types without explicit JOINs (e.g., customer names, item names)

These functions work together to provide accurate, human-readable data from NetSuite without complex queries or multiple API calls.

## Why These Functions Are Important

### BUILTIN.CF (Combined Field Values)
Without `BUILTIN.CF`, querying fields like `transaction.status` may return incomplete or incorrect values:
- `SELECT status FROM transaction` might return just 'B' (representing "paid in full")
- `SELECT BUILTIN.CF(status) FROM transaction` returns 'CustInv: B' (representing "paid in full invoice")

### BUILTIN.DF (Display Field Values)
Without `BUILTIN.DF`, you get only IDs and must make additional queries to get human-readable names:
- `SELECT entity FROM transaction` returns customer ID like '12345'
- `SELECT BUILTIN.DF(entity) FROM transaction` returns customer name like 'Acme Corporation'

## Implementation in FieldPay

### Updated SuiteQL Queries

All transaction-related queries in FieldPay now use both functions where appropriate:

```swift
// Before (incomplete data)
SELECT t.id, t.status, t.entity FROM transaction t

// After (complete data with both functions)
SELECT 
    t.id, 
    BUILTIN.CF(t.status) as status,
    BUILTIN.DF(t.entity) as customer_name
FROM transaction t
```

### New Display Value Query Methods

FieldPay now includes dedicated methods for fetching data with display values:

```swift
// Fetch transactions with customer names
let transactions = try await netSuiteAPI.fetchTransactionsWithDisplayValues()

// Fetch invoices with customer names
let invoices = try await netSuiteAPI.fetchInvoicesWithDisplayValues()

// Fetch payments with customer names
let payments = try await netSuiteAPI.fetchPaymentsWithDisplayValues()

// Fetch sales orders with customer names
let salesOrders = try await netSuiteAPI.fetchSalesOrdersWithDisplayValues()
```

### Common Status Values (BUILTIN.CF)

When using `BUILTIN.CF`, you'll get status values in this format:

- **Invoices**: `CustInv: A` (pending approval), `CustInv: B` (paid in full), `CustInv: C` (closed)
- **Payments**: `CustPymt: A` (pending), `CustPymt: B` (approved), `CustPymt: C` (cleared)
- **Sales Orders**: `SOrd: A` (pending approval), `SOrd: B` (approved), `SOrd: C` (closed)

### Common Display Values (BUILTIN.DF)

When using `BUILTIN.DF`, you'll get human-readable values:

- **Customer Names**: `BUILTIN.DF(t.entity)` returns "Acme Corporation" instead of "12345"
- **Item Names**: `BUILTIN.DF(t.item)` returns "Premium Widget" instead of "ITEM_001"
- **Location Names**: `BUILTIN.DF(t.location)` returns "Main Warehouse" instead of "LOC_001"

## Usage Examples

### 1. Combined Usage for Complete Data

```swift
// Get invoices with both status and customer names
let invoices = try await netSuiteAPI.fetchInvoicesWithDisplayValues()

// Each invoice now has:
// - status: "CustInv: B" (from BUILTIN.CF)
// - customerName: "Acme Corporation" (from BUILTIN.DF)
```

### 2. Custom SuiteQL with Both Functions

```swift
let customQuery = """
SELECT 
    t.id,
    t.tranid,
    BUILTIN.CF(t.status) as status,
    BUILTIN.DF(t.entity) as customer_name,
    BUILTIN.DF(t.item) as item_name
FROM transaction t
WHERE t.type = 'CustInvc' 
AND BUILTIN.CF(t.status) = 'CustInv: B'
"""

let resource = NetSuiteResource.suiteQL(query: customQuery)
let response: SuiteQLResponse = try await netSuiteAPI.fetch(resource, type: SuiteQLResponse.self)
```

### 3. Status Filtering with Display Values

```swift
// Get all paid invoices with customer names
let paidInvoices = try await netSuiteAPI.fetchInvoicesWithStatus("CustInv: B")

// Get all cleared payments with customer names
let clearedPayments = try await netSuiteAPI.fetchPaymentsWithStatus("CustPymt: C")
```

## Best Practices

1. **Always use BUILTIN.CF for status fields** when querying transaction data
2. **Use BUILTIN.DF for entity, item, and location fields** to get human-readable names
3. **Combine both functions** for comprehensive data retrieval
4. **Use the new convenience methods** instead of building custom queries when possible
5. **Test your queries** with actual NetSuite data to ensure correct values

## Migration Notes

If you have existing code that queries NetSuite data without these functions, you should:

1. Update your SuiteQL queries to use `BUILTIN.CF(t.status)` for status fields
2. Add `BUILTIN.DF(t.entity)` for customer names and other display values
3. Update your data models to handle the new combined format
4. Consider using the new convenience methods for common data retrieval patterns

## Testing

Use the NetSuite Debug View in FieldPay to test both functions:

- **"Test BUILTIN.CF"** - Tests status value retrieval and filtering
- **"Test BUILTIN.DF"** - Tests display value retrieval from related records

## Performance Considerations

- **BUILTIN.CF** adds minimal overhead but is necessary for accurate status values
- **BUILTIN.DF** eliminates the need for multiple queries or JOINs
- Both functions are optimized by NetSuite and provide the most efficient way to retrieve complete data

## Troubleshooting

### Common Issues

1. **Status values not matching**: Ensure you're using `BUILTIN.CF` for status fields
2. **Customer names not appearing**: Ensure you're using `BUILTIN.DF(t.entity)` for customer names
3. **Performance issues**: These functions are optimized by NetSuite and should be fast

### Debug Queries

Use the debug tools to test your queries:

```swift
// Test status retrieval
let testQuery = SuiteQLQuery.invoicesWithStatusFilter(statusFilter: "CustInv: B").query
print("Debug Query: \(testQuery)")

// Test display values
let displayQuery = SuiteQLQuery.invoicesWithDisplayValues.query
print("Display Query: \(displayQuery)")
```

## References

- [NetSuite BUILTIN.CF Documentation](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/article_159266079391.html)
- [NetSuite BUILTIN.DF Documentation](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/article_159266079391.html)
- [NetSuite SuiteQL Guide](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/article_159266079391.html)
- [FieldPay NetSuite Integration](fieldpay/Networking/NetSuiteAPI.swift)
