//
//  EmbeddingModels.swift
//  SwiftAzureOpenAI
//
//  Created by Reiley Meeks on 26/07/2025.
//

import Foundation

// MARK: - Embedding Request Models

/// Request for creating embeddings
public struct EmbeddingRequest: Codable, Sendable {
    public let input: EmbeddingInput
    public let user: String?
    public let encodingFormat: EncodingFormat?
    public let dimensions: Int?
    
    public init(
        input: EmbeddingInput,
        user: String? = nil,
        encodingFormat: EncodingFormat? = nil,
        dimensions: Int? = nil
    ) {
        self.input = input
        self.user = user
        self.encodingFormat = encodingFormat
        self.dimensions = dimensions
    }
}

/// Input for embeddings (supports various formats)
public enum EmbeddingInput: Codable, Sendable {
    case string(String)
    case array([String])
    case integerArray([Int])
    case nestedIntegerArray([[Int]])
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .integerArray(let values):
            try container.encode(values)
        case .nestedIntegerArray(let values):
            try container.encode(values)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([String].self) {
            self = .array(array)
        } else if let intArray = try? container.decode([Int].self) {
            self = .integerArray(intArray)
        } else if let nestedIntArray = try? container.decode([[Int]].self) {
            self = .nestedIntegerArray(nestedIntArray)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid input type")
        }
    }
}

/// Format for encoding embeddings
public enum EncodingFormat: String, Codable, Sendable {
    case float = "float"
    case base64 = "base64"
}

// MARK: - Embedding Response Models

/// Response containing embeddings
public struct EmbeddingResponse: Codable, Sendable {
    public let object: String
    public let data: [EmbeddingData]
    public let model: String
    public let usage: Usage
}

/// Individual embedding data
public struct EmbeddingData: Codable, Sendable {
    public let object: String
    public let index: Int
    public let embedding: EmbeddingVector
}

/// Vector representation that can be either float array or base64 string
public enum EmbeddingVector: Codable, Sendable {
    case float([Double])
    case base64(String)
    
    /// Get the embedding as a float array, decoding from base64 if necessary
    public var floatArray: [Double]? {
        switch self {
        case .float(let array):
            return array
        case .base64(let string):
            // Decode base64 to float array if needed
            guard let data = Data(base64Encoded: string) else { return nil }
            return data.withUnsafeBytes { bytes in
                let floats = bytes.bindMemory(to: Float32.self)
                return floats.map { Double($0) }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .float(let array):
            try container.encode(array)
        case .base64(let string):
            try container.encode(string)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([Double].self) {
            self = .float(array)
        } else if let string = try? container.decode(String.self) {
            self = .base64(string)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid embedding format")
        }
    }
}
