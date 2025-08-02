import Foundation

struct Customer: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let email: String?
    let phone: String?
    let address: Address?
    let netSuiteId: String?
    let companyName: String?
    let isActive: Bool
    let createdDate: Date
    let lastModifiedDate: Date
    
    struct Address: Codable, Equatable {
        let street: String?
        let city: String?
        let state: String?
        let zipCode: String?
        let country: String?
    }
    
    init(id: String = UUID().uuidString,
         name: String,
         email: String? = nil,
         phone: String? = nil,
         address: Address? = nil,
         netSuiteId: String? = nil,
         companyName: String? = nil,
         isActive: Bool = true,
         createdDate: Date = Date(),
         lastModifiedDate: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.address = address
        self.netSuiteId = netSuiteId
        self.companyName = companyName
        self.isActive = isActive
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
    }
} 