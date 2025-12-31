import Foundation

/// Helper for building safe SuiteQL queries with proper escaping
/// to prevent SQL injection attacks
struct SuiteQLHelper {

    /// Escape a string value for use in SuiteQL queries
    /// Handles single quotes, backslashes, and other special characters
    static func escape(_ value: String) -> String {
        var escaped = value
        // Escape backslashes first
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        // Escape single quotes (SQL standard)
        escaped = escaped.replacingOccurrences(of: "'", with: "''")
        // Remove null bytes
        escaped = escaped.replacingOccurrences(of: "\0", with: "")
        // Escape newlines and carriage returns
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        return escaped
    }

    /// Wrap an escaped value in single quotes for SQL
    static func quote(_ value: String) -> String {
        return "'\(escape(value))'"
    }

    /// Escape and validate a numeric ID (should only contain digits)
    /// Returns nil if the ID contains non-numeric characters
    static func escapeNumericId(_ id: String) -> String? {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        // Validate that it only contains digits
        guard trimmed.allSatisfy({ $0.isNumber }) else {
            print("Warning: Invalid numeric ID provided: \(id)")
            return nil
        }
        return trimmed
    }

    /// Build a safe IN clause from an array of IDs
    /// Returns nil if any ID is invalid
    static func buildInClause(ids: [String]) -> String? {
        let validIds = ids.compactMap { escapeNumericId($0) }
        guard validIds.count == ids.count else {
            return nil
        }
        return validIds.map { "'\($0)'" }.joined(separator: ",")
    }

    /// Build a safe LIKE pattern for search queries
    static func buildLikePattern(_ searchTerm: String, position: LikePosition = .contains) -> String {
        let escaped = escape(searchTerm)
            // Also escape SQL LIKE wildcards
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")

        switch position {
        case .startsWith:
            return "'\(escaped)%'"
        case .endsWith:
            return "'%\(escaped)'"
        case .contains:
            return "'%\(escaped)%'"
        case .exact:
            return "'\(escaped)'"
        }
    }

    enum LikePosition {
        case startsWith
        case endsWith
        case contains
        case exact
    }

    /// Validate and escape a date string for SuiteQL
    /// Expects format: yyyy-MM-dd
    static func escapeDateString(_ dateString: String) -> String? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate date format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard dateFormatter.date(from: trimmed) != nil else {
            print("Warning: Invalid date format provided: \(dateString)")
            return nil
        }

        return "'\(trimmed)'"
    }

    /// Convert a Date to a safe SuiteQL date string
    static func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return "'\(dateFormatter.string(from: date))'"
    }

    /// Validate column/table names (alphanumeric and underscores only)
    static func validateIdentifier(_ identifier: String) -> Bool {
        let pattern = "^[a-zA-Z_][a-zA-Z0-9_]*$"
        return identifier.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Query Builder

/// A type-safe query builder for SuiteQL
struct SuiteQLQueryBuilder {
    private var selectClauses: [String] = []
    private var fromTable: String = ""
    private var whereClauses: [String] = []
    private var orderByClauses: [String] = []
    private var limitValue: Int?
    private var offsetValue: Int?

    init(from table: String) {
        guard SuiteQLHelper.validateIdentifier(table) else {
            fatalError("Invalid table name: \(table)")
        }
        self.fromTable = table
    }

    mutating func select(_ columns: [String]) -> SuiteQLQueryBuilder {
        for column in columns {
            // Allow qualified names like "t.id"
            let parts = column.split(separator: ".")
            for part in parts {
                guard SuiteQLHelper.validateIdentifier(String(part)) else {
                    fatalError("Invalid column name: \(column)")
                }
            }
        }
        selectClauses = columns
        return self
    }

    mutating func whereEquals(_ column: String, value: String) -> SuiteQLQueryBuilder {
        guard SuiteQLHelper.validateIdentifier(column.replacingOccurrences(of: ".", with: "_")) ||
              column.split(separator: ".").allSatisfy({ SuiteQLHelper.validateIdentifier(String($0)) }) else {
            fatalError("Invalid column name: \(column)")
        }
        whereClauses.append("\(column) = \(SuiteQLHelper.quote(value))")
        return self
    }

    mutating func whereIdEquals(_ column: String, id: String) -> SuiteQLQueryBuilder {
        guard let safeId = SuiteQLHelper.escapeNumericId(id) else {
            fatalError("Invalid numeric ID: \(id)")
        }
        whereClauses.append("\(column) = '\(safeId)'")
        return self
    }

    mutating func whereIn(_ column: String, ids: [String]) -> SuiteQLQueryBuilder {
        guard let inClause = SuiteQLHelper.buildInClause(ids: ids) else {
            fatalError("Invalid IDs in IN clause")
        }
        whereClauses.append("\(column) IN (\(inClause))")
        return self
    }

    mutating func whereLike(_ column: String, pattern: String, position: SuiteQLHelper.LikePosition = .contains) -> SuiteQLQueryBuilder {
        let safePattern = SuiteQLHelper.buildLikePattern(pattern, position: position)
        whereClauses.append("UPPER(\(column)) LIKE UPPER(\(safePattern))")
        return self
    }

    mutating func whereDateGreaterThan(_ column: String, date: Date) -> SuiteQLQueryBuilder {
        whereClauses.append("\(column) >= \(SuiteQLHelper.formatDate(date))")
        return self
    }

    mutating func whereRaw(_ clause: String) -> SuiteQLQueryBuilder {
        // Use with caution - only for trusted internal clauses
        whereClauses.append(clause)
        return self
    }

    mutating func orderBy(_ column: String, ascending: Bool = true) -> SuiteQLQueryBuilder {
        let direction = ascending ? "ASC" : "DESC"
        orderByClauses.append("\(column) \(direction)")
        return self
    }

    mutating func limit(_ value: Int) -> SuiteQLQueryBuilder {
        limitValue = max(0, value)
        return self
    }

    mutating func offset(_ value: Int) -> SuiteQLQueryBuilder {
        offsetValue = max(0, value)
        return self
    }

    func build() -> String {
        var query = "SELECT "
        query += selectClauses.isEmpty ? "*" : selectClauses.joined(separator: ", ")
        query += " FROM \(fromTable)"

        if !whereClauses.isEmpty {
            query += " WHERE " + whereClauses.joined(separator: " AND ")
        }

        if !orderByClauses.isEmpty {
            query += " ORDER BY " + orderByClauses.joined(separator: ", ")
        }

        if let limit = limitValue {
            query += " LIMIT \(limit)"
        }

        if let offset = offsetValue {
            query += " OFFSET \(offset)"
        }

        return query
    }
}
