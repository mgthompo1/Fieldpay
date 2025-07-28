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

// NetSuite Customer Response Model
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
}

// NetSuite Invoice Response Model
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
}

// MARK: - Conversion Extensions

extension NetSuiteCustomerResponse {
    func toCustomer() -> Customer {
        let fullName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        let displayName = fullName.isEmpty ? (companyName ?? "Unknown Customer") : fullName
        
        let address = addressbookList?.addressbook?.first.map { addr in
            Customer.Address(
                street: [addr.addr1, addr.addr2].compactMap { $0 }.joined(separator: " "),
                city: addr.city,
                state: addr.state,
                zipCode: addr.zip,
                country: addr.country
            )
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: dateCreated ?? "") ?? Date()
        let modifiedDate = dateFormatter.date(from: lastModifiedDate ?? "") ?? Date()
        
        return Customer(
            id: id,
            name: displayName,
            email: email,
            phone: phone,
            address: address,
            netSuiteId: entityId,
            companyName: companyName,
            isActive: !(isInactive ?? false),
            createdDate: createdDate,
            lastModifiedDate: modifiedDate
        )
    }
}

extension NetSuiteInvoiceResponse {
    func toInvoice() -> Invoice {
        let dateFormatter = ISO8601DateFormatter()
        let createdDate = dateFormatter.date(from: dateCreated ?? "") ?? Date()
        let modifiedDate = dateFormatter.date(from: lastModifiedDate ?? "") ?? Date()
        let dueDate = dateFormatter.date(from: self.dueDate ?? "")
        
        let items = itemList?.item?.map { item in
            Invoice.InvoiceItem(
                id: UUID().uuidString,
                description: item.description ?? "",
                quantity: item.quantity ?? 0,
                unitPrice: Decimal(item.rate ?? 0),
                amount: Decimal(item.amount ?? 0),
                netSuiteItemId: item.item?.id
            )
        } ?? []
        
        let status: Invoice.InvoiceStatus
        switch self.status?.lowercased() {
        case "paid":
            status = .paid
        case "overdue":
            status = .overdue
        case "cancelled":
            status = .cancelled
        default:
            status = .pending
        }
        
        return Invoice(
            id: id,
            invoiceNumber: tranId ?? "INV-\(id)",
            customerId: entity?.id ?? "",
            customerName: entity?.refName ?? "Unknown Customer",
            amount: Decimal(total ?? 0),
            balance: Decimal(balance ?? 0),
            status: status,
            dueDate: dueDate,
            createdDate: createdDate,
            netSuiteId: id,
            items: items,
            notes: memo
        )
    }
} 