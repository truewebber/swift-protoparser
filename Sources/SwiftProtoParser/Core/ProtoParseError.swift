import Foundation

// MARK: - ProtoParseError

/// Main error type for SwiftProtoParser public API.
///
/// This error type encapsulates all possible errors that can occur during
/// Protocol Buffers file parsing, from file system issues to syntax errors.
public enum ProtoParseError: Error {

  // MARK: - File System Errors

  /// File not found at the specified path
  case fileNotFound(String)

  /// I/O error occurred while reading or writing files
  case ioError(underlying: Error)

  // MARK: - Dependency Resolution Errors

  /// Failed to resolve import dependencies
  case dependencyResolutionError(message: String, importPath: String)

  /// Circular dependency detected in import chain
  case circularDependency([String])

  // MARK: - Parsing Errors

  /// Lexical analysis error (tokenization failure)
  case lexicalError(message: String, file: String, line: Int, column: Int)

  /// Syntax parsing error (grammar rule violation)
  case syntaxError(message: String, file: String, line: Int, column: Int)

  /// Semantic validation error (type checking, etc.)
  case semanticError(message: String, context: String)

  // MARK: - Internal Errors

  /// Internal parser state corruption or unexpected condition
  case internalError(message: String)
}

// MARK: - ProtoParseError + LocalizedError

extension ProtoParseError: LocalizedError {

  /// A localized message describing what error occurred.
  public var errorDescription: String? {
    switch self {
    case .fileNotFound(let path):
      return "File not found: \(path)"

    case .ioError(let underlying):
      return "I/O error: \(underlying.localizedDescription)"

    case .dependencyResolutionError(let message, let importPath):
      return "Dependency resolution failed for '\(importPath)': \(message)"

    case .circularDependency(let chain):
      return "Circular dependency detected: \(chain.joined(separator: " → "))"

    case .lexicalError(let message, let file, let line, let column):
      return "Lexical error in \(file) at \(line):\(column): \(message)"

    case .syntaxError(let message, let file, let line, let column):
      return "Syntax error in \(file) at \(line):\(column): \(message)"

    case .semanticError(let message, let context):
      return "Semantic error in \(context): \(message)"

    case .internalError(let message):
      return "Internal parser error: \(message)"
    }
  }

  /// A localized message describing the reason for the failure.
  public var failureReason: String? {
    switch self {
    case .fileNotFound:
      return "The specified Protocol Buffers file could not be found."

    case .ioError:
      return "An I/O operation failed while processing the file."

    case .dependencyResolutionError:
      return "Failed to resolve imported dependencies."

    case .circularDependency:
      return "Import dependencies form a circular reference."

    case .lexicalError:
      return "Invalid token or character sequence encountered."

    case .syntaxError:
      return "The file does not conform to Protocol Buffers syntax rules."

    case .semanticError:
      return "The file contains semantically invalid constructs."

    case .internalError:
      return "An unexpected internal error occurred."
    }
  }

  /// A localized message describing how one might recover from the failure.
  public var recoverySuggestion: String? {
    switch self {
    case .fileNotFound:
      return "Check that the file path is correct and the file exists."

    case .ioError:
      return "Ensure the file is readable and not corrupted."

    case .dependencyResolutionError:
      return "Verify that all imported files are available in the import paths."

    case .circularDependency:
      return "Remove circular imports by restructuring the dependency chain."

    case .lexicalError:
      return "Check for invalid characters or malformed tokens in the file."

    case .syntaxError:
      return "Verify the file follows valid Protocol Buffers 3 syntax."

    case .semanticError:
      return "Review field types, message definitions, and naming conventions."

    case .internalError:
      return "This may be a bug in SwiftProtoParser. Please report it."
    }
  }
}

// MARK: - ProtoParseError + CustomStringConvertible

extension ProtoParseError: CustomStringConvertible {

  public var description: String {
    return errorDescription ?? "Unknown ProtoParseError"
  }
}

// MARK: - ProtoParseError + Convenience Initializers

extension ProtoParseError {

  /// Creates a file not found error for the specified path
  public static func fileNotFound(at path: String) -> ProtoParseError {
    return .fileNotFound(path)
  }

  /// Creates a lexical error with position information
  public static func lexical(_ message: String, in file: String, at line: Int, column: Int) -> ProtoParseError {
    return .lexicalError(message: message, file: file, line: line, column: column)
  }

  /// Creates a syntax error with position information
  public static func syntax(_ message: String, in file: String, at line: Int, column: Int) -> ProtoParseError {
    return .syntaxError(message: message, file: file, line: line, column: column)
  }

  /// Creates a semantic error with context
  public static func semantic(_ message: String, context: String) -> ProtoParseError {
    return .semanticError(message: message, context: context)
  }

  /// Creates a dependency resolution error
  public static func dependencyResolution(_ message: String, importPath: String) -> ProtoParseError {
    return .dependencyResolutionError(message: message, importPath: importPath)
  }
}
