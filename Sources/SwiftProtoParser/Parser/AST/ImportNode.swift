/// Modifier for an import statement.
enum ImportModifier: Equatable, Hashable, Sendable {
  /// Regular import with no modifier.
  case none
  /// `import public` — re-exports the imported file to dependents.
  case `public`
  /// `import weak` — import is allowed to be missing at link time.
  case weak
}

/// AST node representing a single import statement.
struct ImportNode: Equatable, Hashable, Sendable {
  /// The import path string (e.g. `"google/protobuf/timestamp.proto"`).
  let path: String

  /// The import modifier (`none`, `public`, or `weak`).
  let modifier: ImportModifier

  init(path: String, modifier: ImportModifier = .none) {
    self.path = path
    self.modifier = modifier
  }
}

// MARK: - CustomStringConvertible

extension ImportNode: CustomStringConvertible {
  var description: String {
    switch modifier {
    case .none:
      return "import \"\(path)\";"
    case .public:
      return "import public \"\(path)\";"
    case .weak:
      return "import weak \"\(path)\";"
    }
  }
}
