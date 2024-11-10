import Foundation

/// Handles the collection and reporting of errors.
public class ErrorReporter {
    private(set) public var errors: [ParseError] = []
    
    public init() {}
    
    public func report(error: ParseError) {
        errors.append(error)
        print("Error at line \(error.line), column \(error.column): \(error.message)")
    }
    
    public var hasErrors: Bool {
        return !errors.isEmpty
    }
}
