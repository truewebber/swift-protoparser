import Foundation

/// Errors that can occur during dependency resolution
public enum ResolverError: Error, Equatable, LocalizedError {
  
  // MARK: - File System Errors
  
  /// Proto file not found at specified path
  case fileNotFound(String)
  
  /// Directory not found or not accessible
  case directoryNotFound(String)
  
  /// IO error reading file
  case ioError(String, underlying: String)
  
  // MARK: - Import Resolution Errors
  
  /// Import statement could not be resolved
  case importNotFound(String, searchPaths: [String])
  
  /// Circular dependency detected
  case circularDependency([String])
  
  /// Invalid import path format
  case invalidImportPath(String)
  
  // MARK: - Validation Errors
  
  /// Proto file has invalid syntax declaration
  case invalidSyntax(String, expected: String)
  
  /// Proto file missing required syntax declaration
  case missingSyntax(String)
  
  /// Duplicate file in dependency graph
  case duplicateFile(String, paths: [String])
  
  // MARK: - Configuration Errors
  
  /// No import paths provided and file has imports
  case noImportPaths(String)
  
  /// Invalid or inaccessible import path with detailed reason
  case invalidImportPathWithReason(String, reason: String)
  
  // MARK: - LocalizedError Implementation
  
  public var errorDescription: String? {
    switch self {
    case .fileNotFound(let path):
      return "Proto file not found: \(path)"
      
    case .directoryNotFound(let path):
      return "Directory not found: \(path)"
      
    case .ioError(let path, let underlying):
      return "IO error reading file '\(path)': \(underlying)"
      
    case .importNotFound(let importPath, let searchPaths):
      return "Import '\(importPath)' not found in search paths: \(searchPaths.joined(separator: ", "))"
      
    case .circularDependency(let cycle):
      return "Circular dependency detected: \(cycle.joined(separator: " → "))"
      
    case .invalidImportPath(let path):
      return "Invalid import path format: \(path)"
      
    case .invalidSyntax(let file, let expected):
      return "Invalid syntax in file '\(file)'. Expected: \(expected)"
      
    case .missingSyntax(let file):
      return "Missing syntax declaration in file: \(file)"
      
    case .duplicateFile(let fileName, let paths):
      return "Duplicate file '\(fileName)' found at: \(paths.joined(separator: ", "))"
      
    case .noImportPaths(let file):
      return "File '\(file)' has imports but no import paths provided"
      
    case .invalidImportPathWithReason(let path, let reason):
      return "Invalid import path '\(path)': \(reason)"
    }
  }
  
  public var failureReason: String? {
    switch self {
    case .circularDependency:
      return "Proto files cannot import each other in a circular manner"
    case .importNotFound:
      return "Make sure the imported file exists and import paths are correctly configured"
    case .fileNotFound:
      return "Check the file path and ensure the file exists"
    default:
      return nil
    }
  }
  
  public var recoverySuggestion: String? {
    switch self {
    case .importNotFound(_, let searchPaths):
      if searchPaths.isEmpty {
        return "Provide import paths using the importPaths parameter"
      } else {
        return "Add the directory containing the imported file to your import paths"
      }
    case .circularDependency:
      return "Restructure your proto files to remove circular imports"
    case .noImportPaths:
      return "Provide import paths where dependent proto files can be found"
    default:
      return nil
    }
  }
}
