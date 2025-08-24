import Testing
import Foundation
@testable import SwiftAzureOpenAI

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func testChatCompletions() async throws {
    // Skip test if environment variables are not set
    guard let resourceName = ProcessInfo.processInfo.environment["AZURE_OPENAI_RESOURCE_NAME"],
          let apiKey = ProcessInfo.processInfo.environment["AZURE_OPENAI_API_KEY"],
          let deploymentName = ProcessInfo.processInfo.environment["AZURE_OPENAI_DEPLOYMENT_NAME"] else {
        throw TestSkipped("Environment variables not set")
    }
    
    let configuration = AzureOpenAIConfiguration(
        resourceName: resourceName,
        apiKey: apiKey
    )
    
    let client = AzureOpenAIClient(configuration: configuration)
    defer {
        Task {
            try? await client.shutdown()
        }
    }
    
    let request = ChatCompletionRequest(
        messages: [
            .system("You are a helpful assistant."),
            .user("Say 'Hello, World!' and nothing else.")
        ],
        maxTokens: 50,
        temperature: 0.1
    )
    
    let response = try await client.chatCompletions(request, deploymentName: deploymentName)
    
    #expect(!response.choices.isEmpty)
    #expect(response.choices[0].message.content != nil)
    
    if case .string(let content) = response.choices[0].message.content {
        #expect(content.contains("Hello"))
    }
}

@Test func testStreamingChatCompletions() async throws {
    // Skip test if environment variables are not set
    guard let resourceName = ProcessInfo.processInfo.environment["AZURE_OPENAI_RESOURCE_NAME"],
          let apiKey = ProcessInfo.processInfo.environment["AZURE_OPENAI_API_KEY"],
          let deploymentName = ProcessInfo.processInfo.environment["AZURE_OPENAI_DEPLOYMENT_NAME"] else {
        throw TestSkipped("Environment variables not set")
    }
    
    let configuration = AzureOpenAIConfiguration(
        resourceName: resourceName,
        apiKey: apiKey
    )
    
    let client = AzureOpenAIClient(configuration: configuration)
    defer {
        Task {
            try? await client.shutdown()
        }
    }
    
    let request = ChatCompletionRequest(
        messages: [
            .system("You are a helpful assistant."),
            .user("Count from 1 to 3.")
        ],
        maxTokens: 50,
        temperature: 0.1
    )
    
    let stream = client.streamChatCompletions(request, deploymentName: deploymentName)
    var chunks: [ChatCompletionChunk] = []
    
    for try await chunk in stream {
        chunks.append(chunk)
    }
    
    #expect(!chunks.isEmpty)
    #expect(chunks.first?.choices.first?.delta.role == .assistant)
}

private struct TestSkipped: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}
