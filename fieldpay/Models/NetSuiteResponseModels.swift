import Foundation

// MARK: - NetSuite API Response Models

// Generic NetSuite response wrapper
struct NetSuiteResponse<T: Codable>: Codable {
    let links: [NetSuiteLink]?
    let count: Int?
    let hasMore: Bool?
    let offset: Int?
    let items: [T]
    
    enum CodingKeys: String, CodingKey {
        case links = "links"
        case count = "count"
        case hasMore = "hasMore"
        case offset = "offset"
        case items = "items"
    }
}

struct NetSuiteLink: Codable {
    let rel: String
    let href: String
}

// MARK: - Enhanced Status Enums

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

// MARK: - Enhanced Date Parsing

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
        
        // Try ISO8601 formatters first
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        if let date = iso8601WithFractionalSecondsFormatter.date(from: dateString) {
            return date
        }
        
        // Try DateFormatter formats
        if let date = fullDateFormatter.date(from: dateString) {
            return date
        }
        
        if let date = dateOnlyFormatter.date(from: dateString) {
            return date
        }
        
        // Log parsing failure for debugging
        print("⚠️ DEBUG: NetSuiteDateParser - Failed to parse date: '\(dateString)'")
        return nil
    }
    
    static func parseDateWithFallback(_ dateString: String?, fallback: Date = Date()) -> Date {
        return parseDate(dateString) ?? fallback
    }
}

// MARK: - Enhanced Customer Response Model

struct NetSuiteCustomerResponse: Codable {
    let id: String
    let entityId: String?
    let companyName: String?
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    let addressbookList: NetSuiteAddressBookList?
    let isInactive: Bool?
    let dateCreated: String?
    let lastModifiedDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case entityId = "entityId"
        case companyName = "companyName"
        case firstName = "firstName"
        case lastName = "lastName"
        case email = "email"
        case phone = "phone"
        case addressbookList = "addressbookList"
        case isInactive = "isInactive"
        case dateCreated = "dateCreated"
        case lastModifiedDate = "lastModifiedDate"
    }
}

struct NetSuiteAddressBookList: Codable {
    let addressbook: [NetSuiteAddress]?
}

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

// MARK: - Enhanced Invoice Response Model

struct NetSuiteInvoiceResponse: Codable {
    let id: String
    let tranId: String?
    let entity: NetSuiteEntityReference?
    let tranDate: String?
    let dueDate: String?
    let total: Double?
    let balance: Double?
    let memo: String?
    let status: String?
    let itemList: NetSuiteItemList?
    let dateCreated: String?
    let lastModifiedDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case tranId = "tranId"
        case entity = "entity"
        case tranDate = "tranDate"
        case dueDate = "dueDate"
        case total = "total"
        case balance = "balance"
        case memo = "memo"
        case status = "status"
        case itemList = "itemList"
        case dateCreated = "dateCreated"
        case lastModifiedDate = "lastModifiedDate"
    }
}

struct NetSuiteEntityReference: Codable {
    let id: String?
    let refName: String?
}

struct NetSuiteItemList: Codable {
    let item: [NetSuiteInvoiceItem]?
}

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

// MARK: - Enhanced Conversion Extensions

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

extension NetSuiteInvoiceResponse {
    func toInvoice() -> Invoice {
        // Enhanced date parsing with fallbacks
        let createdDate = NetSuiteDateParser.parseDateWithFallback(dateCreated)
        let _ = NetSuiteDateParser.parseDateWithFallback(lastModifiedDate, fallback: createdDate)
        let dueDate = NetSuiteDateParser.parseDate(dueDate)
        
        // Enhanced item processing with better error handling
        let items = itemList?.item?.compactMap { item -> Invoice.InvoiceItem? in
            // Skip items with invalid data
            guard item.validatedQuantity > 0 || item.validatedAmount > 0 else {
                print("⚠️ DEBUG: NetSuiteInvoiceResponse - Skipping invalid item: \(item.description ?? "Unknown")")
                return nil
            }
            
            return Invoice.InvoiceItem(
                id: item.item?.id ?? UUID().uuidString, // Use NetSuite item ID if available
                description: item.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Item",
                quantity: item.validatedQuantity,
                unitPrice: Decimal(item.validatedRate),
                amount: Decimal(item.validatedAmount),
                netSuiteItemId: item.item?.id
            )
        } ?? []
        
        // Enhanced status mapping using enum
        let netSuiteStatus = NetSuiteInvoiceStatus(rawValue: status)
        let invoiceStatus: Invoice.InvoiceStatus
        
        switch netSuiteStatus {
        case .paid:
            invoiceStatus = .paid
        case .overdue:
            invoiceStatus = .overdue
        case .cancelled:
            invoiceStatus = .cancelled
        case .pending, .draft, .approved, .closed, .unknown:
            invoiceStatus = .pending
        }
        
        // Enhanced amount validation
        let validatedTotal = max(0, total ?? 0)
        let validatedBalance = max(0, balance ?? validatedTotal)
        
        // Enhanced invoice number generation
        let invoiceNumber = tranId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false 
            ? tranId! 
            : "INV-\(id)"
        
        // Enhanced customer information
        let customerId = entity?.id ?? ""
        let customerName = entity?.refName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Customer"
        
        return Invoice(
            id: id, // Use NetSuite ID directly for consistency
            invoiceNumber: invoiceNumber,
            customerId: customerId,
            customerName: customerName,
            amount: Decimal(validatedTotal),
            balance: Decimal(validatedBalance),
            status: invoiceStatus,
            dueDate: dueDate,
            createdDate: createdDate,
            netSuiteId: id,
            items: items,
            notes: memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

// MARK: - Error Handling Extensions

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
            if email.range(of: emailRegex, options: .regularExpression) == nil {
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