import SwiftAzureOpenAI
import Foundation

// Example usage - replace with your actual values
let configuration = AzureOpenAIConfiguration(
    resourceName: "your-resource-name",
    apiKey: "your-api-key",
    apiVersion: "your-api-version"
)

let client = AzureOpenAIClient(configuration: configuration)

let request = ChatCompletionRequest(
    messages: [
        .system("You are a helpful assistant."),
        .user("Hello! How are you?")
    ],
    maxTokens: 100,
    temperature: 0.7,
)

do {
    let response = try await client.chatCompletions(
        request,
        deploymentName: "your-deployment-name"
    )
    
    if let choice = response.choices.first,
       case .string(let content) = choice.message.content {
        print("Response: \(content)")
    }
    
    // Test streaming
    print("\nStreaming response:")
    let stream = client.streamChatCompletions(
        request, deploymentName: "your-deployment-name"
    )
    
    for try await chunk in stream {
        if let choice = chunk.choices.first,
           let content = choice.delta.content {
            print(content, terminator: "")
        }
    }
    print("\n")
    
    try await client.shutdown()
} catch {
    print("Error: \(error)")
}
