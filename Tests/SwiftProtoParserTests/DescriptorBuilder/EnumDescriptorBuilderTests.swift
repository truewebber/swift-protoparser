import XCTest
import SwiftProtobuf
@testable import SwiftProtoParser

final class EnumDescriptorBuilderTests: XCTestCase {
  
  // MARK: - Basic Enum Building Tests
  
  func testBuildBasicEnum() throws {
    // Given: Simple enum with basic values
    let enumNode = EnumNode(
      name: "Status",
      values: [
        EnumValueNode(name: "UNKNOWN", number: 0),
        EnumValueNode(name: "SUCCESS", number: 1),
        EnumValueNode(name: "FAILURE", number: 2)
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Basic properties are set correctly
    XCTAssertEqual(enumProto.name, "Status")
    XCTAssertEqual(enumProto.value.count, 3)
    
    // Verify values
    XCTAssertEqual(enumProto.value[0].name, "UNKNOWN")
    XCTAssertEqual(enumProto.value[0].number, 0)
    XCTAssertEqual(enumProto.value[1].name, "SUCCESS") 
    XCTAssertEqual(enumProto.value[1].number, 1)
    XCTAssertEqual(enumProto.value[2].name, "FAILURE")
    XCTAssertEqual(enumProto.value[2].number, 2)
  }
  
  func testBuildEmptyEnum() throws {
    // Given: Empty enum (should fail validation)
    let enumNode = EnumNode(name: "Empty", values: [])
    
    // When/Then: Should throw error for missing zero value
    XCTAssertThrowsError(try EnumDescriptorBuilder.build(from: enumNode)) { error in
      guard case DescriptorError.conversionFailed(let message) = error else {
        XCTFail("Expected conversionFailed error")
        return
      }
      XCTAssertTrue(message.contains("must have a zero value"))
    }
  }
  
  func testBuildEnumWithoutZeroValue() throws {
    // Given: Enum without zero value (invalid in proto3)
    let enumNode = EnumNode(
      name: "InvalidEnum",
      values: [
        EnumValueNode(name: "FIRST", number: 1),
        EnumValueNode(name: "SECOND", number: 2)
      ]
    )
    
    // When/Then: Should throw error
    XCTAssertThrowsError(try EnumDescriptorBuilder.build(from: enumNode)) { error in
      guard case DescriptorError.conversionFailed(let message) = error else {
        XCTFail("Expected conversionFailed error")
        return
      }
      XCTAssertTrue(message.contains("must have a zero value"))
      XCTAssertTrue(message.contains("InvalidEnum"))
    }
  }
  
  // MARK: - Enum Options Tests
  
  func testBuildEnumWithBasicOptions() throws {
    // Given: Enum with basic options
    let enumNode = EnumNode(
      name: "DeprecatedEnum",
      values: [
        EnumValueNode(name: "DEFAULT", number: 0)
      ],
      options: [
        OptionNode(name: "deprecated", value: .boolean(true)),
        OptionNode(name: "allow_alias", value: .boolean(true))
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Options are set correctly
    XCTAssertTrue(enumProto.hasOptions)
    XCTAssertTrue(enumProto.options.deprecated)
    XCTAssertTrue(enumProto.options.allowAlias)
  }
  
  func testBuildEnumWithCustomOptions() throws {
    // Given: Enum with custom options
    let enumNode = EnumNode(
      name: "CustomEnum", 
      values: [
        EnumValueNode(name: "ZERO", number: 0)
      ],
      options: [
        OptionNode(name: "deprecated", value: .boolean(false)),
        OptionNode(name: "custom_option", value: .string("custom_value"))
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Standard options are processed, custom options are ignored
    XCTAssertTrue(enumProto.hasOptions)
    XCTAssertFalse(enumProto.options.deprecated)
    XCTAssertFalse(enumProto.options.allowAlias) // default value
  }
  
  // MARK: - Enum Value Options Tests
  
  func testBuildEnumWithValueOptions() throws {
    // Given: Enum with value-specific options
    let enumNode = EnumNode(
      name: "StatusWithOptions",
      values: [
        EnumValueNode(name: "UNKNOWN", number: 0),
        EnumValueNode(
          name: "DEPRECATED_SUCCESS",
          number: 1,
          options: [OptionNode(name: "deprecated", value: .boolean(true))]
        ),
        EnumValueNode(
          name: "ACTIVE",
          number: 2,
          options: [OptionNode(name: "deprecated", value: .boolean(false))]
        )
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Value options are set correctly
    XCTAssertEqual(enumProto.value.count, 3)
    
    // First value has no options
    XCTAssertFalse(enumProto.value[0].hasOptions)
    
    // Second value is deprecated
    XCTAssertTrue(enumProto.value[1].hasOptions)
    XCTAssertTrue(enumProto.value[1].options.deprecated)
    
    // Third value is not deprecated
    XCTAssertTrue(enumProto.value[2].hasOptions)
    XCTAssertFalse(enumProto.value[2].options.deprecated)
  }
  
  func testBuildEnumValueWithCustomOptions() throws {
    // Given: Enum value with custom options
    let enumNode = EnumNode(
      name: "CustomValueEnum",
      values: [
        EnumValueNode(name: "ZERO", number: 0),
        EnumValueNode(
          name: "CUSTOM_VALUE",
          number: 1,
          options: [
            OptionNode(name: "deprecated", value: .boolean(true)),
            OptionNode(name: "custom_value_option", value: .number(42))
          ]
        )
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Standard options processed, custom ignored
    XCTAssertEqual(enumProto.value.count, 2)
    XCTAssertTrue(enumProto.value[1].hasOptions)
    XCTAssertTrue(enumProto.value[1].options.deprecated)
  }
  
  // MARK: - Complex Scenarios Tests
  
  func testBuildComplexEnum() throws {
    // Given: Complex enum with multiple features
    let enumNode = EnumNode(
      name: "ComplexStatus",
      values: [
        EnumValueNode(name: "UNSPECIFIED", number: 0),
        EnumValueNode(
          name: "PENDING",
          number: 1,
          options: [OptionNode(name: "deprecated", value: .boolean(false))]
        ),
        EnumValueNode(
          name: "RUNNING", 
          number: 2
        ),
        EnumValueNode(
          name: "COMPLETED",
          number: 3,
          options: [OptionNode(name: "deprecated", value: .boolean(true))]
        ),
        EnumValueNode(name: "FAILED", number: 4)
      ],
      options: [
        OptionNode(name: "allow_alias", value: .boolean(false)),
        OptionNode(name: "deprecated", value: .boolean(false))
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: All features work together
    XCTAssertEqual(enumProto.name, "ComplexStatus")
    XCTAssertEqual(enumProto.value.count, 5)
    
    // Check enum options
    XCTAssertTrue(enumProto.hasOptions)
    XCTAssertFalse(enumProto.options.allowAlias)
    XCTAssertFalse(enumProto.options.deprecated)
    
    // Check value options
    XCTAssertFalse(enumProto.value[0].hasOptions) // UNSPECIFIED
    XCTAssertTrue(enumProto.value[1].hasOptions)  // PENDING
    XCTAssertFalse(enumProto.value[1].options.deprecated)
    XCTAssertFalse(enumProto.value[2].hasOptions) // RUNNING
    XCTAssertTrue(enumProto.value[3].hasOptions)  // COMPLETED
    XCTAssertTrue(enumProto.value[3].options.deprecated)
    XCTAssertFalse(enumProto.value[4].hasOptions) // FAILED
  }
  
  func testBuildEnumWithNegativeValues() throws {
    // Given: Enum with negative values (valid in proto3)
    let enumNode = EnumNode(
      name: "SignedEnum",
      values: [
        EnumValueNode(name: "ZERO", number: 0),
        EnumValueNode(name: "NEGATIVE", number: -1),
        EnumValueNode(name: "POSITIVE", number: 1)
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Negative values are handled correctly
    XCTAssertEqual(enumProto.value.count, 3)
    XCTAssertEqual(enumProto.value[0].number, 0)
    XCTAssertEqual(enumProto.value[1].number, -1)
    XCTAssertEqual(enumProto.value[2].number, 1)
  }
  
  // MARK: - Edge Cases Tests
  
  func testBuildEnumWithLargeNumbers() throws {
    // Given: Enum with large numbers
    let enumNode = EnumNode(
      name: "LargeNumberEnum",
      values: [
        EnumValueNode(name: "ZERO", number: 0),
        EnumValueNode(name: "MAX_VALUE", number: Int32.max),
        EnumValueNode(name: "MIN_VALUE", number: Int32.min)
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Large numbers are handled correctly
    XCTAssertEqual(enumProto.value.count, 3)
    XCTAssertEqual(enumProto.value[0].number, 0)
    XCTAssertEqual(enumProto.value[1].number, Int32.max)
    XCTAssertEqual(enumProto.value[2].number, Int32.min)
  }
  
  func testBuildEnumWithSpecialCharactersInName() throws {
    // Given: Enum with special characters in names
    let enumNode = EnumNode(
      name: "Special_Enum",
      values: [
        EnumValueNode(name: "VALUE_0", number: 0),
        EnumValueNode(name: "VALUE_WITH_UNDERSCORES", number: 1),
        EnumValueNode(name: "VALUE123", number: 2)
      ]
    )
    
    // When: Building descriptor
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Special characters are preserved
    XCTAssertEqual(enumProto.name, "Special_Enum")
    XCTAssertEqual(enumProto.value[0].name, "VALUE_0")
    XCTAssertEqual(enumProto.value[1].name, "VALUE_WITH_UNDERSCORES")
    XCTAssertEqual(enumProto.value[2].name, "VALUE123")
  }
  
  // MARK: - Error Handling Tests
  
  func testBuildEnumWithInvalidOptionValue() throws {
    // Given: Enum with invalid option value type
    let enumNode = EnumNode(
      name: "InvalidOptionEnum",
      values: [
        EnumValueNode(name: "ZERO", number: 0)
      ],
      options: [
        OptionNode(name: "deprecated", value: .string("not_boolean")),
        OptionNode(name: "allow_alias", value: .number(42))
      ]
    )
    
    // When: Building descriptor (should not throw, just ignore invalid options)
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Invalid options are ignored, defaults used
    XCTAssertTrue(enumProto.hasOptions)
    XCTAssertFalse(enumProto.options.deprecated) // default value
    XCTAssertFalse(enumProto.options.allowAlias) // default value
  }
  
  func testBuildEnumValueWithInvalidOptionValue() throws {
    // Given: Enum value with invalid option value type
    let enumNode = EnumNode(
      name: "InvalidValueOptionEnum",
      values: [
        EnumValueNode(name: "ZERO", number: 0),
        EnumValueNode(
          name: "INVALID_OPTION",
          number: 1,
          options: [OptionNode(name: "deprecated", value: .number(123))]
        )
      ]
    )
    
    // When: Building descriptor (should not throw)
    let enumProto = try EnumDescriptorBuilder.build(from: enumNode)
    
    // Then: Invalid option is ignored
    XCTAssertEqual(enumProto.value.count, 2)
    XCTAssertTrue(enumProto.value[1].hasOptions)
    XCTAssertFalse(enumProto.value[1].options.deprecated) // default value
  }
}
