import Foundation
import Combine
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var stripePublicKey = ""
    @Published var stripeSecretKey = ""
    @Published var stripeAccountId = ""
    
    @Published var netSuiteClientId = ""
    @Published var netSuiteClientSecret = ""
    @Published var netSuiteAccountId = ""
    @Published var netSuiteRedirectUri = "fieldpay://callback"
    
    @Published var isStripeConnected = false
    @Published var isNetSuiteConnected = false
    @Published var netSuiteAccessToken: String?
    @Published var tokenExpiryDate: String?
    
    // Windcave Settings
    @Published var windcaveUsername = ""
    @Published var windcaveApiKey = ""
    @Published var isWindcaveConnected = false
    
    // Company Branding
    @Published var companyLogoData: Data?
    @Published var companyName = ""
    

    
    // QuickBooks Settings
    @Published var quickBooksClientId = ""
    @Published var quickBooksClientSecret = ""
    @Published var quickBooksEnvironment = "sandbox"
    @Published var isQuickBooksAuthenticated = false
    
    // Salesforce Settings
    @Published var salesforceClientId = ""
    @Published var salesforceClientSecret = ""
    @Published var salesforceIsSandbox = false
    @Published var isSalesforceAuthenticated = false
    
    // System Management
    @Published var selectedSystem: AccountingSystem = .none
    @Published var isSystemConnected = false
    @Published var systemConnectionStatus = "Not Connected"
    
    // Payment System Selection
    @Published var selectedPaymentSystem: PaymentSystem = .none
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let oAuthManager = OAuthManager.shared

    private let quickBooksOAuthManager = QuickBooksOAuthManager.shared
    private let salesforceOAuthManager = SalesforceOAuthManager.shared
    private let systemManager = SystemManager.shared
    private let windcaveManager = WindcaveManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSettings()
        checkConnectionStatus()
        loadPaymentSystemSelection()
    }
    
    // MARK: - Payment System Management
    
    enum PaymentSystem: String, CaseIterable {
        case none = "none"
        case stripe = "stripe"
        case windcave = "windcave"
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .stripe: return "Stripe"
            case .windcave: return "Windcave"
            }
        }
        
        var description: String {
            switch self {
            case .none: return "No payment system configured"
            case .stripe: return "QR Code/Online payment processing"
            case .windcave: return "Tap to Pay/Online Payments"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "xmark.circle"
            case .stripe: return "creditcard.fill"
            case .windcave: return "wave.3.right"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .gray
            case .stripe: return .blue
            case .windcave: return .purple
            }
        }
    }
    
    func loadPaymentSystemSelection() {
        if let savedSystem = userDefaults.string(forKey: "selected_payment_system"),
           let system = PaymentSystem(rawValue: savedSystem) {
            selectedPaymentSystem = system
        } else {
            selectedPaymentSystem = .none
        }
    }
    
    func savePaymentSystemSelection(_ system: PaymentSystem) {
        selectedPaymentSystem = system
        userDefaults.set(system.rawValue, forKey: "selected_payment_system")
    }
    
    // MARK: - Stripe Settings
    
    func saveStripeSettings() {
        userDefaults.set(stripePublicKey, forKey: "stripe_public_key")
        userDefaults.set(stripeSecretKey, forKey: "stripe_secret_key")
        userDefaults.set(stripeAccountId, forKey: "stripe_account_id")
        
        // Update StripeManager with new keys
        StripeManager.shared.updateConfiguration(
            publicKey: stripePublicKey,
            secretKey: stripeSecretKey,
            accountId: stripeAccountId
        )
        
        checkStripeConnection()
    }
    
    func testStripeConnection() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let isValid = try await StripeManager.shared.testConnection()
                await MainActor.run {
                    self.isStripeConnected = isValid
                    self.isLoading = false
                    if isValid {
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Invalid Stripe credentials"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isStripeConnected = false
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func checkStripeConnection() {
        Task {
            do {
                let isValid = try await StripeManager.shared.testConnection()
                await MainActor.run {
                    self.isStripeConnected = isValid
                }
            } catch {
                await MainActor.run {
                    self.isStripeConnected = false
                }
            }
        }
    }
    
    // MARK: - NetSuite Settings
    
    func saveNetSuiteSettings() {
        print("Debug: Saving NetSuite settings...")
        print("Debug: Client ID to save: '\(netSuiteClientId)'")
        print("Debug: Client Secret to save: '\(netSuiteClientSecret)'")
        print("Debug: Account ID to save: '\(netSuiteAccountId)'")
        print("Debug: Redirect URI to save: '\(netSuiteRedirectUri)'")
        
        userDefaults.set(netSuiteClientId, forKey: "netsuite_client_id")
        userDefaults.set(netSuiteClientSecret, forKey: "netsuite_client_secret")
        userDefaults.set(netSuiteAccountId, forKey: "netsuite_account_id")
        userDefaults.set(netSuiteRedirectUri, forKey: "netsuite_redirect_uri")
        
        // Force UserDefaults to save immediately
        userDefaults.synchronize()
        
        print("Debug: Settings saved to UserDefaults")
        
        // Update OAuthManager with new configuration
        oAuthManager.updateConfiguration(
            clientId: netSuiteClientId,
            clientSecret: netSuiteClientSecret,
            accountId: netSuiteAccountId,
            redirectUri: netSuiteRedirectUri
        )
        
        print("Debug: OAuthManager configuration updated")
    }
    
    func connectToNetSuite() {
        print("Debug: ===== CONNECT TO NETSUITE CALLED =====")
        
        // Check if already authenticated
        if oAuthManager.isAuthenticated {
            print("Debug: Already authenticated with NetSuite, skipping OAuth flow")
            checkNetSuiteConnection()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Validate required fields
        guard !netSuiteClientId.isEmpty && !netSuiteClientSecret.isEmpty && !netSuiteAccountId.isEmpty else {
            print("Debug: Missing required NetSuite credentials")
            print("Debug: Client ID empty: \(netSuiteClientId.isEmpty)")
            print("Debug: Client Secret empty: \(netSuiteClientSecret.isEmpty)")
            print("Debug: Account ID empty: \(netSuiteAccountId.isEmpty)")
            
            isLoading = false
            errorMessage = "Please enter NetSuite Client ID, Client Secret, and Account ID first"
            return
        }
        
        // First save the settings to make sure OAuthManager is configured
        saveNetSuiteSettings()
        
        Task {
            do {
                print("Debug: About to call oAuthManager.startOAuthFlow()")
                let authURL = try await oAuthManager.startOAuthFlow()
                
                print("Debug: Generated auth URL: \(authURL)")
                
                await MainActor.run {
                    self.isLoading = false
                    // Open Safari with the OAuth authorization URL
                    if let url = URL(string: authURL) {
                        print("Debug: Opening URL in Safari: \(url)")
                        print("Debug: URL absolute string: \(url.absoluteString)")
                        print("Debug: URL scheme: \(url.scheme ?? "nil")")
                        print("Debug: URL host: \(url.host ?? "nil")")
                        print("Debug: URL path: \(url.path)")
                        print("Debug: URL query: \(url.query ?? "nil")")
                        
                        UIApplication.shared.open(url) { success in
                            print("Debug: Safari open result: \(success)")
                            if !success {
                                self.errorMessage = "Failed to open Safari. Please try again."
                            }
                        }
                    } else {
                        print("Debug: Failed to create URL from string: \(authURL)")
                        self.errorMessage = "Invalid OAuth URL generated"
                    }
                }
                
            } catch {
                print("Debug: OAuth error: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func disconnectNetSuite() {
        userDefaults.removeObject(forKey: "netsuite_access_token")
        userDefaults.removeObject(forKey: "netsuite_refresh_token")
        userDefaults.removeObject(forKey: "netsuite_token_expiry")
        
        netSuiteAccessToken = nil
        tokenExpiryDate = nil
        isNetSuiteConnected = false
        
        oAuthManager.clearTokens()
    }
    
    func reconnectNetSuite() {
        print("Debug: ===== reconnectNetSuite() called =====")
        
        // Clear current connection status
        isNetSuiteConnected = false
        netSuiteAccessToken = nil
        tokenExpiryDate = nil
        
        // Clear stored tokens to force fresh OAuth flow
        userDefaults.removeObject(forKey: "netsuite_access_token")
        userDefaults.removeObject(forKey: "netsuite_refresh_token")
        userDefaults.removeObject(forKey: "netsuite_token_expiry")
        
        // Clear OAuthManager tokens
        oAuthManager.clearTokens()
        
        print("Debug: Cleared all NetSuite tokens and connection status")
        print("Debug: Starting fresh OAuth flow...")
        
        // Start fresh OAuth flow
        connectToNetSuite()
    }
    
    func handleOAuthCallback() {
        // This method will be called when OAuth callback is successful
        print("Debug: SettingsViewModel - OAuth callback handled, checking NetSuite connection...")
        Task {
            // Wait a moment for OAuthManager to process the callback
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                self.checkNetSuiteConnection()
            }
        }
    }
    

    
    private func checkNetSuiteConnection() {
        print("Debug: ===== checkNetSuiteConnection() called =====")
        
        // Check if we have valid OAuth tokens from OAuthManager
        if oAuthManager.isAuthenticated, let accessToken = oAuthManager.accessToken {
            print("Debug: OAuthManager is authenticated with access token")
            netSuiteAccessToken = accessToken
            isNetSuiteConnected = true
            
            // Update NetSuiteAPI with current tokens
            if let refreshToken = oAuthManager.refreshToken {
                let expiryDate = Date().addingTimeInterval(3600) // Default 1 hour expiry
                NetSuiteAPI.shared.updateTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    expiryDate: expiryDate
                )
                tokenExpiryDate = formatDate(expiryDate)
                print("Debug: NetSuiteAPI updated with OAuthManager tokens")
            }
        } else {
            print("Debug: OAuthManager not authenticated, checking stored tokens")
            // Check stored tokens as fallback
            if let accessToken = userDefaults.string(forKey: "netsuite_access_token"),
               let expiryDate = userDefaults.object(forKey: "netsuite_token_expiry") as? Date {
                
                let isExpired = Date() > expiryDate
                print("Debug: Found stored access token, expired: \(isExpired)")
                
                if !isExpired {
                    netSuiteAccessToken = accessToken
                    tokenExpiryDate = formatDate(expiryDate)
                    isNetSuiteConnected = true
                    
                    // Update NetSuiteAPI with stored tokens
                    if let refreshToken = userDefaults.string(forKey: "netsuite_refresh_token") {
                        NetSuiteAPI.shared.updateTokens(
                            accessToken: accessToken,
                            refreshToken: refreshToken,
                            expiryDate: expiryDate
                        )
                        print("Debug: NetSuiteAPI updated with stored tokens")
                    }
                } else {
                    print("Debug: Stored token is expired, attempting refresh")
                    // Token expired, try to refresh
                    refreshNetSuiteToken()
                }
            } else {
                print("Debug: No stored access token found, setting isNetSuiteConnected = false")
                isNetSuiteConnected = false
                netSuiteAccessToken = nil
                tokenExpiryDate = nil
            }
        }
        
        print("Debug: Final connection status - isNetSuiteConnected: \(isNetSuiteConnected)")
        print("Debug: Final connection status - has access token: \(netSuiteAccessToken != nil)")
    }
    
    private func refreshNetSuiteToken() {
        guard let refreshToken = userDefaults.string(forKey: "netsuite_refresh_token") else {
            isNetSuiteConnected = false
            return
        }
        
        Task {
            do {
                let newTokens = try await oAuthManager.refreshAccessToken(refreshToken: refreshToken)
                
                await MainActor.run {
                    self.netSuiteAccessToken = newTokens.accessToken
                    self.tokenExpiryDate = self.formatDate(newTokens.expiryDate)
                    self.isNetSuiteConnected = true
                    
                    // Update stored tokens
                    self.userDefaults.set(newTokens.accessToken, forKey: "netsuite_access_token")
                    self.userDefaults.set(newTokens.refreshToken, forKey: "netsuite_refresh_token")
                    self.userDefaults.set(newTokens.expiryDate, forKey: "netsuite_token_expiry")
                    
                    // Update NetSuiteAPI
                    NetSuiteAPI.shared.updateTokens(
                        accessToken: newTokens.accessToken,
                        refreshToken: newTokens.refreshToken,
                        expiryDate: newTokens.expiryDate
                    )
                }
            } catch {
                await MainActor.run {
                    self.isNetSuiteConnected = false
                    self.netSuiteAccessToken = nil
                    self.tokenExpiryDate = nil
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        print("Debug: Starting loadSettings()")
        
        stripePublicKey = userDefaults.string(forKey: "stripe_public_key") ?? ""
        stripeSecretKey = userDefaults.string(forKey: "stripe_secret_key") ?? ""
        stripeAccountId = userDefaults.string(forKey: "stripe_account_id") ?? ""
        
        netSuiteClientId = userDefaults.string(forKey: "netsuite_client_id") ?? ""
        netSuiteClientSecret = userDefaults.string(forKey: "netsuite_client_secret") ?? ""
        netSuiteAccountId = userDefaults.string(forKey: "netsuite_account_id") ?? ""
        netSuiteRedirectUri = userDefaults.string(forKey: "netsuite_redirect_uri") ?? "fieldpay://callback"
        
        print("Debug: Loaded NetSuite credentials - ClientID: \(netSuiteClientId.prefix(10))..., AccountID: \(netSuiteAccountId)")
        
        windcaveUsername = userDefaults.string(forKey: "windcave_username") ?? ""
        windcaveApiKey = userDefaults.string(forKey: "windcave_api_key") ?? ""
        
        // Update WindcaveManager with loaded credentials
        if !windcaveUsername.isEmpty && !windcaveApiKey.isEmpty {
            print("Debug: Configuring WindcaveManager with loaded credentials")
            windcaveManager.updateConfiguration(username: windcaveUsername, apiKey: windcaveApiKey)
        }
        
        // Load company branding settings
        companyLogoData = userDefaults.data(forKey: "company_logo")
        companyName = userDefaults.string(forKey: "company_name") ?? ""
        

        
        // Load QuickBooks settings
        quickBooksClientId = userDefaults.string(forKey: "quickbooks_client_id") ?? ""
        quickBooksClientSecret = userDefaults.string(forKey: "quickbooks_client_secret") ?? ""
        quickBooksEnvironment = userDefaults.string(forKey: "quickbooks_environment") ?? "sandbox"
        
        // Load Salesforce settings
        salesforceClientId = userDefaults.string(forKey: "salesforce_client_id") ?? ""
        salesforceClientSecret = userDefaults.string(forKey: "salesforce_client_secret") ?? ""
        salesforceIsSandbox = userDefaults.bool(forKey: "salesforce_is_sandbox")
        
        // Load system management settings
        let systemString = userDefaults.string(forKey: "current_accounting_system") ?? "none"
        selectedSystem = AccountingSystem(rawValue: systemString) ?? .none
        
        // Update OAuthManager with loaded NetSuite credentials
        if !netSuiteClientId.isEmpty && !netSuiteClientSecret.isEmpty && !netSuiteAccountId.isEmpty {
            print("Debug: Configuring OAuthManager with NetSuite credentials")
            oAuthManager.updateConfiguration(
                clientId: netSuiteClientId,
                clientSecret: netSuiteClientSecret,
                accountId: netSuiteAccountId,
                redirectUri: netSuiteRedirectUri
            )
            print("Debug: OAuthManager configured with loaded NetSuite credentials")
            
            // Also configure NetSuiteAPI if we have stored tokens
            if let accessToken = userDefaults.string(forKey: "netsuite_access_token") {
                print("Debug: Configuring NetSuiteAPI with stored access token")
                NetSuiteAPI.shared.configure(accountId: netSuiteAccountId, accessToken: accessToken)
            }
        } else {
            print("Debug: NetSuite credentials are empty - ClientID: \(netSuiteClientId.isEmpty), Secret: \(netSuiteClientSecret.isEmpty), AccountID: \(netSuiteAccountId.isEmpty)")
        }
        
        print("Debug: loadSettings() completed")
        print("Debug: NetSuite Client ID: \(netSuiteClientId)")
        print("Debug: NetSuite Account ID: \(netSuiteAccountId)")
        print("Debug: NetSuite Client Secret: \(netSuiteClientSecret)")
    }
    
    private func checkConnectionStatus() {
        checkStripeConnection()
        checkNetSuiteConnection()
        checkWindcaveConnection()

        checkQuickBooksAuthentication()
        checkSalesforceAuthentication()
        
        // Update system connection status
        isSystemConnected = systemManager.isConnected
        systemConnectionStatus = systemManager.connectionStatus
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Windcave Settings
    
    func saveWindcaveSettings() {
        userDefaults.set(windcaveUsername, forKey: "windcave_username")
        userDefaults.set(windcaveApiKey, forKey: "windcave_api_key")
        
        // Update WindcaveManager with new credentials
        windcaveManager.updateConfiguration(username: windcaveUsername, apiKey: windcaveApiKey)
        
        // Update connection status immediately since we now have configuration
        if !windcaveUsername.isEmpty && !windcaveApiKey.isEmpty {
            print("Debug: Windcave credentials saved, updating connection status")
            isWindcaveConnected = windcaveManager.isConfigured
        }
        
        checkWindcaveConnection()
    }
    
    func testWindcaveConnection() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let isValid = try await windcaveManager.testConnection()
                await MainActor.run {
                    self.isWindcaveConnected = isValid
                    self.isLoading = false
                    if isValid {
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Invalid Windcave credentials"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isWindcaveConnected = false
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func checkWindcaveConnection() {
        // If not configured, don't show as connected
        guard windcaveManager.isConfigured else {
            isWindcaveConnected = false
            print("Debug: Windcave not configured, setting connection to false")
            return
        }
        
        Task {
            do {
                let isValid = try await windcaveManager.testConnection()
                await MainActor.run {
                    self.isWindcaveConnected = isValid
                    print("Debug: Windcave connection test result: \(isValid)")
                }
            } catch {
                await MainActor.run {
                    self.isWindcaveConnected = false
                    print("Debug: Windcave connection test failed: \(error)")
                }
            }
        }
    }
    

    
    // MARK: - QuickBooks Settings
    func saveQuickBooksSettings() {
        userDefaults.set(quickBooksClientId, forKey: "quickbooks_client_id")
        userDefaults.set(quickBooksClientSecret, forKey: "quickbooks_client_secret")
        userDefaults.set(quickBooksEnvironment, forKey: "quickbooks_environment")
        quickBooksOAuthManager.updateConfiguration(
            clientId: quickBooksClientId,
            clientSecret: quickBooksClientSecret,
            environment: quickBooksEnvironment
        )
        checkQuickBooksAuthentication()
    }
    
    func startQuickBooksOAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let authURL = try await quickBooksOAuthManager.startOAuthFlow()
                await MainActor.run {
                    self.isLoading = false
                    // Open Safari with auth URL
                    if let url = URL(string: authURL) {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func checkQuickBooksAuthentication() {
        isQuickBooksAuthenticated = quickBooksOAuthManager.isAuthenticated
    }
    
    // MARK: - Salesforce Settings
    func saveSalesforceSettings() {
        userDefaults.set(salesforceClientId, forKey: "salesforce_client_id")
        userDefaults.set(salesforceClientSecret, forKey: "salesforce_client_secret")
        userDefaults.set(salesforceIsSandbox, forKey: "salesforce_is_sandbox")
        salesforceOAuthManager.updateConfiguration(
            clientId: salesforceClientId,
            clientSecret: salesforceClientSecret,
            isSandbox: salesforceIsSandbox
        )
        checkSalesforceAuthentication()
    }
    
    func startSalesforceOAuth() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let authURL = try await salesforceOAuthManager.startOAuthFlow()
                await MainActor.run {
                    self.isLoading = false
                    // Open Safari with auth URL
                    if let url = URL(string: authURL) {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func checkSalesforceAuthentication() {
        isSalesforceAuthenticated = salesforceOAuthManager.isAuthenticated
    }
    
    // MARK: - System Management
    func connectToSystem(_ system: AccountingSystem) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await systemManager.connectToSystem(system)
                await MainActor.run {
                    self.selectedSystem = system
                    self.isSystemConnected = systemManager.isConnected
                    self.systemConnectionStatus = systemManager.connectionStatus
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func disconnectFromCurrentSystem() {
        Task {
            await systemManager.disconnectFromCurrentSystem()
            await MainActor.run {
                self.selectedSystem = .none
                self.isSystemConnected = false
                self.systemConnectionStatus = "Not Connected"
            }
        }
    }
    
    func canConnectToSystem(_ system: AccountingSystem) -> Bool {
        return systemManager.canConnectToSystem(system)
    }
    
    // MARK: - Company Branding Settings
    
    func saveCompanyBranding() {
        if let logoData = companyLogoData {
            userDefaults.set(logoData, forKey: "company_logo")
        } else {
            userDefaults.removeObject(forKey: "company_logo")
        }
        userDefaults.set(companyName, forKey: "company_name")
        print("Debug: Company branding saved - Name: \(companyName), Logo: \(companyLogoData != nil ? "Present" : "None")")
    }
    
    func clearCompanyLogo() {
        companyLogoData = nil
        userDefaults.removeObject(forKey: "company_logo")
        print("Debug: Company logo cleared")
    }
}

// MARK: - OAuth Token Response

struct OAuthTokenResponse {
    let accessToken: String
    let refreshToken: String
    let expiryDate: Date
} 