import Foundation

public class ServiceDescriptor {
    public var name: String
    public var methods: [MethodDescriptor] = []

    public init(name: String) {
        self.name = name
    }
}

public class MethodDescriptor {
    public var name: String
    public var inputType: String
    public var outputType: String
    public var clientStreaming: Bool = false
    public var serverStreaming: Bool = false

    public init(
        name: String,
        inputType: String,
        outputType: String,
        clientStreaming: Bool = false,
        serverStreaming: Bool = false
    ) {
        self.name = name
        self.inputType = inputType
        self.outputType = outputType
        self.clientStreaming = clientStreaming
        self.serverStreaming = serverStreaming
    }
}
