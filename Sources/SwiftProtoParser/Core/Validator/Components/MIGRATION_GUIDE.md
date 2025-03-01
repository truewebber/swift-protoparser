# Migration Guide: Splitting Validator into Components

This guide outlines the process for migrating from the monolithic `Validation.swift` file to a component-based structure.

## Overview

The original `Validation.swift` file (4,200+ lines) has been split into smaller, more manageable files based on logical grouping of functionality. This approach offers several benefits:

1. **Improved maintainability**: Smaller files are easier to understand and modify
2. **Better organization**: Related functionality is grouped together
3. **Enhanced testability**: Components can be tested in isolation
4. **Clearer responsibilities**: Each component has a well-defined purpose

## Migration Steps

### Step 1: Create the Component Structure

1. Create a `Components` directory under `Sources/SwiftProtoParser/Core/Validator/`
2. Create the following files:
   - `Validator.swift` - Main validator class
   - `ValidationState.swift` - Shared state management
   - `ValidatorProtocols.swift` - Protocol definitions
   - Component implementations (e.g., `FileValidator.swift`, `MessageValidator.swift`, etc.)

### Step 2: Extract State Management

1. Move all state variables from the original `Validator` class to the `ValidationState` class
2. Ensure the state is properly shared among all components

### Step 3: Define Component Protocols

1. Create protocol definitions for each validation concern
2. Ensure each protocol has a clear responsibility
3. Define method signatures that match the original implementation

### Step 4: Implement Components

For each component:
1. Create a class that implements the corresponding protocol
2. Copy the relevant methods from the original `Validator` class
3. Update method signatures to match the protocol
4. Ensure the component has access to the shared state

### Step 5: Update the Main Validator Class

1. Update the `Validator` class to use composition instead of containing all the methods
2. Initialize all components in the constructor
3. Delegate validation tasks to the appropriate components

### Step 6: Testing

1. Run all existing tests to ensure functionality is preserved
2. Add new tests for each component if needed

## Code Organization

The new structure organizes code as follows:

```
Sources/SwiftProtoParser/Core/Validator/
├── Validation.swift (original file, to be deprecated)
├── Errors.swift (unchanged)
└── Components/
    ├── Validator.swift (new main class)
    ├── ValidationState.swift (shared state)
    ├── ValidatorProtocols.swift (protocol definitions)
    ├── FileValidator.swift
    ├── MessageValidator.swift
    ├── EnumValidator.swift
    ├── FieldValidator.swift
    ├── ServiceValidator.swift
    ├── OptionValidator.swift
    ├── ReferenceValidator.swift
    ├── DependencyValidator.swift
    └── SemanticValidator.swift
```

## Transition Strategy

To minimize disruption, follow this transition strategy:

1. Implement the new component-based structure alongside the existing code
2. Create a new `ValidatorV2` class that uses the component-based approach
3. Add tests for the new implementation
4. Once tests pass, gradually migrate clients to use the new implementation
5. Eventually, deprecate and remove the original implementation

## Example Usage

```swift
// Before
let validator = Validator()
try validator.validate(fileNode)

// After
let validator = Validator() // Uses components internally
try validator.validate(fileNode) // Same API, different implementation
``` 