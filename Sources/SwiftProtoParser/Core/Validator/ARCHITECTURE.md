# Validator Architecture

This document provides a detailed explanation of the component-based architecture for the SwiftProtoParser validator.

## Overview

The validator is responsible for ensuring that Protocol Buffer files adhere to the proto3 specification. The original implementation was a monolithic class with over 4,200 lines of code, making it difficult to maintain and extend.

The new architecture splits the validator into smaller, focused components, each responsible for a specific aspect of validation. This approach offers several benefits:

1. **Improved maintainability**: Each component is smaller and easier to understand
2. **Better separation of concerns**: Each component has a clear responsibility
3. **Enhanced testability**: Components can be tested in isolation
4. **Easier collaboration**: Multiple developers can work on different components simultaneously

## Core Components

### ValidationState

The `ValidationState` class manages the shared state used during validation, including:

- Current package being validated
- Defined types
- Scope stack for nested type resolution
- Imported types and definitions
- Dependencies between types

This state is shared among all validator components, allowing them to access and modify the state as needed.

### ValidatorV2

The `ValidatorV2` class is the main entry point for validation. It:

1. Coordinates the validation process
2. Delegates specific validation tasks to specialized components
3. Maintains the same public API as the original validator

### Component Protocols

Each validation concern is defined by a protocol that specifies the methods that must be implemented:

- `FileValidating`: File-level validation
- `MessageValidating`: Message-level validation
- `EnumValidating`: Enum-level validation
- `FieldValidating`: Field-level validation
- `ServiceValidating`: Service and RPC validation
- `OptionValidating`: Option validation
- `ReferenceValidating`: Type reference validation
- `DependencyValidating`: Dependency graph validation
- `SemanticValidating`: Semantic rule validation

### Component Implementations

Each protocol has a corresponding implementation class:

- `FileValidator`: Validates file syntax, package names, and imports
- `MessageValidator`: Validates message structure, fields, and nested types
- `EnumValidator`: Validates enum values and semantics
- `FieldValidator`: Validates field numbers, names, and types
- `ServiceValidator`: Validates services, methods, and RPCs
- `OptionValidator`: Validates options for various elements
- `ReferenceValidator`: Validates type references and handles registration
- `DependencyValidator`: Builds and validates the dependency graph
- `SemanticValidator`: Validates semantic rules across the file

## Validation Process

The validation process follows these steps:

1. **Reset state**: Clear any previous validation state
2. **Basic validation**: Validate syntax version and file options
3. **Register types**: Register all types to allow for forward references
4. **Validate enums**: Validate enum semantics and values
5. **Validate messages**: Validate message structure and fields
6. **Validate services**: Validate service definitions and methods
7. **Final validations**: Check for cyclic dependencies and cross-references

## Compatibility Layer

To facilitate a gradual migration from the original implementation to the new component-based architecture, a compatibility layer is provided:

- `ValidatorProtocol`: Common interface for both implementations
- `ValidatorFactory`: Factory for creating validator instances
- `ValidatorImplementation`: Enum for selecting the implementation

This allows clients to switch between implementations without changing their code.

## Design Decisions

### Why Composition Over Inheritance?

The architecture uses composition (combining smaller objects) rather than inheritance (extending a base class) for several reasons:

1. **Flexibility**: Components can be replaced or modified independently
2. **Testability**: Components can be tested in isolation with mock dependencies
3. **Clarity**: Each component has a clear, focused responsibility

### Why Shared State?

While shared state can be problematic, it's appropriate in this case because:

1. The validation process is inherently stateful
2. The state is encapsulated in a dedicated class
3. The state is only shared among validator components
4. The state is reset between validations

### Why a Compatibility Layer?

The compatibility layer allows for a gradual migration by:

1. Providing a common interface for both implementations
2. Allowing clients to switch between implementations
3. Facilitating A/B testing and performance comparisons

## Future Improvements

Potential future improvements include:

1. **Parallel validation**: Validate independent aspects in parallel
2. **Incremental validation**: Only validate changed parts of a file
3. **Custom validation rules**: Allow clients to add custom validation rules
4. **Performance optimizations**: Optimize specific validation steps 