import Foundation

/// Configuration options for the proto parser.
public struct Configuration {
  /// Paths to search for imports.
  public let importPaths: [String]

  /// Whether to generate source code info.
  public let generateSourceInfo: Bool

  /// Whether to allow type name aliases.
  public let allowAliases: Bool

  /// Whether to allow services.
  public let allowServices: Bool

  /// Whether to validate field defaults.
  public let validateDefaults: Bool

  /// Whether to allow extensions.
  public let allowExtensions: Bool

  /// Maximum recursion depth for nested messages.
  public let maxRecursionDepth: Int

  /// Whether to preserve unknown fields.
  public let preserveUnknownFields: Bool

  /// Options for naming conventions.
  public struct NamingOptions {
    /// Whether to enforce standard naming conventions.
    public let enforceConventions: Bool

    /// Whether to allow underscores in type names.
    public let allowUnderscoresInTypes: Bool

    /// Whether to allow underscores in field names.
    public let allowUnderscoresInFields: Bool

    /// Initialize naming options.
    /// - Parameters:.
    ///   - enforceConventions: Whether to enforce standard naming conventions.
    ///   - allowUnderscoresInTypes: Whether to allow underscores in type names.
    ///   - allowUnderscoresInFields: Whether to allow underscores in field names.
    public init(
      enforceConventions: Bool = true,
      allowUnderscoresInTypes: Bool = true,
      allowUnderscoresInFields: Bool = true
    ) {
      self.enforceConventions = enforceConventions
      self.allowUnderscoresInTypes = allowUnderscoresInTypes
      self.allowUnderscoresInFields = allowUnderscoresInFields
    }
  }

  /// Options for output generation.
  public struct OutputOptions {
    /// Whether to generate source code info.
    public let generateSourceInfo: Bool

    /// Whether to generate json names.
    public let generateJsonNames: Bool

    /// Whether to preserve proto names.
    public let preserveProtoNames: Bool

    /// Initialize output options.
    /// - Parameters:.
    ///   - generateSourceInfo: Whether to generate source code info.
    ///   - generateJsonNames: Whether to generate json names.
    ///   - preserveProtoNames: Whether to preserve proto names.
    public init(
      generateSourceInfo: Bool = true,
      generateJsonNames: Bool = true,
      preserveProtoNames: Bool = false
    ) {
      self.generateSourceInfo = generateSourceInfo
      self.generateJsonNames = generateJsonNames
      self.preserveProtoNames = preserveProtoNames
    }
  }

  /// Naming options.
  public let namingOptions: NamingOptions

  /// Output options.
  public let outputOptions: OutputOptions

  /// Initialize configuration with default values.
  public init(
    importPaths: [String] = [],
    generateSourceInfo: Bool = true,
    allowAliases: Bool = true,
    allowServices: Bool = true,
    validateDefaults: Bool = true,
    allowExtensions: Bool = false,
    maxRecursionDepth: Int = 100,
    preserveUnknownFields: Bool = false,
    namingOptions: NamingOptions = NamingOptions(),
    outputOptions: OutputOptions = OutputOptions()
  ) {
    self.importPaths = importPaths
    self.generateSourceInfo = generateSourceInfo
    self.allowAliases = allowAliases
    self.allowServices = allowServices
    self.validateDefaults = validateDefaults
    self.allowExtensions = allowExtensions
    self.maxRecursionDepth = maxRecursionDepth
    self.preserveUnknownFields = preserveUnknownFields
    self.namingOptions = namingOptions
    self.outputOptions = outputOptions
  }
}

// MARK: - Configuration Builder

extension Configuration {
  /// Builder for creating configurations.
  public final class Builder {
    private var importPaths: [String] = []
    private var generateSourceInfo: Bool = true
    private var allowAliases: Bool = true
    private var allowServices: Bool = true
    private var validateDefaults: Bool = true
    private var allowExtensions: Bool = false
    private var maxRecursionDepth: Int = 100
    private var preserveUnknownFields: Bool = false
    private var namingOptions = NamingOptions()
    private var outputOptions = OutputOptions()

    /// Initialize a new builder.
    public init() {}

    /// Add an import path.
    @discardableResult
    public func addImportPath(_ path: String) -> Builder {
      importPaths.append(path)
      return self
    }

    /// Set whether to generate source info.
    @discardableResult
    public func withSourceInfo(_ generate: Bool) -> Builder {
      generateSourceInfo = generate
      return self
    }

    /// Set whether to allow aliases.
    @discardableResult
    public func withAliases(_ allow: Bool) -> Builder {
      allowAliases = allow
      return self
    }

    /// Set whether to allow services.
    @discardableResult
    public func withServices(_ allow: Bool) -> Builder {
      allowServices = allow
      return self
    }

    /// Set whether to validate defaults.
    @discardableResult
    public func withDefaultValidation(_ validate: Bool) -> Builder {
      validateDefaults = validate
      return self
    }

    /// Set whether to allow extensions.
    @discardableResult
    public func withExtensions(_ allow: Bool) -> Builder {
      allowExtensions = allow
      return self
    }

    /// Set maximum recursion depth.
    @discardableResult
    public func withMaxRecursionDepth(_ depth: Int) -> Builder {
      maxRecursionDepth = depth
      return self
    }

    /// Set whether to preserve unknown fields.
    @discardableResult
    public func withUnknownFields(_ preserve: Bool) -> Builder {
      preserveUnknownFields = preserve
      return self
    }

    /// Set naming options.
    @discardableResult
    public func withNamingOptions(_ options: NamingOptions) -> Builder {
      namingOptions = options
      return self
    }

    /// Set output options.
    @discardableResult
    public func withOutputOptions(_ options: OutputOptions) -> Builder {
      outputOptions = options
      return self
    }

    /// Build the configuration.
    public func build() -> Configuration {
      return Configuration(
        importPaths: importPaths,
        generateSourceInfo: generateSourceInfo,
        allowAliases: allowAliases,
        allowServices: allowServices,
        validateDefaults: validateDefaults,
        allowExtensions: allowExtensions,
        maxRecursionDepth: maxRecursionDepth,
        preserveUnknownFields: preserveUnknownFields,
        namingOptions: namingOptions,
        outputOptions: outputOptions
      )
    }
  }
}

// MARK: - Configuration Extensions

extension Configuration {
  /// Create a new builder.
  public static func builder() -> Builder {
    return Builder()
  }

  /// Create a configuration with custom import paths.
  public static func withImportPaths(_ paths: [String]) -> Configuration {
    return builder()
      .addImportPath(contentsOf: paths)
      .build()
  }
}

// MARK: - Builder Extensions

extension Configuration.Builder {
  /// Add multiple import paths.
  @discardableResult
  public func addImportPath(contentsOf paths: [String]) -> Configuration.Builder {
    importPaths.append(contentsOf: paths)
    return self
  }
}
