//
//  ChatModels.swift
//  SwiftAzureOpenAI
//
//  Created by Reiley Meeks on 26/07/2025.
//

import Foundation

// MARK: - Chat Request Models

/// Request for chat completions
public struct ChatCompletionRequest: Codable, Sendable {
    public let messages: [ChatMessage]
    public let model: String?
    public let frequencyPenalty: Double?
    public let logitBias: [String: Double]?
    public let logprobs: Bool?
    public let topLogprobs: Int?
    public let maxTokens: Int?
    public let n: Int?
    public let presencePenalty: Double?
    public let responseFormat: ResponseFormat?
    public let seed: Int?
    public let stop: StopSequence?
    public let temperature: Double?
    public let topP: Double?
    public let tools: [Tool]?
    public let toolChoice: ToolChoice?
    public let user: String?
    public var stream: Bool?
    public let streamOptions: StreamOptions?
    
    public init(
        messages: [ChatMessage],
        model: String? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Double]? = nil,
        logprobs: Bool? = nil,
        topLogprobs: Int? = nil,
        maxTokens: Int? = nil,
        n: Int? = nil,
        presencePenalty: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        stop: StopSequence? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        user: String? = nil,
        stream: Bool? = nil,
        streamOptions: StreamOptions? = nil
    ) {
        self.messages = messages
        self.model = model
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.logprobs = logprobs
        self.topLogprobs = topLogprobs
        self.maxTokens = maxTokens
        self.n = n
        self.presencePenalty = presencePenalty
        self.responseFormat = responseFormat
        self.seed = seed
        self.stop = stop
        self.temperature = temperature
        self.topP = topP
        self.tools = tools
        self.toolChoice = toolChoice
        self.user = user
        self.stream = stream
        self.streamOptions = streamOptions
    }
}

/// A message in a chat conversation
public struct ChatMessage: Codable, Sendable {
    public let role: ChatRole
    public let content: ChatContent?
    public let name: String?
    public let toolCalls: [ToolCall]?
    public let toolCallId: String?
    
    public init(
        role: ChatRole,
        content: ChatContent? = nil,
        name: String? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
    
    /// Convenience initializer for simple text messages
    public init(role: ChatRole, content: String) {
        self.init(role: role, content: .string(content))
    }
    
    /// Convenience initializer for system messages
    public static func system(_ content: String) -> ChatMessage {
        return ChatMessage(role: .system, content: content)
    }
    
    /// Convenience initializer for user messages
    public static func user(_ content: String) -> ChatMessage {
        return ChatMessage(role: .user, content: content)
    }
    
    /// Convenience initializer for assistant messages
    public static func assistant(_ content: String) -> ChatMessage {
        return ChatMessage(role: .assistant, content: content)
    }
}

/// Role of a message sender
public enum ChatRole: String, Codable, Sendable {
    case system
    case user
    case assistant
    case tool
}

/// Content of a chat message (text or multimodal)
public enum ChatContent: Codable, Sendable {
    case string(String)
    case parts([ContentPart])
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let parts = try? container.decode([ContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid content type")
        }
    }
}

/// Part of a multimodal message
public struct ContentPart: Codable, Sendable {
    public let type: ContentPartType
    public let text: String?
    public let imageUrl: ImageUrl?
    
    public init(text: String) {
        self.type = .text
        self.text = text
        self.imageUrl = nil
    }
    
    public init(imageUrl: ImageUrl) {
        self.type = .imageUrl
        self.text = nil
        self.imageUrl = imageUrl
    }
}

/// Type of content part
public enum ContentPartType: String, Codable, Sendable {
    case text
    case imageUrl = "image_url"
}

/// Image URL for vision models
public struct ImageUrl: Codable, Sendable {
    public let url: String
    public let detail: ImageDetail?
    
    public init(url: String, detail: ImageDetail? = nil) {
        self.url = url
        self.detail = detail
    }
}

/// Image detail level for vision models
public enum ImageDetail: String, Codable, Sendable {
    case auto
    case low
    case high
}

/// Response format specification
public struct ResponseFormat: Codable, Sendable {
    public let type: ResponseFormatType
    
    public init(type: ResponseFormatType) {
        self.type = type
    }
}

/// Available response format types
public enum ResponseFormatType: String, Codable, Sendable {
    case text
    case jsonObject = "json_object"
}

/// Stop sequences for completion
public enum StopSequence: Codable, Sendable {
    case string(String)
    case array([String])
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([String].self) {
            self = .array(array)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid stop sequence")
        }
    }
}

/// Options for streaming responses
public struct StreamOptions: Codable, Sendable {
    public let includeUsage: Bool?
    
    public init(includeUsage: Bool? = nil) {
        self.includeUsage = includeUsage
    }
}

// MARK: - Chat Response Models

/// Response from chat completion
public struct ChatCompletionResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatChoice]
    public let usage: Usage?
    public let systemFingerprint: String?
}

/// A choice in chat completion response
public struct ChatChoice: Codable, Sendable {
    public let index: Int
    public let message: ChatMessage
    public let logprobs: LogProbs?
    public let finishReason: FinishReason?
}

/// Log probability information
public struct LogProbs: Codable, Sendable {
    public let content: [LogProbContent]?
}

/// Log probability for a token
public struct LogProbContent: Codable, Sendable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
    public let topLogprobs: [TopLogProb]?
}

/// Top log probabilities
public struct TopLogProb: Codable, Sendable {
    public let token: String
    public let logprob: Double
    public let bytes: [Int]?
}

/// Reason why the model stopped generating
public enum FinishReason: String, Codable, Sendable {
    case stop
    case length
    case contentFilter = "content_filter"
    case toolCalls = "tool_calls"
}

// MARK: - Streaming Response Models

/// Chunk of a streaming chat completion
public struct ChatCompletionChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let systemFingerprint: String?
    public let choices: [ChatChunkChoice]
    public let usage: Usage?
}

/// Choice in a streaming chunk
public struct ChatChunkChoice: Codable, Sendable {
    public let index: Int
    public let delta: ChatDelta
    public let logprobs: LogProbs?
    public let finishReason: FinishReason?
}

/// Delta content in streaming response
public struct ChatDelta: Codable, Sendable {
    public let role: ChatRole?
    public let content: String?
    public let toolCalls: [ToolCallDelta]?
}

/// Delta for tool calls in streaming
public struct ToolCallDelta: Codable, Sendable {
    public let index: Int
    public let id: String?
    public let type: String?
    public let function: FunctionCallDelta?
}

/// Delta for function calls in streaming
public struct FunctionCallDelta: Codable, Sendable {
    public let name: String?
    public let arguments: String?
}
