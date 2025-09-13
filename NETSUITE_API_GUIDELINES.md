# NetSuite API Integration Guidelines

## Overview
This document provides comprehensive guidance on when to use NetSuite REST API vs SuiteQL, and how to ensure accurate data retrieval without background process interference.

## REST API vs SuiteQL: When to Use Each

### **Use REST API for:**

#### 1. **Simple CRUD Operations**
- Creating new records (customers, invoices, payments)
- Reading individual records by ID
- Updating existing records
- Deleting records (when supported)

#### 2. **Basic Entity Queries**
- Fetching lists of customers, invoices, or payments
- Simple filtering (by status, date range, etc.)
- Pagination support
- Standard record operations

#### 3. **When You Need Full Record Structure**
- Complete NetSuite record objects
- All available fields and relationships
- Standard NetSuite data types
- Built-in validation and error handling

#### 4. **Standard Operations**
```swift
// Example: Fetch customer by ID
let resource = NetSuiteResource.customerDetail(id: customerId)
let customer: NetSuiteCustomerRecord = try await netSuiteAPI.fetch(resource, type: NetSuiteCustomerRecord.self)

// Example: Create new payment
let payment = try await netSuiteAPI.createPayment(paymentData)
```

### **Use SuiteQL for:**

#### 1. **Complex Queries with Joins**
- Multiple table relationships
- Custom filtering logic
- Aggregated data (sums, counts, grouped results)
- Cross-entity queries

#### 2. **Custom Filtering**
- Complex WHERE clauses
- Multiple conditions
- Custom business logic
- When REST API filters are insufficient

#### 3. **Specific Field Selection**
- Only the fields you need
- Custom calculations
- Derived fields
- Performance optimization

#### 4. **Batch Operations**
- Multiple records in one query
- Bulk data processing
- Complex reporting queries

#### 5. **Examples:**
```swift
// Example: Complex customer invoice query with line items
let query = """
SELECT 
    t.id, t.tranid, t.trandate, t.total, t.status, t.memo, t.duedate,
    t.amountremaining, t.amountpaid, t.createddate, t.entity
FROM transaction t 
WHERE t.entity = '\(customerId)' AND t.type = 'CustInvc'
ORDER BY t.trandate DESC
"""

// Example: Payment history with custom filtering
let paymentQuery = """
SELECT 
    t.id, t.tranid, t.trandate, t.total, t.status, t.memo, t.entity,
    t.paymentmethod, t.createddate, t.currency
FROM transaction t 
WHERE t.entity = '\(customerId)' AND t.type = 'CustPymt'
AND t.trandate >= '\(fromDate)' AND t.status = 'Approved'
ORDER BY t.trandate DESC
"""
```

## **Data Fetching Best Practices**

### 1. **Prevent Background Process Interference**
- Use coordinated API calls
- Implement proper error handling
- Cache results to avoid duplicate requests
- Use semaphores for concurrent operations

```swift
// Example: Coordinated API calls
private func coordinateAPICalls<T>(_ operation: @escaping () async throws -> T) async throws -> T {
    return try await withCheckedThrowingContinuation { continuation in
        Task {
            do {
                let result = try await operation()
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### 2. **Batch Operations**
- Fetch related data together
- Reduce API call frequency
- Improve performance
- Better error handling

```swift
// Example: Batch customer data fetching
func fetchCustomerDataBatch(customerIds: [String]) async throws -> [String: CustomerData] {
    var customerData: [String: CustomerData] = [:]
    
    // Process in smaller batches
    let batchSize = 5
    for batch in stride(from: 0, to: customerIds.count, by: batchSize) {
        let endIndex = min(batch + batchSize, customerIds.count)
        let batchIds = Array(customerIds[batch..<endIndex])
        
        try await withThrowingTaskGroup(of: (String, CustomerData).self) { group in
            for customerId in batchIds {
                group.addTask {
                    let invoices = try await self.fetchCustomerInvoices(for: customerId)
                    let payments = try await self.fetchCustomerPayments(for: customerId)
                    let transactions = try await self.fetchCustomerTransactions(for: customerId)
                    
                    return (customerId, CustomerData(
                        invoices: invoices,
                        payments: payments,
                        transactions: transactions
                    ))
                }
            }
            
            for try await (customerId, data) in group {
                customerData[customerId] = data
            }
        }
        
        // Respectful delay between batches
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    return customerData
}
```

### 3. **Proper Error Handling**
- Implement retry logic
- Handle rate limiting
- Provide meaningful error messages
- Fallback mechanisms

```swift
// Example: Retry with exponential backoff
private func fetchWithRetry<T>(_ operation: @escaping () async throws -> T, maxRetries: Int = 3) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt)) * 0.5 // Exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }
        }
    }
    
    throw lastError ?? NetSuiteError.requestFailed
}
```

## **Common Use Cases and Recommendations**

### **Customer Management**
- **REST API**: Basic CRUD operations, simple queries
- **SuiteQL**: Complex filtering, bulk operations, custom reports

### **Invoice Management**
- **REST API**: Create invoices, fetch individual invoices
- **SuiteQL**: Customer invoice history, line item details, custom filtering

### **Payment Processing**
- **REST API**: Create payments, fetch payment records
- **SuiteQL**: Payment history, customer payment summaries, custom reports

### **Reporting and Analytics**
- **SuiteQL**: All reporting queries, aggregated data, custom calculations
- **REST API**: Not recommended for complex reporting

## **Performance Considerations**

### **REST API**
- Better for small datasets
- Built-in pagination
- Standard error handling
- Easier to implement

### **SuiteQL**
- Better for large datasets
- More efficient for complex queries
- Custom optimization possible
- Requires careful query design

## **Security Best Practices**

### **SQL Injection Prevention**
- Always sanitize user input
- Use parameterized queries when possible
- Validate data before using in queries

```swift
// Example: Safe query construction
private func sanitizeQuery(_ input: String) -> String {
    return input.replacingOccurrences(of: "'", with: "''")
}

let safeCustomerId = sanitizeQuery(customerId)
let query = "SELECT * FROM customer WHERE id = '\(safeCustomerId)'"
```

### **Authentication**
- Use OAuth tokens
- Implement proper token refresh
- Secure token storage
- Regular token validation

## **Monitoring and Debugging**

### **API Call Logging**
- Log all API requests and responses
- Monitor response times
- Track error rates
- Implement health checks

### **Debug Tools**
- Use NetSuite debug views
- Test queries in NetSuite console
- Monitor API usage limits
- Validate data consistency

## **Troubleshooting Common Issues**

### **Missing Line Items**
- Ensure proper JOIN clauses in SuiteQL
- Check transaction line relationships
- Verify item references
- Use enhanced queries with all necessary fields

### **Inconsistent Data**
- Implement proper caching
- Use coordinated API calls
- Validate data before display
- Implement retry mechanisms

### **Background Process Interference**
- Use semaphores for concurrent operations
- Implement proper task coordination
- Cache results to avoid duplicate requests
- Use batch operations when possible

## **Conclusion**

The key to successful NetSuite integration is understanding when to use each API type:

- **REST API**: For simple, standard operations
- **SuiteQL**: For complex queries and custom requirements
- **Coordinated calls**: To prevent interference and ensure data consistency
- **Proper caching**: To improve performance and reduce API calls
- **Error handling**: To provide robust user experience

By following these guidelines, you can ensure accurate data retrieval, prevent background process interference, and create a reliable NetSuite integration.
