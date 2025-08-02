import Foundation

/// NetSuite Customer Record - Detailed customer information from NetSuite API
struct NetSuiteCustomerRecord: Codable {
    let id: String
    let entityId: String?
    let companyName: String?
    let email: String?
    let phone: String?
    let isInactive: Bool?
    let dateCreated: String?
    let lastModifiedDate: String?
    let addressbook: [AddressBookEntry]?
    
    // Additional fields that might be present
    let subsidiary: Reference?
    let customFieldList: [CustomField]?
    
    enum CodingKeys: String, CodingKey {
        case id, entityId, companyName, email, phone, isInactive, dateCreated, lastModifiedDate, addressbook, subsidiary, customFieldList
    }
}

// MARK: - Address Book Models

/// Address book entry for customer
struct AddressBookEntry: Codable {
    let defaultBilling: Bool?
    let defaultShipping: Bool?
    let label: String?
    let addressbookAddress: Address?
    
    // Additional fields
    let attention: String?
    let addr2: String?
    let addr3: String?
    let phone: String?
    let fax: String?
    let addrText: String?
    let override: Bool?
    let customFieldList: [CustomField]?
}

/// Physical address structure
struct Address: Codable {
    let addr1: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
    
    // Additional address fields
    let attention: String?
    let addr2: String?
    let addr3: String?
    let phone: String?
    let fax: String?
    let addrText: String?
    
    enum CodingKeys: String, CodingKey {
        case addr1, city, state, zip, country, attention, addr2, addr3, phone, fax, addrText
    }
}

// MARK: - Reference Models
// Using shared types from NetSuiteInvoiceRecord.swift

// MARK: - Convenience Extensions

extension NetSuiteCustomerRecord {
    /// Convert to your existing Customer model
    func toCustomer() -> Customer {
        let createdDate = NetSuiteDateParser.parseDateWithFallback(dateCreated)
        
        // Get primary address
        let primaryAddress = addressbook?.first(where: { $0.defaultBilling == true })?.addressbookAddress
        let customerAddress = Customer.Address(
            street: primaryAddress?.addr1,
            city: primaryAddress?.city,
            state: primaryAddress?.state,
            zipCode: primaryAddress?.zip,
            country: primaryAddress?.country
        )
        
        // Enhanced customer name handling with better fallback logic
        let trimmedEntityId = entityId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompanyName = companyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract customer name from company name if it contains parentheses with name
        let customerName: String
        if let companyName = trimmedCompanyName, !companyName.isEmpty {
            // Check if company name contains a name in parentheses (e.g., "Default Customer (Wilman Arambillete, ...)")
            if let nameStart = companyName.range(of: "("),
               let nameEnd = companyName.range(of: ",", range: nameStart.upperBound..<companyName.endIndex) {
                let extractedName = String(companyName[nameStart.upperBound..<nameEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !extractedName.isEmpty {
                    customerName = extractedName
                } else {
                    customerName = companyName
                }
            } else {
                customerName = companyName
            }
        } else if let entityId = trimmedEntityId, !entityId.isEmpty {
            // Only use entityId if it looks like a name (not a numeric ID)
            if entityId.range(of: "^[0-9]+$", options: .regularExpression) == nil {
                customerName = entityId
            } else {
                customerName = "Customer \(id)"
            }
        } else {
            customerName = "Customer \(id)"
        }
        
        return Customer(
            id: id,
            name: customerName,
            email: email?.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone?.trimmingCharacters(in: .whitespacesAndNewlines),
            address: customerAddress,
            netSuiteId: id,
            companyName: companyName?.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: !(isInactive ?? false),
            createdDate: createdDate,
            lastModifiedDate: NetSuiteDateParser.parseDateWithFallback(lastModifiedDate)
        )
    }
    
    // MARK: - Convenience Accessors
    
    var displayName: String {
        let trimmedCompanyName = companyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEntityId = entityId?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract customer name from company name if it contains parentheses with name
        if let companyName = trimmedCompanyName, !companyName.isEmpty {
            // Check if company name contains a name in parentheses (e.g., "Default Customer (Wilman Arambillete, ...)")
            if let nameStart = companyName.range(of: "("),
               let nameEnd = companyName.range(of: ",", range: nameStart.upperBound..<companyName.endIndex) {
                let extractedName = String(companyName[nameStart.upperBound..<nameEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !extractedName.isEmpty {
                    return extractedName
                } else {
                    return companyName
                }
            } else {
                return companyName
            }
        } else if let entityId = trimmedEntityId, !entityId.isEmpty {
            // Only use entityId if it looks like a name (not a numeric ID)
            if entityId.range(of: "^[0-9]+$", options: .regularExpression) == nil {
                return entityId
            } else {
                return "Customer \(id)"
            }
        } else {
            return "Customer \(id)"
        }
    }
    
    var formattedBalance: String {
        // This would need to be calculated from transactions
        return "$0.00"
    }
    
    var isActive: Bool {
        return !(isInactive ?? false)
    }
    
    var primaryBillingAddress: Address? {
        return addressbook?.first(where: { $0.defaultBilling == true })?.addressbookAddress
    }
    
    var primaryShippingAddress: Address? {
        return addressbook?.first(where: { $0.defaultShipping == true })?.addressbookAddress
    }
    
    var addressSummary: String {
        guard let address = primaryBillingAddress else { return "No address" }
        
        var parts: [String] = []
        if let addr1 = address.addr1, !addr1.isEmpty { parts.append(addr1) }
        if let city = address.city, !city.isEmpty { parts.append(city) }
        if let state = address.state, !state.isEmpty { parts.append(state) }
        if let zip = address.zip, !zip.isEmpty { parts.append(zip) }
        
        return parts.isEmpty ? "No address" : parts.joined(separator: ", ")
    }
    
    var contactSummary: String {
        var parts: [String] = []
        if let email = email, !email.isEmpty { parts.append(email) }
        if let phone = phone, !phone.isEmpty { parts.append(phone) }
        return parts.isEmpty ? "No contact info" : parts.joined(separator: " • ")
    }
    
    var hasOutstandingBalance: Bool {
        // This would need to be calculated from transactions
        return false
    }
    
    var daysSinceLastOrder: Int? {
        // This would need to be calculated from order history
        return nil
    }
    
    var statusSummary: String {
        if isInactive == true {
            return "Inactive"
        } else {
            return "Active"
        }
    }
} 