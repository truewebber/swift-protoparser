import Foundation
@testable import SwiftProtoParser

/// A mock file provider for testing import resolution
class MockFileProvider: FileProvider {
    private var files: [String: String] = [:]
    private var importPaths: [String] = []
    
    /// Initializes a new mock file provider
    /// - Parameter files: A dictionary mapping file paths to file contents
    init(files: [String: String] = [:], importPaths: [String] = []) {
        self.files = files
        self.importPaths = importPaths
    }
    
    /// Adds a file to the mock provider
    /// - Parameters:
    ///   - content: The file content
    ///   - path: The file path
    func addFile(_ content: String, at path: String) {
        files[path] = content
    }
    
    /// Adds an import path to the mock provider
    /// - Parameter path: The import path
    func addImportPath(_ path: String) {
        importPaths.append(path)
    }
    
    // MARK: - FileProvider Protocol
    
    func fileExists(_ path: String) -> Bool {
        return files.keys.contains(path)
    }
    
    func readFile(_ path: String) throws -> String {
        guard let content = files[path] else {
            throw ImportError.fileNotFound(path)
        }
        
        return content
    }
    
    func resolvePath(_ path: String) -> String? {
        // First, check if the path exists directly
        if fileExists(path) {
            return path
        }
        
        // Try each import path
        for importDirectory in importPaths {
            let resolvedPath = (importDirectory as NSString).appendingPathComponent(path)
            
            if fileExists(resolvedPath) {
                return resolvedPath
            }
        }
        
        return nil
    }
} 