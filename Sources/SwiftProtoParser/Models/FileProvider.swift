import Foundation

/// Protocol for providing file system access
public protocol FileProvider {
    /// Read a file at the given path
    /// - Parameter path: The path to read
    /// - Returns: The file contents
    /// - Throws: Error if file cannot be read
    func readFile(_ path: String) throws -> String
    
    /// Check if a file exists at the given path
    /// - Parameter path: The path to check
    /// - Returns: True if file exists
    func fileExists(_ path: String) -> Bool
    
    /// Resolve a relative path against import paths
    /// - Parameter path: The path to resolve
    /// - Returns: The absolute path if found
    func resolvePath(_ path: String) -> String?
}

/// Default file provider using FileManager
public struct DefaultFileProvider: FileProvider {
    /// Import paths to search
    private let importPaths: [String]
    
    /// Initialize with import paths
    /// - Parameter importPaths: Paths to search for imports
    public init(importPaths: [String]) {
        self.importPaths = importPaths
    }
    
    public func readFile(_ path: String) throws -> String {
        return try String(contentsOfFile: path, encoding: .utf8)
    }
    
    public func fileExists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    public func resolvePath(_ path: String) -> String? {
        // First check if the path is absolute or relative to current directory
        if fileExists(path) {
            return path
        }
        
        // Then check import paths
        for importPath in importPaths {
            let resolvedPath = (importPath as NSString).appendingPathComponent(path)
            if fileExists(resolvedPath) {
                return resolvedPath
            }
        }
        
        return nil
    }
}

/// Manages proto file imports and resolution
public final class ImportResolver {
    /// The file provider to use
    private let fileProvider: FileProvider
    
    /// Cache of parsed files
    private var fileCache: [String: FileNode] = [:]
    
    /// Set of files currently being processed (for circular import detection)
    private var processingFiles: Set<String> = []
    
    /// The parser to use for parsing imported files
    private let parser: (String) throws -> FileNode
    
    /// Initialize a new import resolver
    /// - Parameters:
    ///   - fileProvider: The file provider to use
    ///   - parser: Function to parse proto files
    public init(
        fileProvider: FileProvider,
        parser: @escaping (String) throws -> FileNode
    ) {
        self.fileProvider = fileProvider
        self.parser = parser
    }
    
    /// Resolve an imported file
    /// - Parameter path: The import path
    /// - Returns: The parsed file node
    /// - Throws: ImportError if resolution fails
    public func resolveImport(_ path: String) throws -> FileNode {
        // Check if we have a cached version
        if let cached = fileCache[path] {
            return cached
        }
        
        // Resolve the actual file path
        guard let resolvedPath = fileProvider.resolvePath(path) else {
            throw ImportError.fileNotFound(path)
        }
        
        // Check for circular imports
        guard !processingFiles.contains(resolvedPath) else {
            throw ImportError.circularImport(path)
        }
        
        // Mark as processing
        processingFiles.insert(resolvedPath)
        defer { processingFiles.remove(resolvedPath) }
        
        // Read and parse the file
        let content = try fileProvider.readFile(resolvedPath)
        let file = try parser(content)
        
        // Cache the result
        fileCache[path] = file
        
        return file
    }
    
    /// Resolve a type in imported files
    /// - Parameter name: The type name to resolve
    /// - Returns: The fully qualified name if found
    /// - Throws: ImportError if resolution fails
    public func resolveType(_ name: String) throws -> String? {
        // Check all cached files for the type
        for (_, file) in fileCache {
            if let type = file.findType(name) {
                return type.fullName(inPackage: file.package)
            }
        }
        return nil
    }
    
    /// Clear the import cache
    public func clearCache() {
        fileCache.removeAll()
        processingFiles.removeAll()
    }
    
    /// Get all imported files
    /// - Returns: Array of imported file paths
    public func importedFiles() -> [String] {
        return Array(fileCache.keys)
    }
    
    /// Get all types defined in imported files
    /// - Returns: Dictionary mapping type names to their defining files
    public func importedTypes() -> [String: String] {
        var types: [String: String] = [:]
        
        for (path, file) in fileCache {
            for type in file.allDefinedTypes {
                let fullName = type.fullName(inPackage: file.package)
                types[fullName] = path
            }
        }
        
        return types
    }
}

/// Errors that can occur during import resolution
public enum ImportError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case circularImport(String)
    case invalidImport(String)
    case parseError(String, Error)
    
    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "Import not found: \(path)"
        case .circularImport(let path):
            return "Circular import detected: \(path)"
        case .invalidImport(let path):
            return "Invalid import: \(path)"
        case .parseError(let path, let error):
            return "Error parsing import \(path): \(error)"
        }
    }
}
