# Changelog

All notable changes to SwiftProtoParser will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive test suite for EnumNode
- Improved test coverage for Lexer component
- Coverage analysis infrastructure
- Detailed coverage tracking documentation

### Changed
- Enhanced error reporting with source location information
- Improved validation of enum definitions

### Fixed
- Fixed parsing of adjacent punctuation tokens
- Fixed handling of escape sequences in string literals

## [0.1.0] - 2023-12-15

### Added
- Initial release of SwiftProtoParser
- Support for proto3 syntax
- Lexical analysis of proto files
- Parsing of messages, enums, services, and options
- Validation of proto3 rules
- Generation of FileDescriptorProto objects
- Basic error reporting
- Swift Package Manager support 