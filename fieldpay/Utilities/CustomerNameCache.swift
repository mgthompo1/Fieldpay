import Foundation

/// Global actor-based cache for customer names to prevent duplicate API calls
/// across ViewModels. Thread-safe and shared application-wide.
actor CustomerNameCache {
    static let shared = CustomerNameCache()

    // MARK: - Cache Storage
    private var cache: [String: CachedName] = [:]
    private var pendingRequests: [String: Task<String, Error>] = [:]

    // Cache TTL: 24 hours
    private let cacheTTL: TimeInterval = 86400

    // MARK: - Cache Entry
    private struct CachedName {
        let name: String
        let timestamp: Date

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > 86400
        }
    }

    private init() {}

    // MARK: - Public API

    /// Get a customer name, using cache if available
    /// - Parameters:
    ///   - customerId: The NetSuite customer ID
    ///   - fetcher: Async closure to fetch the name if not cached
    /// - Returns: The customer name
    func getName(
        for customerId: String,
        fetcher: @escaping () async throws -> String
    ) async throws -> String {
        // Check cache first
        if let cached = cache[customerId], !cached.isExpired {
            return cached.name
        }

        // Check if there's already a pending request for this customer
        if let pendingTask = pendingRequests[customerId] {
            return try await pendingTask.value
        }

        // Create a new fetch task
        let task = Task<String, Error> {
            let name = try await fetcher()
            return name
        }

        pendingRequests[customerId] = task

        do {
            let name = try await task.value
            // Cache the result
            cache[customerId] = CachedName(name: name, timestamp: Date())
            pendingRequests.removeValue(forKey: customerId)
            return name
        } catch {
            pendingRequests.removeValue(forKey: customerId)
            throw error
        }
    }

    /// Get multiple customer names in batch, using cache where available
    /// - Parameters:
    ///   - customerIds: Array of NetSuite customer IDs
    ///   - batchFetcher: Async closure to fetch names for uncached IDs
    /// - Returns: Dictionary mapping customer ID to name
    func getNames(
        for customerIds: [String],
        batchFetcher: @escaping ([String]) async throws -> [String: String]
    ) async throws -> [String: String] {
        var result: [String: String] = [:]
        var uncachedIds: [String] = []

        // Check cache for each ID
        for customerId in customerIds {
            if let cached = cache[customerId], !cached.isExpired {
                result[customerId] = cached.name
            } else {
                uncachedIds.append(customerId)
            }
        }

        // If all were cached, return immediately
        if uncachedIds.isEmpty {
            return result
        }

        // Fetch uncached names in batches of 100 (NetSuite IN clause limit)
        let batchSize = 100
        for batchStart in stride(from: 0, to: uncachedIds.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, uncachedIds.count)
            let batch = Array(uncachedIds[batchStart..<batchEnd])

            let fetched = try await batchFetcher(batch)

            // Cache and add to result
            for (customerId, name) in fetched {
                cache[customerId] = CachedName(name: name, timestamp: Date())
                result[customerId] = name
            }
        }

        // For any IDs that weren't returned, use fallback
        for customerId in uncachedIds {
            if result[customerId] == nil {
                let fallback = "Customer \(customerId)"
                result[customerId] = fallback
                cache[customerId] = CachedName(name: fallback, timestamp: Date())
            }
        }

        return result
    }

    /// Pre-populate cache with known customer names (e.g., from list fetch)
    func preload(_ names: [String: String]) {
        let now = Date()
        for (customerId, name) in names {
            // Only update if not already cached or expired
            if cache[customerId] == nil || cache[customerId]?.isExpired == true {
                cache[customerId] = CachedName(name: name, timestamp: now)
            }
        }
    }

    /// Clear expired entries from cache
    func pruneExpired() {
        cache = cache.filter { !$0.value.isExpired }
    }

    /// Clear all cached data
    func clearAll() {
        cache.removeAll()
        pendingRequests.removeAll()
    }

    /// Get cache statistics for debugging
    var stats: (count: Int, oldestAge: TimeInterval?) {
        let oldest = cache.values.min(by: { $0.timestamp < $1.timestamp })
        let age = oldest.map { Date().timeIntervalSince($0.timestamp) }
        return (cache.count, age)
    }
}

// MARK: - Convenience Extension for NetSuiteAPI

extension CustomerNameCache {
    /// Fetch customer name using NetSuiteAPI, with caching
    func getCustomerName(
        customerId: String,
        using api: NetSuiteAPI = .shared
    ) async -> String {
        guard !customerId.isEmpty else { return "Unknown Customer" }

        do {
            return try await getName(for: customerId) {
                // Use safe ID validation
                guard let safeId = SuiteQLHelper.escapeNumericId(customerId) else {
                    return "Customer \(customerId)"
                }

                let query = """
                    SELECT id, entityid, companyname, BUILTIN.DF(id) AS displayname
                    FROM customer
                    WHERE id = '\(safeId)'
                    LIMIT 1
                """

                let resource = NetSuiteResource.suiteQL(query: query)
                let response: SuiteQLResponse = try await api.fetch(resource, type: SuiteQLResponse.self)

                if let row = response.items.first {
                    // Priority: displayname > companyname > entityid
                    if let displayName = row.values["displayname"], !displayName.isEmpty {
                        return displayName
                    }
                    if let companyName = row.values["companyname"], !companyName.isEmpty {
                        return companyName
                    }
                    if let entityId = row.values["entityid"], !entityId.isEmpty {
                        return entityId
                    }
                }

                return "Customer \(customerId)"
            }
        } catch {
            print("CustomerNameCache: Failed to fetch name for \(customerId): \(error)")
            return "Customer \(customerId)"
        }
    }

    /// Fetch multiple customer names using NetSuiteAPI, with caching
    func getCustomerNames(
        customerIds: [String],
        using api: NetSuiteAPI = .shared
    ) async -> [String: String] {
        let uniqueIds = Array(Set(customerIds.filter { !$0.isEmpty }))
        guard !uniqueIds.isEmpty else { return [:] }

        do {
            return try await getNames(for: uniqueIds) { idsToFetch in
                guard let inClause = SuiteQLHelper.buildInClause(ids: idsToFetch) else {
                    return [:]
                }

                let query = """
                    SELECT id, entityid, companyname, BUILTIN.DF(id) AS displayname
                    FROM customer
                    WHERE id IN (\(inClause))
                """

                let resource = NetSuiteResource.suiteQL(query: query)
                let response: SuiteQLResponse = try await api.fetch(resource, type: SuiteQLResponse.self)

                var result: [String: String] = [:]
                for row in response.items {
                    guard let id = row.values["id"] else { continue }

                    // Priority: displayname > companyname > entityid
                    if let displayName = row.values["displayname"], !displayName.isEmpty {
                        result[id] = displayName
                    } else if let companyName = row.values["companyname"], !companyName.isEmpty {
                        result[id] = companyName
                    } else if let entityId = row.values["entityid"], !entityId.isEmpty {
                        result[id] = entityId
                    } else {
                        result[id] = "Customer \(id)"
                    }
                }

                return result
            }
        } catch {
            print("CustomerNameCache: Failed to batch fetch names: \(error)")
            // Return fallback names for all requested IDs
            var fallback: [String: String] = [:]
            for id in uniqueIds {
                fallback[id] = "Customer \(id)"
            }
            return fallback
        }
    }
}
