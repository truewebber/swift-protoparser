import Foundation

// MARK: - KeywordRecognizer

/// Utility for recognizing Protocol Buffers keywords vs identifiers.
/// 
/// This struct provides efficient keyword recognition by utilizing the 
/// `ProtoKeyword` enum's raw value initialization capabilities.
internal struct KeywordRecognizer {
    
    // MARK: - Private Properties
    
    /// Cache of all keyword strings for fast lookup
    /// Using a Set for O(1) average lookup time
    private static let keywordStrings: Set<String> = {
        return Set(ProtoKeyword.allCases.map { $0.rawValue })
    }()
    
    // MARK: - Recognition Methods
    
    /// Recognizes whether an identifier string is a keyword or regular identifier.
    /// 
    /// - Parameter identifier: The string to analyze
    /// - Returns: A `Token` - either `.keyword` if recognized, or `.identifier` if not
    internal static func recognize(_ identifier: String) -> Token {
        // Fast path: check if it's a keyword using raw value initialization
        if let keyword = ProtoKeyword(rawValue: identifier) {
            return .keyword(keyword)
        } else {
            return .identifier(identifier)
        }
    }
    
    /// Checks if a string is a Protocol Buffers keyword.
    /// 
    /// - Parameter string: The string to check
    /// - Returns: `true` if the string is a keyword, `false` otherwise
    internal static func isKeyword(_ string: String) -> Bool {
        return keywordStrings.contains(string)
    }
    
    /// Checks if a string is a valid identifier (not a keyword).
    /// 
    /// This method only checks for keyword conflicts, not identifier syntax validity.
    /// 
    /// - Parameter string: The string to check
    /// - Returns: `true` if the string is not a keyword, `false` if it is a keyword
    internal static func isValidIdentifier(_ string: String) -> Bool {
        return !isKeyword(string)
    }
    
    /// Returns the keyword for a given string, if it exists.
    /// 
    /// - Parameter string: The string to look up
    /// - Returns: The corresponding `ProtoKeyword` if found, `nil` otherwise
    internal static func getKeyword(_ string: String) -> ProtoKeyword? {
        return ProtoKeyword(rawValue: string)
    }
}

// MARK: - KeywordRecognizer + Validation

extension KeywordRecognizer {
    
    /// Validates that an identifier name doesn't conflict with keywords.
    /// 
    /// - Parameter identifier: The identifier to validate
    /// - Returns: `true` if the identifier is valid (not a keyword), `false` otherwise
    internal static func validateIdentifierName(_ identifier: String) -> Bool {
        return isValidIdentifier(identifier)
    }
    
    /// Provides suggestions for identifier names that conflict with keywords.
    /// 
    /// - Parameter conflictingIdentifier: An identifier that conflicts with a keyword
    /// - Returns: A suggested alternative identifier name
    internal static func suggestAlternative(for conflictingIdentifier: String) -> String {
        if isKeyword(conflictingIdentifier) {
            // Common patterns for avoiding keyword conflicts
            return "\(conflictingIdentifier)_value"
        } else {
            return conflictingIdentifier
        }
    }
}

// MARK: - KeywordRecognizer + Categories

extension KeywordRecognizer {
    
    /// Checks if a keyword belongs to the core language keywords.
    /// 
    /// - Parameter keyword: The keyword to check
    /// - Returns: `true` if it's a core keyword (syntax, package, import, option)
    internal static func isCoreKeyword(_ keyword: ProtoKeyword) -> Bool {
        switch keyword {
        case .syntax, .package, .import, .option:
            return true
        default:
            return false
        }
    }
    
    /// Checks if a keyword is related to type definitions.
    /// 
    /// - Parameter keyword: The keyword to check
    /// - Returns: `true` if it's a type definition keyword (message, enum, service, rpc)
    internal static func isTypeDefinitionKeyword(_ keyword: ProtoKeyword) -> Bool {
        switch keyword {
        case .message, .enum, .service, .rpc:
            return true
        default:
            return false
        }
    }
    
    /// Checks if a keyword is a field modifier.
    /// 
    /// - Parameter keyword: The keyword to check
    /// - Returns: `true` if it's a field modifier (repeated, optional, required)
    internal static func isFieldModifierKeyword(_ keyword: ProtoKeyword) -> Bool {
        switch keyword {
        case .repeated, .optional, .required:
            return true
        default:
            return false
        }
    }
    
    /// Checks if a keyword is related to service definitions.
    /// 
    /// - Parameter keyword: The keyword to check
    /// - Returns: `true` if it's a service keyword (returns, stream, rpc)
    internal static func isServiceKeyword(_ keyword: ProtoKeyword) -> Bool {
        switch keyword {
        case .returns, .stream, .rpc:
            return true
        default:
            return false
        }
    }
    
    /// Checks if a keyword is for proto2 compatibility.
    /// 
    /// - Parameter keyword: The keyword to check
    /// - Returns: `true` if it's a proto2 compatibility keyword
    internal static func isProto2CompatibilityKeyword(_ keyword: ProtoKeyword) -> Bool {
        switch keyword {
        case .optional, .required, .extend, .extensions, .group:
            return true
        default:
            return false
        }
    }
}

// MARK: - KeywordRecognizer + Performance

extension KeywordRecognizer {
    
    /// Returns the total number of recognized keywords.
    /// 
    /// This is useful for testing and debugging purposes.
    /// 
    /// - Returns: The count of all Protocol Buffers keywords
    internal static var keywordCount: Int {
        return ProtoKeyword.allCases.count
    }
    
    /// Returns all keyword strings for debugging purposes.
    /// 
    /// - Returns: A sorted array of all keyword strings
    internal static var allKeywordStrings: [String] {
        return ProtoKeyword.allCases.map { $0.rawValue }.sorted()
    }
}
