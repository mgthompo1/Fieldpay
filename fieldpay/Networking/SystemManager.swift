import Foundation
import Combine
import SwiftUI

enum AccountingSystem: String, CaseIterable {
    case none = "none"
    case netsuite = "netsuite"
    case xero = "xero"
    case quickbooks = "quickbooks"
    case salesforce = "salesforce"
    
    var displayName: String {
        switch self {
        case .none: return "None (Standalone Mode)"
        case .netsuite: return "NetSuite"
        case .xero: return "Xero"
        case .quickbooks: return "QuickBooks"
        case .salesforce: return "Salesforce"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "building.2"
        case .netsuite: return "building.2.fill"
        case .xero: return "x.circle.fill"
        case .quickbooks: return "q.circle.fill"
        case .salesforce: return "cloud.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .netsuite: return .green
        case .xero: return .blue
        case .quickbooks: return .orange
        case .salesforce: return .purple
        }
    }
}

@MainActor
class SystemManager: ObservableObject {
    static let shared = SystemManager()
    
    @Published var currentSystem: AccountingSystem = .none
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Not Connected"
    
    private let userDefaults = UserDefaults.standard
    private let oAuthManager = OAuthManager.shared
    private let xeroOAuthManager = XeroOAuthManager.shared
    private let quickBooksOAuthManager = QuickBooksOAuthManager.shared
    private let salesforceOAuthManager = SalesforceOAuthManager.shared
    
    private init() {
        loadCurrentSystem()
        updateConnectionStatus()
    }
    
    // MARK: - System Management
    func connectToSystem(_ system: AccountingSystem) async throws {
        print("Debug: SystemManager - connectToSystem called for: \(system.displayName)")
        print("Debug: SystemManager - current system: \(currentSystem.displayName)")
        
        // Only disconnect if we're switching to a different system
        if currentSystem != system {
            print("Debug: SystemManager - Switching from \(currentSystem.displayName) to \(system.displayName), disconnecting current system")
            await disconnectFromCurrentSystem()
        } else {
            print("Debug: SystemManager - Already connected to \(system.displayName), skipping disconnect")
        }
        
        switch system {
        case .netsuite:
            print("Debug: SystemManager - Connecting to NetSuite...")
            try await connectToNetSuite()
        case .xero:
            print("Debug: SystemManager - Connecting to Xero...")
            try await connectToXero()
        case .quickbooks:
            print("Debug: SystemManager - Connecting to QuickBooks...")
            try await connectToQuickBooks()
        case .salesforce:
            print("Debug: SystemManager - Connecting to Salesforce...")
            try await connectToSalesforce()
        case .none:
            print("Debug: SystemManager - Setting standalone mode...")
            await setStandaloneMode()
        }
        
        currentSystem = system
        userDefaults.set(system.rawValue, forKey: "current_accounting_system")
        updateConnectionStatus()
        print("Debug: SystemManager - Successfully connected to \(system.displayName)")
    }
    
    func disconnectFromCurrentSystem() async {
        print("Debug: SystemManager - disconnectFromCurrentSystem called for: \(currentSystem.displayName)")
        
        switch currentSystem {
        case .netsuite:
            print("Debug: SystemManager - Clearing NetSuite OAuth tokens")
            oAuthManager.clearTokens()
        case .xero:
            print("Debug: SystemManager - Clearing Xero OAuth tokens")
            xeroOAuthManager.clearTokens()
        case .quickbooks:
            print("Debug: SystemManager - Clearing QuickBooks OAuth tokens")
            quickBooksOAuthManager.clearTokens()
        case .salesforce:
            print("Debug: SystemManager - Clearing Salesforce OAuth tokens")
            salesforceOAuthManager.clearTokens()
        case .none:
            print("Debug: SystemManager - No system to disconnect from")
            break
        }
        
        currentSystem = .none
        userDefaults.set(AccountingSystem.none.rawValue, forKey: "current_accounting_system")
        updateConnectionStatus()
        print("Debug: SystemManager - Successfully disconnected from system")
    }
    
    private func connectToNetSuite() async throws {
        print("Debug: SystemManager - connectToNetSuite called")
        print("Debug: SystemManager - OAuthManager.isAuthenticated: \(oAuthManager.isAuthenticated)")
        
        guard oAuthManager.isAuthenticated else {
            print("Debug: SystemManager - ERROR: NetSuite not authenticated")
            throw SystemManagerError.notAuthenticated
        }
        
        print("Debug: SystemManager - NetSuite authentication confirmed, setting connected = true")
        isConnected = true
    }
    
    private func connectToXero() async throws {
        guard xeroOAuthManager.isAuthenticated else {
            throw SystemManagerError.notAuthenticated
        }
        isConnected = true
    }
    
    private func connectToQuickBooks() async throws {
        guard quickBooksOAuthManager.isAuthenticated else {
            throw SystemManagerError.notAuthenticated
        }
        isConnected = true
    }
    
    private func connectToSalesforce() async throws {
        guard salesforceOAuthManager.isAuthenticated else {
            throw SystemManagerError.notAuthenticated
        }
        isConnected = true
    }
    
    private func setStandaloneMode() async {
        isConnected = false
    }
    
    // MARK: - Status Management
    private func loadCurrentSystem() {
        let systemString = userDefaults.string(forKey: "current_accounting_system") ?? "none"
        currentSystem = AccountingSystem(rawValue: systemString) ?? .none
    }
    
    private func updateConnectionStatus() {
        print("Debug: SystemManager - updateConnectionStatus called")
        print("Debug: SystemManager - currentSystem: \(currentSystem.displayName)")
        
        switch currentSystem {
        case .none:
            connectionStatus = "Standalone Mode"
            isConnected = false
            print("Debug: SystemManager - Set to standalone mode")
        case .netsuite:
            let isAuth = oAuthManager.isAuthenticated
            connectionStatus = isAuth ? "Connected to NetSuite" : "NetSuite Not Authenticated"
            isConnected = isAuth
            print("Debug: SystemManager - NetSuite status: \(connectionStatus), isConnected: \(isConnected)")
        case .xero:
            let isAuth = xeroOAuthManager.isAuthenticated
            connectionStatus = isAuth ? "Connected to Xero" : "Xero Not Authenticated"
            isConnected = isAuth
            print("Debug: SystemManager - Xero status: \(connectionStatus), isConnected: \(isConnected)")
        case .quickbooks:
            let isAuth = quickBooksOAuthManager.isAuthenticated
            connectionStatus = isAuth ? "Connected to QuickBooks" : "QuickBooks Not Authenticated"
            isConnected = isAuth
            print("Debug: SystemManager - QuickBooks status: \(connectionStatus), isConnected: \(isConnected)")
        case .salesforce:
            let isAuth = salesforceOAuthManager.isAuthenticated
            connectionStatus = isAuth ? "Connected to Salesforce" : "Salesforce Not Authenticated"
            isConnected = isAuth
            print("Debug: SystemManager - Salesforce status: \(connectionStatus), isConnected: \(isConnected)")
        }
    }
    
    // MARK: - System Information
    func getCurrentSystemInfo() -> (system: AccountingSystem, isConnected: Bool, status: String) {
        return (currentSystem, isConnected, connectionStatus)
    }
    
    func isInStandaloneMode() -> Bool {
        return currentSystem == .none
    }
    
    func canConnectToSystem(_ system: AccountingSystem) -> Bool {
        switch system {
        case .netsuite:
            return oAuthManager.isAuthenticated
        case .xero:
            return xeroOAuthManager.isAuthenticated
        case .quickbooks:
            return quickBooksOAuthManager.isAuthenticated
        case .salesforce:
            return salesforceOAuthManager.isAuthenticated
        case .none:
            return true
        }
    }
    
    // MARK: - API Access
    func getCurrentOAuthManager() -> Any? {
        switch currentSystem {
        case .netsuite:
            return oAuthManager
        case .xero:
            return xeroOAuthManager
        case .quickbooks:
            return quickBooksOAuthManager
        case .salesforce:
            return salesforceOAuthManager
        case .none:
            return nil
        }
    }
    
    func getValidAccessToken() async throws -> String {
        switch currentSystem {
        case .netsuite:
            return try await oAuthManager.getValidAccessToken()
        case .xero:
            return try await xeroOAuthManager.getValidAccessToken()
        case .quickbooks:
            return try await quickBooksOAuthManager.getValidAccessToken()
        case .salesforce:
            return try await salesforceOAuthManager.getValidAccessToken()
        case .none:
            throw SystemManagerError.noSystemConnected
        }
    }
}

// MARK: - Errors
enum SystemManagerError: Error, LocalizedError {
    case notAuthenticated
    case noSystemConnected
    case systemNotSupported
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "System not authenticated. Please complete OAuth setup first."
        case .noSystemConnected:
            return "No accounting system connected. Running in standalone mode."
        case .systemNotSupported:
            return "This accounting system is not supported."
        }
    }
} 