# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.3.0] - 2025-03-07

### Added
- Full support for extensions in proto3 files
- Support for extending existing message types with new fields
- Validation of extension field numbers and types
- Descriptor generation for extensions
- Integration with Google Protobuf extensions
- Comprehensive test coverage for extensions

### Changed
- Updated documentation to include extensions support
- Enhanced validation to handle extended types correctly

## [0.2.0] - 2025-03-15

### Added
- Full support for custom options in proto3 files
- Custom options at all levels (file, message, field, enum, enum value, service, method)
- Support for nested fields in custom options using dot notation
- Validation of option values against their defined types
- Descriptor generation for custom options
- Comprehensive test coverage for all acceptance criteria from previous sprints

### Changed
- Updated documentation to include custom options support
- Enhanced symbol table to track option extensions
- Improved validation for option values

## [0.1.0] - 2024-03-02

### Added
- Initial project setup
- Lexical analysis for proto3 files
- Basic parsing for proto3 elements
- AST node types for proto3 elements
- Validation framework
- Descriptor generation
- Public API for parsing proto files
- Configuration options
- Error handling with detailed messages
- Documentation
- Integration tests comparing output with protoc
- Performance tests and optimizations
- Usage examples
- Troubleshooting guide

### Changed

### Deprecated

### Removed

### Fixed

### Security 