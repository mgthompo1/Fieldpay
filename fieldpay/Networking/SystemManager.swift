import Foundation
import Combine
import SwiftUI

// MARK: - Debug Logging Configuration
struct DebugLogConfig {
    static let shared = DebugLogConfig()
    
    // Master debug logging toggle
    let debugLoggingEnabled = false  // Debug logging disabled for quiet operation
    
    // Individual category toggles to reduce noise
    let logSystemManager = false  // Turn off system manager logging
    let logTokenValidation = false  // Reduce repetitive token validation logs
    let logConfigurationLoading = false  // Reduce repetitive config loading logs
    let logConnectionStatus = false  // Turn off connection status logging
    let logAPIRequests = false  // Turn off API request logging
    let logErrorDetails = false  // Turn off error logging for quiet operation
    let logSuiteQLResponses = false  // Turn off SuiteQL response logging for quiet operation
    
    private init() {}
}

enum TokenHealthStatus {
    case healthy
    case expired
    case notAuthenticated
    case noSystem
    
    var description: String {
        switch self {
        case .healthy:
            return "Token is valid"
        case .expired:
            return "Token has expired"
        case .notAuthenticated:
            return "System not authenticated"
        case .noSystem:
            return "No system connected"
        }
    }
}

enum AccountingSystem: String, CaseIterable {
    case none = "none"
    case netsuite = "netsuite"
    case quickbooks = "quickbooks"
    case salesforce = "salesforce"
    
    var displayName: String {
        switch self {
        case .none: return "None (Standalone Mode)"
        case .netsuite: return "NetSuite"
        case .quickbooks: return "QuickBooks"
        case .salesforce: return "Salesforce"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "building.2"
        case .netsuite: return "building.2.fill"
        case .quickbooks: return "q.circle.fill"
        case .salesforce: return "cloud.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .netsuite: return .green
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
    private let quickBooksOAuthManager = QuickBooksOAuthManager.shared
    private let salesforceOAuthManager = SalesforceOAuthManager.shared
    
    private init() {
        loadCurrentSystem()
        // Note: updateConnectionStatus() will be called after state recovery
        // We'll call validateAndRecoverSystemState() from the app's main entry point
    }
    
    // MARK: - System Management
    func connectToSystem(_ system: AccountingSystem) async throws {
        if DebugLogConfig.shared.logSystemManager {
            print("🔗 SystemManager - Connecting to: \(system.displayName)")
        }
        
        // Update status to show connection attempt
        connectionStatus = "Connecting to \(system.displayName)..."
        
        // Only disconnect if we're switching to a different system
        if currentSystem != system {
            if DebugLogConfig.shared.logSystemManager {
                print("🔄 SystemManager - Switching from \(currentSystem.displayName) to \(system.displayName)")
            }
            await disconnectFromCurrentSystem()
        } else if DebugLogConfig.shared.logSystemManager {
            print("ℹ️ SystemManager - Already connected to \(system.displayName)")
        }
        
        do {
            switch system {
            case .netsuite:
                if DebugLogConfig.shared.logSystemManager {
                    print("🔗 SystemManager - Connecting to NetSuite...")
                }
                try await connectToNetSuite()
            case .quickbooks:
                if DebugLogConfig.shared.logSystemManager {
                    print("🔗 SystemManager - Connecting to QuickBooks...")
                }
                try await connectToQuickBooks()
            case .salesforce:
                if DebugLogConfig.shared.logSystemManager {
                    print("🔗 SystemManager - Connecting to Salesforce...")
                }
                try await connectToSalesforce()
            case .none:
                if DebugLogConfig.shared.logSystemManager {
                    print("🔗 SystemManager - Setting standalone mode...")
                }
                await setStandaloneMode()
            }
            
            currentSystem = system
            userDefaults.set(system.rawValue, forKey: "current_accounting_system")
            
            // Update status immediately after successful connection
            if isConnected {
                connectionStatus = "Connected to \(system.displayName)"
                if DebugLogConfig.shared.logConnectionStatus {
                    print("✅ SystemManager - Connected to \(system.displayName)")
                }
            }
            
            updateConnectionStatus()
            if DebugLogConfig.shared.logSystemManager {
                print("✅ SystemManager - Successfully connected to \(system.displayName)")
            }
            
        } catch {
            // Update status to show connection failure
            connectionStatus = "Failed to connect to \(system.displayName)"
            isConnected = false
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - Failed to connect to \(system.displayName): \(error)")
            }
            throw error
        }
    }
    
    func disconnectFromCurrentSystem() async {
        if DebugLogConfig.shared.logSystemManager {
            print("🔌 SystemManager - Disconnecting from: \(currentSystem.displayName)")
        }
        
        // Store the current system before disconnecting for potential recovery
        let previousSystem = currentSystem
        userDefaults.set(previousSystem.rawValue, forKey: "previous_accounting_system")
        
        switch currentSystem {
        case .netsuite:
            if DebugLogConfig.shared.logSystemManager {
                print("🔌 SystemManager - Clearing NetSuite OAuth tokens")
            }
            oAuthManager.clearTokens()
        case .quickbooks:
            if DebugLogConfig.shared.logSystemManager {
                print("🔌 SystemManager - Clearing QuickBooks OAuth tokens")
            }
            quickBooksOAuthManager.clearTokens()
        case .salesforce:
            if DebugLogConfig.shared.logSystemManager {
                print("🔌 SystemManager - Clearing Salesforce OAuth tokens")
            }
            salesforceOAuthManager.clearTokens()
        case .none:
            if DebugLogConfig.shared.logSystemManager {
                print("ℹ️ SystemManager - No system to disconnect from")
            }
            break
        }
        
        currentSystem = .none
        userDefaults.set(AccountingSystem.none.rawValue, forKey: "current_accounting_system")
        updateConnectionStatus()
        if DebugLogConfig.shared.logSystemManager {
            print("✅ SystemManager - Successfully disconnected from system")
        }
    }
    
    // MARK: - State Recovery & Validation
    func validateAndRecoverSystemState() async {
        if DebugLogConfig.shared.logSystemManager {
            print("🔄 SystemManager - Validating and recovering system state...")
        }
        
        // Check if we have a stored system and if it's still valid
        let storedSystem = userDefaults.string(forKey: "current_accounting_system") ?? "none"
        let system = AccountingSystem(rawValue: storedSystem) ?? .none
        
        if system != .none {
            if DebugLogConfig.shared.logSystemManager {
                print("🔍 SystemManager - Found stored system: \(system.displayName)")
            }
            
            // Check if the system is still authenticated
            let canConnect = canConnectToSystem(system)
            if canConnect {
                if DebugLogConfig.shared.logSystemManager {
                    print("✅ SystemManager - Stored system is still valid, attempting to reconnect")
                }
                do {
                    try await connectToSystem(system)
                } catch {
                    if DebugLogConfig.shared.logErrorDetails {
                        print("❌ SystemManager - Failed to reconnect to stored system: \(error)")
                    }
                    // Fall back to standalone mode
                    await disconnectFromCurrentSystem()
                }
            } else {
                if DebugLogConfig.shared.logSystemManager {
                    print("⚠️ SystemManager - Stored system is no longer valid, switching to standalone mode")
                }
                await disconnectFromCurrentSystem()
            }
        } else if DebugLogConfig.shared.logSystemManager {
            print("ℹ️ SystemManager - No stored system found, staying in standalone mode")
        }
    }
    
    private func connectToNetSuite() async throws {
        if DebugLogConfig.shared.logSystemManager {
            print("🔗 SystemManager - Connecting to NetSuite...")
        }
        
        guard oAuthManager.isAuthenticated else {
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - NetSuite not authenticated")
            }
            throw SystemManagerError.notAuthenticated
        }
        
        // Validate token and refresh if needed
        do {
            let _ = try await oAuthManager.getValidAccessToken()
            if DebugLogConfig.shared.logTokenValidation {
                print("✅ SystemManager - NetSuite token validated successfully")
            }
        } catch {
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - NetSuite token validation failed: \(error)")
            }
            throw SystemManagerError.tokenValidationFailed
        }
        
        if DebugLogConfig.shared.logSystemManager {
            print("✅ SystemManager - NetSuite authentication confirmed")
        }
        isConnected = true
    }
    
    private func connectToQuickBooks() async throws {
        if DebugLogConfig.shared.logSystemManager {
            print("🔗 SystemManager - Connecting to QuickBooks...")
        }
        
        guard quickBooksOAuthManager.isAuthenticated else {
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - QuickBooks not authenticated")
            }
            throw SystemManagerError.notAuthenticated
        }
        
        // Validate token and refresh if needed
        do {
            let _ = try await quickBooksOAuthManager.getValidAccessToken()
            if DebugLogConfig.shared.logTokenValidation {
                print("✅ SystemManager - QuickBooks token validated successfully")
            }
        } catch {
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - QuickBooks token validation failed: \(error)")
            }
            throw SystemManagerError.tokenValidationFailed
        }
        
        isConnected = true
    }
    
    private func connectToSalesforce() async throws {
        if DebugLogConfig.shared.logSystemManager {
            print("🔗 SystemManager - Connecting to Salesforce...")
        }
        
        guard salesforceOAuthManager.isAuthenticated else {
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - Salesforce not authenticated")
            }
            throw SystemManagerError.notAuthenticated
        }
        
        // Validate token and refresh if needed
        do {
            let _ = try await salesforceOAuthManager.getValidAccessToken()
            if DebugLogConfig.shared.logTokenValidation {
                print("✅ SystemManager - Salesforce token validated successfully")
            }
        } catch {
            if DebugLogConfig.shared.logErrorDetails {
                print("❌ SystemManager - Salesforce token validation failed: \(error)")
            }
            throw SystemManagerError.tokenValidationFailed
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
        if DebugLogConfig.shared.logConnectionStatus {
            print("🔄 SystemManager - Updating connection status for: \(currentSystem.displayName)")
        }
        
        switch currentSystem {
        case .none:
            connectionStatus = "Standalone Mode"
            isConnected = false
            if DebugLogConfig.shared.logConnectionStatus {
                print("ℹ️ SystemManager - Set to standalone mode")
            }
        case .netsuite:
            let isAuth = oAuthManager.isAuthenticated
            if isAuth && isConnected {
                // If we're already connected, show connected status immediately
                connectionStatus = "Connected to NetSuite"
                if DebugLogConfig.shared.logConnectionStatus {
                    print("✅ SystemManager - NetSuite: Connected")
                }
            } else if isAuth {
                // If authenticated but not yet connected, validate token
                Task {
                    do {
                        let _ = try await oAuthManager.getValidAccessToken()
                        await MainActor.run {
                            connectionStatus = "Connected to NetSuite"
                            isConnected = true
                            if DebugLogConfig.shared.logConnectionStatus {
                                print("✅ SystemManager - NetSuite: Status updated to Connected")
                            }
                        }
                    } catch {
                        await MainActor.run {
                            connectionStatus = "NetSuite Token Expired"
                            isConnected = false
                            if DebugLogConfig.shared.logErrorDetails {
                                print("❌ SystemManager - NetSuite token expired: \(error)")
                            }
                        }
                    }
                }
            } else {
                connectionStatus = "NetSuite Not Authenticated"
                isConnected = false
                if DebugLogConfig.shared.logConnectionStatus {
                    print("⚠️ SystemManager - NetSuite: Not Authenticated")
                }
            }
        case .quickbooks:
            let isAuth = quickBooksOAuthManager.isAuthenticated
            if isAuth && isConnected {
                // If we're already connected, show connected status immediately
                connectionStatus = "Connected to QuickBooks"
                if DebugLogConfig.shared.logConnectionStatus {
                    print("✅ SystemManager - QuickBooks: Connected")
                }
            } else if isAuth {
                // If authenticated but not yet connected, validate token
                Task {
                    do {
                        let _ = try await quickBooksOAuthManager.getValidAccessToken()
                        await MainActor.run {
                            connectionStatus = "Connected to QuickBooks"
                            isConnected = true
                            if DebugLogConfig.shared.logConnectionStatus {
                                print("✅ SystemManager - QuickBooks: Status updated to Connected")
                            }
                        }
                    } catch {
                        await MainActor.run {
                            connectionStatus = "QuickBooks Token Expired"
                            isConnected = false
                            if DebugLogConfig.shared.logErrorDetails {
                                print("❌ SystemManager - QuickBooks token expired: \(error)")
                            }
                        }
                    }
                }
            } else {
                connectionStatus = "QuickBooks Not Authenticated"
                isConnected = false
                if DebugLogConfig.shared.logConnectionStatus {
                    print("⚠️ SystemManager - QuickBooks: Not Authenticated")
                }
            }
        case .salesforce:
            let isAuth = salesforceOAuthManager.isAuthenticated
            if isAuth && isConnected {
                // If we're already connected, show connected status immediately
                connectionStatus = "Connected to Salesforce"
                if DebugLogConfig.shared.logConnectionStatus {
                    print("✅ SystemManager - Salesforce: Connected")
                }
            } else if isAuth {
                // If authenticated but not yet connected, validate token
                Task {
                    do {
                        let _ = try await salesforceOAuthManager.getValidAccessToken()
                        await MainActor.run {
                            connectionStatus = "Connected to Salesforce"
                            isConnected = true
                            if DebugLogConfig.shared.logConnectionStatus {
                                print("✅ SystemManager - Salesforce: Status updated to Connected")
                            }
                        }
                    } catch {
                        await MainActor.run {
                            connectionStatus = "Salesforce Token Expired"
                            isConnected = false
                            if DebugLogConfig.shared.logErrorDetails {
                                print("❌ SystemManager - Salesforce token expired: \(error)")
                            }
                        }
                    }
                }
            } else {
                connectionStatus = "Salesforce Not Authenticated"
                isConnected = false
                if DebugLogConfig.shared.logConnectionStatus {
                    print("⚠️ SystemManager - Salesforce: Not Authenticated")
                }
            }
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
        case .quickbooks:
            return quickBooksOAuthManager.isAuthenticated
        case .salesforce:
            return salesforceOAuthManager.isAuthenticated
        case .none:
            return true
        }
    }
    
    // MARK: - Token Health & Validation
    func checkTokenHealth() async -> TokenHealthStatus {
        if DebugLogConfig.shared.logTokenValidation {
            print("🔍 SystemManager - Checking token health for: \(currentSystem.displayName)")
        }
        
        switch currentSystem {
        case .none:
            return .noSystem
        case .netsuite:
            return await checkNetSuiteTokenHealth()
        case .quickbooks:
            return await checkQuickBooksTokenHealth()
        case .salesforce:
            return await checkSalesforceTokenHealth()
        }
    }
    
    private func checkNetSuiteTokenHealth() async -> TokenHealthStatus {
        guard oAuthManager.isAuthenticated else {
            return .notAuthenticated
        }
        
        do {
            let _ = try await oAuthManager.getValidAccessToken()
            return .healthy
        } catch {
            return .expired
        }
    }
    
    private func checkQuickBooksTokenHealth() async -> TokenHealthStatus {
        guard quickBooksOAuthManager.isAuthenticated else {
            return .notAuthenticated
        }
        
        do {
            let _ = try await quickBooksOAuthManager.getValidAccessToken()
            return .healthy
        } catch {
            return .expired
        }
    }
    
    private func checkSalesforceTokenHealth() async -> TokenHealthStatus {
        guard salesforceOAuthManager.isAuthenticated else {
            return .notAuthenticated
        }
        
        do {
            let _ = try await salesforceOAuthManager.getValidAccessToken()
            return .healthy
        } catch {
            return .expired
        }
    }
    
    func refreshCurrentSystemToken() async throws {
        if DebugLogConfig.shared.logTokenValidation {
            print("🔄 SystemManager - Refreshing token for: \(currentSystem.displayName)")
        }
        
        switch currentSystem {
        case .none:
            throw SystemManagerError.noSystemConnected
        case .netsuite:
            let _ = try await oAuthManager.getValidAccessToken()
        case .quickbooks:
            let _ = try await quickBooksOAuthManager.getValidAccessToken()
        case .salesforce:
            let _ = try await salesforceOAuthManager.getValidAccessToken()
        }
        
        if DebugLogConfig.shared.logTokenValidation {
            print("✅ SystemManager - Token refresh successful for \(currentSystem.displayName)")
        }
    }
    
    // MARK: - API Access
    func getCurrentOAuthManager() -> (any ObservableObject)? {
        switch currentSystem {
        case .netsuite:
            return oAuthManager
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
    case tokenValidationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "System not authenticated. Please complete OAuth setup first."
        case .noSystemConnected:
            return "No accounting system connected. Running in standalone mode."
        case .systemNotSupported:
            return "This accounting system is not supported."
        case .tokenValidationFailed:
            return "Token validation failed. Please re-authenticate the system."
        }
    }
} 