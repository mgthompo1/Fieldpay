import Foundation
import Security

class KeychainWrapper {
    static let shared = KeychainWrapper()
    
    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        return (result as? Data)
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - String Operations
    
    func saveString(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("Debug: KeychainWrapper - Failed to convert string to data for key: \(key)")
            return false
        }
        return save(key: key, data: data)
    }
    
    func loadString(key: String) -> String? {
        guard let data = load(key: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Date Operations
    
    func saveDate(key: String, value: Date) -> Bool {
        let timeInterval = value.timeIntervalSince1970
        let data = withUnsafeBytes(of: timeInterval) { Data($0) }
        return save(key: key, data: data)
    }
    
    func loadDate(key: String) -> Date? {
        guard let data = load(key: key) else {
            return nil
        }
        
        let timeInterval = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    // MARK: - NetSuite Specific Keys
    
    enum NetSuiteKeys {
        static let accessToken = "netsuite_access_token"
        static let refreshToken = "netsuite_refresh_token"
        static let tokenExpiry = "netsuite_token_expiry"
        static let accountId = "netsuite_account_id"
        static let clientId = "netsuite_client_id"
        static let clientSecret = "netsuite_client_secret"
        static let redirectUri = "netsuite_redirect_uri"
    }
    
    // MARK: - NetSuite Token Operations
    
    func saveNetSuiteTokens(accessToken: String, refreshToken: String, expiryDate: Date) -> Bool {
        print("Debug: KeychainWrapper - Saving NetSuite tokens to Keychain")
        
        let accessTokenSaved = saveString(key: NetSuiteKeys.accessToken, value: accessToken)
        let refreshTokenSaved = saveString(key: NetSuiteKeys.refreshToken, value: refreshToken)
        let expiryDateSaved = saveDate(key: NetSuiteKeys.tokenExpiry, value: expiryDate)
        
        print("Debug: KeychainWrapper - Token storage results:")
        print("Debug: - Access token saved: \(accessTokenSaved)")
        print("Debug: - Refresh token saved: \(refreshTokenSaved)")
        print("Debug: - Expiry date saved: \(expiryDateSaved)")
        
        return accessTokenSaved && refreshTokenSaved && expiryDateSaved
    }
    
    func loadNetSuiteTokens() -> (accessToken: String?, refreshToken: String?, expiryDate: Date?) {
        print("Debug: KeychainWrapper - Loading NetSuite tokens from Keychain")
        
        let accessToken = loadString(key: NetSuiteKeys.accessToken)
        let refreshToken = loadString(key: NetSuiteKeys.refreshToken)
        let expiryDate = loadDate(key: NetSuiteKeys.tokenExpiry)
        
        print("Debug: KeychainWrapper - Token loading results:")
        print("Debug: - Access token loaded: \(accessToken != nil)")
        print("Debug: - Refresh token loaded: \(refreshToken != nil)")
        print("Debug: - Expiry date loaded: \(expiryDate != nil)")
        
        return (accessToken: accessToken, refreshToken: refreshToken, expiryDate: expiryDate)
    }
    
    func clearNetSuiteTokens() -> Bool {
        print("Debug: KeychainWrapper - Clearing NetSuite tokens from Keychain")
        
        let accessTokenDeleted = delete(key: NetSuiteKeys.accessToken)
        let refreshTokenDeleted = delete(key: NetSuiteKeys.refreshToken)
        let expiryDateDeleted = delete(key: NetSuiteKeys.tokenExpiry)
        
        print("Debug: KeychainWrapper - Token deletion results:")
        print("Debug: - Access token deleted: \(accessTokenDeleted)")
        print("Debug: - Refresh token deleted: \(refreshTokenDeleted)")
        print("Debug: - Expiry date deleted: \(expiryDateDeleted)")
        
        return accessTokenDeleted && refreshTokenDeleted && expiryDateDeleted
    }
    
    func saveNetSuiteConfiguration(accountId: String, clientId: String, clientSecret: String, redirectUri: String) -> Bool {
        print("Debug: KeychainWrapper - Saving NetSuite configuration to Keychain")
        
        let accountIdSaved = saveString(key: NetSuiteKeys.accountId, value: accountId)
        let clientIdSaved = saveString(key: NetSuiteKeys.clientId, value: clientId)
        let clientSecretSaved = saveString(key: NetSuiteKeys.clientSecret, value: clientSecret)
        let redirectUriSaved = saveString(key: NetSuiteKeys.redirectUri, value: redirectUri)
        
        print("Debug: KeychainWrapper - Configuration storage results:")
        print("Debug: - Account ID saved: \(accountIdSaved)")
        print("Debug: - Client ID saved: \(clientIdSaved)")
        print("Debug: - Client Secret saved: \(clientSecretSaved)")
        print("Debug: - Redirect URI saved: \(redirectUriSaved)")
        
        return accountIdSaved && clientIdSaved && clientSecretSaved && redirectUriSaved
    }
    
    func loadNetSuiteConfiguration() -> (accountId: String?, clientId: String?, clientSecret: String?, redirectUri: String?) {
        print("Debug: KeychainWrapper - Loading NetSuite configuration from Keychain")
        
        let accountId = loadString(key: NetSuiteKeys.accountId)
        let clientId = loadString(key: NetSuiteKeys.clientId)
        let clientSecret = loadString(key: NetSuiteKeys.clientSecret)
        let redirectUri = loadString(key: NetSuiteKeys.redirectUri)
        
        print("Debug: KeychainWrapper - Configuration loading results:")
        print("Debug: - Account ID loaded: \(accountId != nil)")
        print("Debug: - Client ID loaded: \(clientId != nil)")
        print("Debug: - Client Secret loaded: \(clientSecret != nil)")
        print("Debug: - Redirect URI loaded: \(redirectUri != nil)")
        
        return (accountId: accountId, clientId: clientId, clientSecret: clientSecret, redirectUri: redirectUri)
    }
    
    func clearNetSuiteConfiguration() -> Bool {
        print("Debug: KeychainWrapper - Clearing NetSuite configuration from Keychain")
        
        let accountIdDeleted = delete(key: NetSuiteKeys.accountId)
        let clientIdDeleted = delete(key: NetSuiteKeys.clientId)
        let clientSecretDeleted = delete(key: NetSuiteKeys.clientSecret)
        let redirectUriDeleted = delete(key: NetSuiteKeys.redirectUri)
        
        print("Debug: KeychainWrapper - Configuration deletion results:")
        print("Debug: - Account ID deleted: \(accountIdDeleted)")
        print("Debug: - Client ID deleted: \(clientIdDeleted)")
        print("Debug: - Client Secret deleted: \(clientSecretDeleted)")
        print("Debug: - Redirect URI deleted: \(redirectUriDeleted)")
        
        return accountIdDeleted && clientIdDeleted && clientSecretDeleted && redirectUriDeleted
    }
} 