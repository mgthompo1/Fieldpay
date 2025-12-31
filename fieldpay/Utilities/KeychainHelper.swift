import Foundation
import Security

/// A secure helper for storing sensitive credentials in the iOS Keychain
/// instead of UserDefaults which is not encrypted
final class KeychainHelper {
    static let shared = KeychainHelper()

    private init() {}

    // MARK: - Service identifiers for different credential types
    enum Service: String {
        case stripe = "com.fieldpay.stripe"
        case windcave = "com.fieldpay.windcave"
        case netsuite = "com.fieldpay.netsuite"
    }

    enum KeychainError: Error, LocalizedError {
        case duplicateEntry
        case unknown(OSStatus)
        case itemNotFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .duplicateEntry:
                return "This item already exists in the keychain"
            case .unknown(let status):
                return "Keychain error: \(status)"
            case .itemNotFound:
                return "Item not found in keychain"
            case .invalidData:
                return "Invalid data format"
            }
        }
    }

    // MARK: - Save

    /// Save a string value to the keychain
    func save(_ value: String, service: Service, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, service: service, account: account)
    }

    /// Save data to the keychain
    func save(_ data: Data, service: Service, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)

        // Then add the new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Read

    /// Read a string value from the keychain
    func read(service: Service, account: String) -> String? {
        guard let data = readData(service: service, account: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Read data from the keychain
    func readData(service: Service, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    // MARK: - Delete

    /// Delete an item from the keychain
    func delete(service: Service, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    /// Delete all items for a service
    func deleteAll(service: Service) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Migration Helper

    /// Migrate a value from UserDefaults to Keychain (one-time migration)
    func migrateFromUserDefaults(userDefaultsKey: String, service: Service, account: String) {
        // Check if already migrated
        if read(service: service, account: account) != nil {
            return
        }

        // Get value from UserDefaults
        guard let value = UserDefaults.standard.string(forKey: userDefaultsKey), !value.isEmpty else {
            return
        }

        // Save to Keychain
        do {
            try save(value, service: service, account: account)
            // Remove from UserDefaults after successful migration
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            print("Successfully migrated \(userDefaultsKey) to Keychain")
        } catch {
            print("Failed to migrate \(userDefaultsKey) to Keychain: \(error)")
        }
    }
}

// MARK: - Convenience Extensions for Stripe

extension KeychainHelper {
    struct StripeKeys {
        static let publicKey = "public_key"
        static let secretKey = "secret_key"
        static let accountId = "account_id"
    }

    var stripePublicKey: String? {
        get { read(service: .stripe, account: StripeKeys.publicKey) }
        set {
            if let value = newValue {
                try? save(value, service: .stripe, account: StripeKeys.publicKey)
            } else {
                try? delete(service: .stripe, account: StripeKeys.publicKey)
            }
        }
    }

    var stripeSecretKey: String? {
        get { read(service: .stripe, account: StripeKeys.secretKey) }
        set {
            if let value = newValue {
                try? save(value, service: .stripe, account: StripeKeys.secretKey)
            } else {
                try? delete(service: .stripe, account: StripeKeys.secretKey)
            }
        }
    }

    var stripeAccountId: String? {
        get { read(service: .stripe, account: StripeKeys.accountId) }
        set {
            if let value = newValue {
                try? save(value, service: .stripe, account: StripeKeys.accountId)
            } else {
                try? delete(service: .stripe, account: StripeKeys.accountId)
            }
        }
    }

    func migrateStripeCredentials() {
        migrateFromUserDefaults(userDefaultsKey: "stripe_public_key", service: .stripe, account: StripeKeys.publicKey)
        migrateFromUserDefaults(userDefaultsKey: "stripe_secret_key", service: .stripe, account: StripeKeys.secretKey)
        migrateFromUserDefaults(userDefaultsKey: "stripe_account_id", service: .stripe, account: StripeKeys.accountId)
    }
}

// MARK: - Convenience Extensions for Windcave

extension KeychainHelper {
    struct WindcaveKeys {
        static let username = "username"
        static let apiKey = "api_key"
    }

    var windcaveUsername: String? {
        get { read(service: .windcave, account: WindcaveKeys.username) }
        set {
            if let value = newValue {
                try? save(value, service: .windcave, account: WindcaveKeys.username)
            } else {
                try? delete(service: .windcave, account: WindcaveKeys.username)
            }
        }
    }

    var windcaveApiKey: String? {
        get { read(service: .windcave, account: WindcaveKeys.apiKey) }
        set {
            if let value = newValue {
                try? save(value, service: .windcave, account: WindcaveKeys.apiKey)
            } else {
                try? delete(service: .windcave, account: WindcaveKeys.apiKey)
            }
        }
    }

    func migrateWindcaveCredentials() {
        migrateFromUserDefaults(userDefaultsKey: "windcave_username", service: .windcave, account: WindcaveKeys.username)
        migrateFromUserDefaults(userDefaultsKey: "windcave_api_key", service: .windcave, account: WindcaveKeys.apiKey)
    }
}

// MARK: - Convenience Extensions for NetSuite OAuth

extension KeychainHelper {
    struct NetSuiteKeys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let tokenExpiry = "token_expiry"
        static let consumerKey = "consumer_key"
        static let consumerSecret = "consumer_secret"
    }

    var netSuiteAccessToken: String? {
        get { read(service: .netsuite, account: NetSuiteKeys.accessToken) }
        set {
            if let value = newValue {
                try? save(value, service: .netsuite, account: NetSuiteKeys.accessToken)
            } else {
                try? delete(service: .netsuite, account: NetSuiteKeys.accessToken)
            }
        }
    }

    var netSuiteRefreshToken: String? {
        get { read(service: .netsuite, account: NetSuiteKeys.refreshToken) }
        set {
            if let value = newValue {
                try? save(value, service: .netsuite, account: NetSuiteKeys.refreshToken)
            } else {
                try? delete(service: .netsuite, account: NetSuiteKeys.refreshToken)
            }
        }
    }

    func clearNetSuiteTokens() {
        try? delete(service: .netsuite, account: NetSuiteKeys.accessToken)
        try? delete(service: .netsuite, account: NetSuiteKeys.refreshToken)
        try? delete(service: .netsuite, account: NetSuiteKeys.tokenExpiry)
    }
}
