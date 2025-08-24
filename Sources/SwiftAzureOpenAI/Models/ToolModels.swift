//
//  ToolModels.swift
//  SwiftAzureOpenAI
//
//  Created by Reiley Meeks on 26/07/2025.
//

import Foundation

// MARK: - Tool Definition Models

/// A tool that can be called by the model
public struct Tool: Codable, Sendable {
    public let type: ToolType
    public let function: FunctionDefinition
    
    public init(type: ToolType = .function, function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// Type of tool (currently only function is supported)
public enum ToolType: String, Codable, Sendable {
    case function
}

/// Definition of a function that can be called
public struct FunctionDefinition: Codable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: FunctionParameters?
    
    public init(name: String, description: String? = nil, parameters: FunctionParameters? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Parameters for a function using JSON Schema
public struct FunctionParameters: Codable, Sendable {
    private let schemaData: Data
    
    /// Internal use only: Decoded schema dictionary for testing/debug purposes
    public var schema: [String: Any] {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: schemaData)
            if let dict = jsonObject as? [String: Any] {
                return dict
            }
        } catch {
            // ignore decoding errors here; fallback to empty dictionary
        }
        return [:]
    }
    
    public init(type: String = "object", properties: [String: Any]? = nil, required: [String]? = nil) {
        var schema: [String: Any] = ["type": type]
        if let properties = properties {
            schema["properties"] = properties
        }
        if let required = required {
            schema["required"] = required
        }
        do {
            self.schemaData = try JSONSerialization.data(withJSONObject: schema, options: [])
        } catch {
            // If serialization fails, store empty JSON object
            self.schemaData = Data("{}".utf8)
        }
    }
    
    public init(schema: [String: Any]) {
        do {
            self.schemaData = try JSONSerialization.data(withJSONObject: schema, options: [])
        } catch {
            self.schemaData = Data("{}".utf8)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let jsonObject = try JSONSerialization.jsonObject(with: schemaData)
        try container.encode(AnyEncodable(jsonObject))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let anyDecodable = try container.decode(AnyDecodable.self)
        guard let dict = anyDecodable.value as? [String: Any] else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected dictionary for parameters")
        }
        do {
            self.schemaData = try JSONSerialization.data(withJSONObject: dict, options: [])
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Failed to serialize parameters dictionary to Data")
        }
    }
}

/// How the model should use the provided tools
public enum ToolChoice: Codable, Sendable {
    case none
    case auto
    case required
    case function(name: String)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encode("none")
        case .auto:
            try container.encode("auto")
        case .required:
            try container.encode("required")
        case .function(let name):
            let functionChoice: [String: Any] = [
                "type": "function",
                "function": ["name": name]
            ]
            try container.encode(AnyEncodable(functionChoice))
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            switch string {
            case "none": self = .none
            case "auto": self = .auto
            case "required": self = .required
            default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice string")
            }
        } else if let anyDecodable = try? container.decode(AnyDecodable.self),
                  let dict = anyDecodable.value as? [String: Any],
                  let type = dict["type"] as? String,
                  type == "function",
                  let function = dict["function"] as? [String: Any],
                  let name = function["name"] as? String {
            self = .function(name: name)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice")
        }
    }
}

// MARK: - Tool Call Models

/// A tool call made by the model
public struct ToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: FunctionCall
    
    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// A function call made by the model
public struct FunctionCall: Codable, Sendable {
    public let name: String
    public let arguments: String
    
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Helper Types

/// Type-erased encodable wrapper for JSON Schema
private struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyEncodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyEncodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode value"))
        }
    }
}

/// Type-erased decodable wrapper
private struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}
