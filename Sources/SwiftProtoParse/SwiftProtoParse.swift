import Foundation
import SwiftProtobuf

public class SwiftProtoParse {
	public static func parse(protoContent: String) throws -> Google_Protobuf_FileDescriptorProto {
		let lexer = Lexer(source: protoContent)
		let tokens = try lexer.tokenize()
		let parser = Parser(tokens: tokens)
		let descriptor = try parser.parse()
		return descriptor
	}

	public static func parseFile(at url: URL) throws -> Google_Protobuf_FileDescriptorProto {
		let content = try String(contentsOf: url)
		return try parse(protoContent: content)
	}
}
