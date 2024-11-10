import Foundation

extension String {
    /// Checks if the string is a valid identifier.
    func isIdentifier() -> Bool {
        guard let firstChar = self.first, firstChar.isLetter || firstChar == "_" else {
            return false
        }
        return self.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    /// Checks if the string represents a numeric literal.
    func isNumeric() -> Bool {
        return Double(self) != nil
    }
}

extension Array {
    /// Safely peeks at an element in the array.
    func peek(_ index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
