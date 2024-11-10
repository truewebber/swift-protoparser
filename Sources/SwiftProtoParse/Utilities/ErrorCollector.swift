import Foundation

public protocol ErrorCollector {
	func addError(line: Int, column: Int, message: String)
}

public class SimpleErrorCollector: ErrorCollector {
	public private(set) var errors: [String] = []

	public init() {}

	public func addError(line: Int, column: Int, message: String) {
		let errorMessage = "Error at \(line):\(column): \(message)"
		errors.append(errorMessage)
	}
}
