//
//  CommonModels.swift
//  SwiftAzureOpenAI
//
//  Created by Reiley Meeks on 26/07/2025.
//

import Foundation

// MARK: - Common Response Models

/// Token usage information returned by most API endpoints
public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int?
    public let totalTokens: Int
}

// MARK: - Error Models

/// Error response from Azure OpenAI API
public struct ErrorResponse: Codable, Sendable {
    public let error: APIError
}

/// Detailed API error information
public struct APIError: Codable, Sendable {
    public let message: String
    public let type: String
    public let param: String?
    public let code: String?
}

// MARK: - Azure OpenAI Errors

/// Errors that can occur when using the Azure OpenAI service
public enum AzureOpenAIError: LocalizedError, Sendable {
    case apiError(APIError)
    case httpError(statusCode: UInt)
    case invalidResponse
    case streamingError(String)
    case encodingError(String)
    case missingData
    
    public var errorDescription: String? {
        switch self {
        case .apiError(let error):
            return "API Error: \(error.message) (type: \(error.type), code: \(error.code ?? "unknown"))"
        case .httpError(let statusCode):
            return "HTTP Error: \(statusCode)"
        case .invalidResponse:
            return "Invalid response from Azure OpenAI API"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .missingData:
            return "Response data is missing"
        }
    }
}

// MARK: - Configuration

/// Configuration for Azure OpenAI client
public struct AzureOpenAIConfiguration: Sendable {
    public let resourceName: String
    public let apiKey: String
    public let apiVersion: String
    public let timeoutInterval: TimeInterval
    
    public var baseURL: String {
        "https://\(resourceName).openai.azure.com"
    }
    
    public init(
        resourceName: String,
        apiKey: String,
        apiVersion: String = "2024-06-01",
        timeoutInterval: TimeInterval = 60
    ) {
        self.resourceName = resourceName
        self.apiKey = apiKey
        self.apiVersion = apiVersion
        self.timeoutInterval = timeoutInterval
    }
    
    /// Convenience initializer using environment variables
    /// Expects AZURE_OPENAI_RESOURCE_NAME and AZURE_OPENAI_API_KEY
    public init?(
        apiVersion: String = "2024-06-01",
        timeoutInterval: TimeInterval = 60
    ) {
        guard let resourceName = ProcessInfo.processInfo.environment["AZURE_OPENAI_RESOURCE_NAME"],
              let apiKey = ProcessInfo.processInfo.environment["AZURE_OPENAI_API_KEY"] else {
            return nil
        }
        
        self.resourceName = resourceName
        self.apiKey = apiKey
        self.apiVersion = apiVersion
        self.timeoutInterval = timeoutInterval
    }
}
