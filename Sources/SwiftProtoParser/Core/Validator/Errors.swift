public enum ValidationError: Error, CustomStringConvertible {
  case firstEnumValueNotZero(String)  // enum name
  case duplicateEnumValue(String, value: Int)  // value name, number
  case emptyEnum(String)  // enum name
  case invalidPackageName(String)  // package name
  case invalidImport(String)  // error message
  case invalidOptionValue(String)  // error message
  case unknownOption(String)  // option name
  case duplicateMethodName(String)  // method name
  case invalidSyntaxVersion(String)  // syntax version
  case circularImport(String)  // import path
  case duplicateNestedTypeName(String)  // type name
  case duplicateFieldName(String, inType: String)  // field name, containing type
  case invalidFieldNumber(Int, location: SourceLocation)  // number, location
  case reservedFieldName(String)  // field name
  case undefinedType(String, referencedIn: String)  // type name, containing type
  case invalidMapKeyType(String)  // key type
  case invalidMapValueType(String)  // key type
  case repeatedMapField(String)  // field name
  case optionalMapField(String)  // field name
  case emptyOneof(String)  // oneof name
  case repeatedOneof(String)  // oneof name
  case optionalOneof(String)  // oneof name
  case invalidOptionName(String)  // option name
  case duplicateTypeName(String)  // type name
  case invalidFieldName(String)
  case cyclicDependency([String])
  case duplicateMessageFieldNumber(Int, messageName: String)
  case duplicateOption(String)
  case invalidMessageName(String)
  case invalidEnumName(String)
  case invalidEnumValueName(String)
  case invalidServiceName(String)
  case invalidMethodName(String)
  case unpackableFieldType(String, TypeNode.ScalarType)
  case custom(String)

  public var description: String {
    switch self {
    case .firstEnumValueNotZero(let name):
      return "First enum value in '\(name)' must be zero in proto3"
    case .duplicateEnumValue(let name, let value):
      return "Duplicate enum value \(value) in enum value '\(name)'"
    case .emptyEnum(let name):
      return "Enum '\(name)' must have at least one value"
    case .invalidPackageName(let name):
      return "Invalid package name: '\(name)'"
    case .invalidImport(let message):
      return "Invalid import: \(message)"
    case .invalidOptionValue(let message):
      return "Invalid option value: \(message)"
    case .unknownOption(let name):
      return "Unknown option: '\(name)'"
    case .duplicateMethodName(let name):
      return "Duplicate method name: '\(name)'"
    case .invalidSyntaxVersion(let version):
      return "Invalid syntax version: '\(version)', expected 'proto3'"
    case .circularImport(let path):
      return "Circular import detected: '\(path)'"
    case .duplicateNestedTypeName(let name):
      return "Duplicate nested type name: '\(name)'"
    case .duplicateFieldName(let field, let type):
      return "Duplicate field name '\(field)' in type '\(type)'"
    case .invalidFieldNumber(let number, let location):
      return "Invalid field number \(number) at \(location.line):\(location.column)"
    case .reservedFieldName(let name):
      return "Field name '\(name)' is reserved"
    case .undefinedType(let type, let container):
      return "Undefined type '\(type)' referenced in '\(container)'"
    case .invalidMapKeyType(let type):
      return "Invalid map key type: '\(type)'"
    case .invalidMapValueType(let value):
      return "Invalid map value type: '\(value)'"
    case .repeatedMapField(let name):
      return "Map field '\(name)' cannot be repeated"
    case .optionalMapField(let name):
      return "Map field '\(name)' cannot be optional"
    case .emptyOneof(let name):
      return "Oneof '\(name)' must have at least one field"
    case .repeatedOneof(let name):
      return "Oneof field '\(name)' cannot be repeated"
    case .optionalOneof(let name):
      return "Oneof '\(name)' must have at least one field"
    case .invalidOptionName(let name):
      return "Invalid option name: '\(name)'"
    case .invalidFieldName(let name):
      return "Invalid field name \(name)"
    case .cyclicDependency(let path):
      return "Cyclic dependency detected: \(path.joined(separator: " -> "))"
    case .duplicateTypeName(let name):
      return "Duplicate type name: '\(name)'"
    case .duplicateMessageFieldNumber(let number, let messageName):
      return "Duplicate message filed number: '\(number)' in message '\(messageName)'"
    case .duplicateOption(let opttionName):
      return "Duplicate option: '\(opttionName)'"
    case .invalidMessageName(let messageName):
      return "Invalid message name: '\(messageName)'"
    case .invalidEnumName(let enumName):
      return "Invalid enum name: '\(enumName)'"
    case .invalidEnumValueName(let enumValueName):
      return "Invalid enum value name: '\(enumValueName)'"
    case .invalidServiceName(let serviceName):
      return "Invalid service name: '\(serviceName)'"
    case .invalidMethodName(let methodName):
      return "Invalid method name: '\(methodName)'"
    case .unpackableFieldType(let fieldName, let scalarType):
      return "Field '\(fieldName)' of type '\(scalarType)' cannot be packed"
    case .custom(let message):
      return message
    }
  }
}
