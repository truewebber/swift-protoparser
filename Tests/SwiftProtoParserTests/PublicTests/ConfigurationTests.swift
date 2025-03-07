import XCTest
@testable import SwiftProtoParser

final class ConfigurationTests: XCTestCase {
    
    // MARK: - Default Configuration Tests
    
    func testDefaultConfiguration() {
        // Act
        let config = Configuration()
        
        // Assert
        XCTAssertTrue(config.importPaths.isEmpty, "Default import paths should be empty")
        XCTAssertTrue(config.generateSourceInfo, "Source info generation should be enabled by default")
        XCTAssertTrue(config.allowAliases, "Aliases should be allowed by default")
        XCTAssertTrue(config.allowServices, "Services should be allowed by default")
        XCTAssertTrue(config.validateDefaults, "Default validation should be enabled by default")
        XCTAssertFalse(config.allowExtensions, "Extensions should not be allowed by default")
        XCTAssertEqual(config.maxRecursionDepth, 100, "Default max recursion depth should be 100")
        XCTAssertFalse(config.preserveUnknownFields, "Unknown fields should not be preserved by default")
    }
    
    func testDefaultNamingOptions() {
        // Act
        let config = Configuration()
        
        // Assert
        XCTAssertTrue(config.namingOptions.enforceConventions, "Naming conventions should be enforced by default")
        XCTAssertTrue(config.namingOptions.allowUnderscoresInTypes, "Underscores in types should be allowed by default")
        XCTAssertTrue(config.namingOptions.allowUnderscoresInFields, "Underscores in fields should be allowed by default")
    }
    
    // MARK: - Builder Tests
    
    func testBuilderWithImportPaths() {
        // Act
        let config = Configuration.builder()
            .addImportPath("path/to/imports")
            .addImportPath("another/path")
            .build()
        
        // Assert
        XCTAssertEqual(config.importPaths.count, 2, "Should have 2 import paths")
        XCTAssertEqual(config.importPaths[0], "path/to/imports", "First import path should match")
        XCTAssertEqual(config.importPaths[1], "another/path", "Second import path should match")
    }
    
    func testBuilderWithMultipleImportPaths() {
        // Act
        let config = Configuration.builder()
            .addImportPath(contentsOf: ["path1", "path2", "path3"])
            .build()
        
        // Assert
        XCTAssertEqual(config.importPaths.count, 3, "Should have 3 import paths")
        XCTAssertEqual(config.importPaths, ["path1", "path2", "path3"], "Import paths should match")
    }
    
    func testBuilderWithSourceInfo() {
        // Act
        let configEnabled = Configuration.builder()
            .withSourceInfo(true)
            .build()
        
        let configDisabled = Configuration.builder()
            .withSourceInfo(false)
            .build()
        
        // Assert
        XCTAssertTrue(configEnabled.generateSourceInfo, "Source info should be enabled")
        XCTAssertFalse(configDisabled.generateSourceInfo, "Source info should be disabled")
    }
    
    func testBuilderWithAliases() {
        // Act
        let configEnabled = Configuration.builder()
            .withAliases(true)
            .build()
        
        let configDisabled = Configuration.builder()
            .withAliases(false)
            .build()
        
        // Assert
        XCTAssertTrue(configEnabled.allowAliases, "Aliases should be enabled")
        XCTAssertFalse(configDisabled.allowAliases, "Aliases should be disabled")
    }
    
    func testBuilderWithServices() {
        // Act
        let configEnabled = Configuration.builder()
            .withServices(true)
            .build()
        
        let configDisabled = Configuration.builder()
            .withServices(false)
            .build()
        
        // Assert
        XCTAssertTrue(configEnabled.allowServices, "Services should be enabled")
        XCTAssertFalse(configDisabled.allowServices, "Services should be disabled")
    }
    
    func testBuilderWithDefaultValidation() {
        // Act
        let configEnabled = Configuration.builder()
            .withDefaultValidation(true)
            .build()
        
        let configDisabled = Configuration.builder()
            .withDefaultValidation(false)
            .build()
        
        // Assert
        XCTAssertTrue(configEnabled.validateDefaults, "Default validation should be enabled")
        XCTAssertFalse(configDisabled.validateDefaults, "Default validation should be disabled")
    }
    
    func testBuilderWithExtensions() {
        // Act
        let configEnabled = Configuration.builder()
            .withExtensions(true)
            .build()
        
        let configDisabled = Configuration.builder()
            .withExtensions(false)
            .build()
        
        // Assert
        XCTAssertTrue(configEnabled.allowExtensions, "Extensions should be enabled")
        XCTAssertFalse(configDisabled.allowExtensions, "Extensions should be disabled")
    }
    
    func testBuilderWithMaxRecursionDepth() {
        // Act
        let config = Configuration.builder()
            .withMaxRecursionDepth(50)
            .build()
        
        // Assert
        XCTAssertEqual(config.maxRecursionDepth, 50, "Max recursion depth should be 50")
    }
    
    func testBuilderWithNamingOptions() {
        // Act
        let namingOptions = Configuration.NamingOptions(
            enforceConventions: false,
            allowUnderscoresInTypes: false,
            allowUnderscoresInFields: false
        )
        
        let config = Configuration.builder()
            .withNamingOptions(namingOptions)
            .build()
        
        // Assert
        XCTAssertFalse(config.namingOptions.enforceConventions, "Naming conventions should not be enforced")
        XCTAssertFalse(config.namingOptions.allowUnderscoresInTypes, "Underscores in types should not be allowed")
        XCTAssertFalse(config.namingOptions.allowUnderscoresInFields, "Underscores in fields should not be allowed")
    }
    
    func testBuilderChaining() {
        // Act
        let namingOptions = Configuration.NamingOptions(
            enforceConventions: false,
            allowUnderscoresInTypes: false,
            allowUnderscoresInFields: false
        )
        
        let config = Configuration.builder()
            .addImportPath("path/to/imports")
            .withSourceInfo(false)
            .withAliases(false)
            .withServices(false)
            .withDefaultValidation(false)
            .withExtensions(false)
            .withMaxRecursionDepth(20)
            .withNamingOptions(namingOptions)
            .build()
        
        // Assert
        XCTAssertEqual(config.importPaths, ["path/to/imports"], "Import path should match")
        XCTAssertFalse(config.generateSourceInfo, "Source info should be disabled")
        XCTAssertFalse(config.allowAliases, "Aliases should be disabled")
        XCTAssertFalse(config.allowServices, "Services should be disabled")
        XCTAssertFalse(config.validateDefaults, "Default validation should be disabled")
        XCTAssertFalse(config.allowExtensions, "Extensions should be disabled")
        XCTAssertEqual(config.maxRecursionDepth, 20, "Max recursion depth should be 20")
        XCTAssertFalse(config.namingOptions.enforceConventions, "Naming conventions should not be enforced")
        XCTAssertFalse(config.namingOptions.allowUnderscoresInTypes, "Underscores in types should not be allowed")
        XCTAssertFalse(config.namingOptions.allowUnderscoresInFields, "Underscores in fields should not be allowed")
    }
    
    // MARK: - Convenience Methods Tests
    
    func testWithImportPathsConvenience() {
        // Act
        let config = Configuration.withImportPaths(["path1", "path2"])
        
        // Assert
        XCTAssertEqual(config.importPaths, ["path1", "path2"], "Import paths should match")
    }
} 