#!/bin/bash

# Migration script for splitting Validator into components
# This script helps with the migration process by creating the necessary files and structure

# Create the Components directory if it doesn't exist
mkdir -p Sources/SwiftProtoParser/Core/Validator/Components

# Define the component files
COMPONENTS=(
  "Validator"
  "ValidationState"
  "ValidatorProtocols"
  "FileValidator"
  "MessageValidator"
  "EnumValidator"
  "FieldValidator"
  "ServiceValidator"
  "OptionValidator"
  "ReferenceValidator"
  "DependencyValidator"
  "SemanticValidator"
)

# Create empty Swift files for each component
for component in "${COMPONENTS[@]}"; do
  echo "Creating $component.swift..."
  touch "Sources/SwiftProtoParser/Core/Validator/Components/$component.swift"
  echo "import Foundation" > "Sources/SwiftProtoParser/Core/Validator/Components/$component.swift"
done

# Extract validation methods from the original file
echo "Extracting validation methods from Validation.swift..."

# File validation methods
grep -n "private func validate.*File\|validatePackageName\|validateImport\|validateSyntaxVersion" Sources/SwiftProtoParser/Core/Validator/Validation.swift > file_methods.txt

# Message validation methods
grep -n "private func validate.*Message\|validateNestedMessage\|validateReservedFields\|validateExtensionRules" Sources/SwiftProtoParser/Core/Validator/Validation.swift > message_methods.txt

# Enum validation methods
grep -n "private func validate.*Enum" Sources/SwiftProtoParser/Core/Validator/Validation.swift > enum_methods.txt

# Field validation methods
grep -n "private func validate.*Field\|validateOneof" Sources/SwiftProtoParser/Core/Validator/Validation.swift > field_methods.txt

# Service validation methods
grep -n "private func validate.*Service\|validateMethod\|validateRPC\|validateStreaming" Sources/SwiftProtoParser/Core/Validator/Validation.swift > service_methods.txt

# Option validation methods
grep -n "private func validate.*Option" Sources/SwiftProtoParser/Core/Validator/Validation.swift > option_methods.txt

# Reference validation methods
grep -n "private func validate.*Reference\|registerTypes\|validateTypeReference" Sources/SwiftProtoParser/Core/Validator/Validation.swift > reference_methods.txt

# Dependency validation methods
grep -n "private func build.*Dependency\|checkCyclicDependencies" Sources/SwiftProtoParser/Core/Validator/Validation.swift > dependency_methods.txt

# Semantic validation methods
grep -n "private func validate.*Semantic" Sources/SwiftProtoParser/Core/Validator/Validation.swift > semantic_methods.txt

echo "Migration preparation complete!"
echo "Next steps:"
echo "1. Review the extracted method lists in the *_methods.txt files"
echo "2. Implement each component based on the extracted methods"
echo "3. Update the main Validator class to use the components"
echo "4. Run tests to ensure functionality is preserved" 