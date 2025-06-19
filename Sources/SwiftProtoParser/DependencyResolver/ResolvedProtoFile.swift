import Foundation

/// Represents a proto file that has been resolved with its dependencies.
public struct ResolvedProtoFile {

  // MARK: - Properties

  /// The absolute path to the proto file.
  public let filePath: String

  /// The original import path (relative path used in import statements).
  public let importPath: String

  /// The content of the proto file.
  public let content: String

  /// List of import statements found in this file.
  public let imports: [String]

  /// The syntax version declared in the file (e.g., "proto3").
  public let syntax: String?

  /// Package name declared in the file.
  public let packageName: String?

  /// File modification time for caching.
  public let modificationTime: Date

  /// File size in bytes.
  public let fileSize: Int64

  /// Whether this is the main file being parsed (not a dependency).
  public let isMainFile: Bool

  // MARK: - Computed Properties

  /// The directory containing this proto file.
  public var directory: String {
    return (filePath as NSString).deletingLastPathComponent
  }

  /// The filename without path.
  public var fileName: String {
    return (filePath as NSString).lastPathComponent
  }

  /// The filename without extension.
  public var baseName: String {
    let filename = fileName
    if filename.hasSuffix(".proto") {
      return String(filename.dropLast(6))
    }
    return filename
  }

  // MARK: - Initializers

  /// Initialize a resolved proto file.
  /// - Parameters:.
  ///   - filePath: Absolute path to the file.
  ///   - importPath: Import path used in import statements.
  ///   - content: File content.
  ///   - imports: List of import statements.
  ///   - syntax: Syntax version.
  ///   - packageName: Package name.
  ///   - modificationTime: File modification time.
  ///   - fileSize: File size in bytes.
  ///   - isMainFile: Whether this is the main file.
  public init(
    filePath: String,
    importPath: String,
    content: String,
    imports: [String],
    syntax: String? = nil,
    packageName: String? = nil,
    modificationTime: Date,
    fileSize: Int64,
    isMainFile: Bool = false
  ) {
    self.filePath = filePath
    self.importPath = importPath
    self.content = content
    self.imports = imports
    self.syntax = syntax
    self.packageName = packageName
    self.modificationTime = modificationTime
    self.fileSize = fileSize
    self.isMainFile = isMainFile
  }

  // MARK: - Factory Methods

  /// Create a ResolvedProtoFile from a file path.
  /// - Parameters:.
  ///   - filePath: Absolute path to the proto file.
  ///   - importPath: Import path (defaults to filename).
  ///   - isMainFile: Whether this is the main file.
  /// - Returns: ResolvedProtoFile or throws an error.
  public static func from(
    filePath: String,
    importPath: String? = nil,
    isMainFile: Bool = false
  ) throws -> ResolvedProtoFile {

    // Check if file exists
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: filePath) else {
      throw ResolverError.fileNotFound(filePath)
    }

    // Get file attributes
    let attributes = try fileManager.attributesOfItem(atPath: filePath)
    let modificationTime = attributes[.modificationDate] as? Date ?? Date()
    let fileSize = attributes[.size] as? Int64 ?? 0

    // Read file content
    let content: String
    do {
      content = try String(contentsOfFile: filePath, encoding: .utf8)
    }
    catch {
      throw ResolverError.ioError(filePath, underlying: error.localizedDescription)
    }

    // Parse basic info from content
    let (imports, syntax, packageName) = parseBasicInfo(from: content)

    // Use provided import path or derive from filename
    let resolvedImportPath = importPath ?? (filePath as NSString).lastPathComponent

    return ResolvedProtoFile(
      filePath: filePath,
      importPath: resolvedImportPath,
      content: content,
      imports: imports,
      syntax: syntax,
      packageName: packageName,
      modificationTime: modificationTime,
      fileSize: fileSize,
      isMainFile: isMainFile
    )
  }

  // MARK: - Helper Methods

  /// Parse basic information from proto file content.
  /// - Parameter content: The proto file content.
  /// - Returns: Tuple of (imports, syntax, package).
  private static func parseBasicInfo(from content: String) -> ([String], String?, String?) {
    var imports: [String] = []
    var syntax: String?
    var packageName: String?

    let lines = content.components(separatedBy: .newlines)

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

      // Skip comments and empty lines
      if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
        continue
      }

      // Parse syntax declaration
      if trimmed.hasPrefix("syntax") {
        syntax = extractSyntax(from: trimmed)
      }

      // Parse package declaration
      if trimmed.hasPrefix("package") {
        packageName = extractPackage(from: trimmed)
      }

      // Parse import statements
      if trimmed.hasPrefix("import") {
        if let importPath = extractImport(from: trimmed) {
          imports.append(importPath)
        }
      }
    }

    return (imports, syntax, packageName)
  }

  /// Extract syntax version from syntax declaration.
  private static func extractSyntax(from line: String) -> String? {
    // syntax = "proto3";
    let pattern = #"syntax\s*=\s*"([^"]+)""#
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: line.count)

    if let match = regex?.firstMatch(in: line, range: range),
      let syntaxRange = Range(match.range(at: 1), in: line)
    {
      return String(line[syntaxRange])
    }

    return nil
  }

  /// Extract package name from package declaration.
  private static func extractPackage(from line: String) -> String? {
    // package com.example;
    let pattern = #"package\s+([\w.]+)\s*;"#
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: line.count)

    if let match = regex?.firstMatch(in: line, range: range),
      let packageRange = Range(match.range(at: 1), in: line)
    {
      return String(line[packageRange])
    }

    return nil
  }

  /// Extract import path from import statement.
  private static func extractImport(from line: String) -> String? {
    // import "path/to/file.proto";
    // import public "path/to/file.proto";
    // import weak "path/to/file.proto";
    let pattern = #"import\s+(?:public\s+|weak\s+)?"([^"]+)""#
    let regex = try? NSRegularExpression(pattern: pattern)
    let range = NSRange(location: 0, length: line.count)

    if let match = regex?.firstMatch(in: line, range: range),
      let importRange = Range(match.range(at: 1), in: line)
    {
      return String(line[importRange])
    }

    return nil
  }
}

// MARK: - Equatable

extension ResolvedProtoFile: Equatable {
  public static func == (lhs: ResolvedProtoFile, rhs: ResolvedProtoFile) -> Bool {
    return lhs.filePath == rhs.filePath && lhs.importPath == rhs.importPath && lhs.content == rhs.content
  }
}

// MARK: - Hashable

extension ResolvedProtoFile: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(filePath)
    hasher.combine(importPath)
  }
}

// MARK: - CustomStringConvertible

extension ResolvedProtoFile: CustomStringConvertible {
  public var description: String {
    var components = ["ResolvedProtoFile("]
    components.append("file: \(fileName)")
    components.append("import: \(importPath)")
    if let syntax = syntax {
      components.append("syntax: \(syntax)")
    }
    if let package = packageName {
      components.append("package: \(package)")
    }
    components.append("imports: \(imports.count)")
    if isMainFile {
      components.append("main")
    }
    components.append(")")
    return components.joined(separator: ", ")
  }
}
