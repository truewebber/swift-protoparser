import Foundation

extension Character {
	var isWhitespace: Bool {
		return self == " " || self == "\t" || self == "\n" || self == "\r"
	}
}
