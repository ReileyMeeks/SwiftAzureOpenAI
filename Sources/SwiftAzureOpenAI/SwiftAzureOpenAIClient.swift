// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import AsyncHTTPClient
import NIOHTTP1

/// Main client for interacting with Azure OpenAI Service
public final class AzureOpenAIClient: Sendable {
    // MARK: - Properties
    
    private let httpClient: HTTPClient
    private let configuration: AzureOpenAIConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let shouldShutdownClient: Bool
    
    // MARK: - Initialization
    
    /// Initialize a new Azure OpenAI client
    /// - Parameters:
    ///   - configuration: Azure OpenAI configuration including resource name, API key, and version
    ///   - httpClient: Optional HTTP client. If not provided, a new one will be created
    public init(
        configuration: AzureOpenAIConfiguration,
        httpClient: HTTPClient? = nil
    ) {
        self.configuration = configuration
        
        if let httpClient = httpClient {
            self.httpClient = httpClient
            self.shouldShutdownClient = false
        } else {
            self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            self.shouldShutdownClient = true
        }
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    deinit {
        if shouldShutdownClient {
            try? httpClient.syncShutdown()
        }
    }
    
    /// Shut down the HTTP client gracefully
    /// Call this when you're done using the client to free resources
    public func shutdown() async throws {
        if shouldShutdownClient {
            try await httpClient.shutdown()
        }
    }
    
    // MARK: - Chat Completions
    
    /// Create a chat completion
    /// - Parameters:
    ///   - request: The chat completion request
    ///   - deploymentName: The name of your deployed model
    /// - Returns: Chat completion response
    public func chatCompletions(
        _ request: ChatCompletionRequest,
        deploymentName: String
    ) async throws -> ChatCompletionResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/chat/completions"
        return try await performRequest(
            endpoint: endpoint,
            method: .POST,
            body: request
        )
    }
    
    /// Create a streaming chat completion
    /// - Parameters:
    ///   - request: The chat completion request
    ///   - deploymentName: The name of your deployed model
    /// - Returns: AsyncThrowingStream of chat completion chunks
    public func streamChatCompletions(
        _ request: ChatCompletionRequest,
        deploymentName: String
    ) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        var streamRequest = request
        streamRequest.stream = true
        
        return AsyncThrowingStream { [streamRequest] continuation in
            Task { @Sendable in
                do {
                    let endpoint = "/openai/deployments/\(deploymentName)/chat/completions"
                    let url = buildURL(endpoint: endpoint)
                    
                    var httpRequest = HTTPClientRequest(url: url)
                    httpRequest.method = .POST
                    httpRequest.headers.add(name: "api-key", value: configuration.apiKey)
                    httpRequest.headers.add(name: "Content-Type", value: "application/json")
                    
                    let bodyData = try encoder.encode(streamRequest)
                    httpRequest.body = .bytes(bodyData)
                    
                    let response = try await httpClient.execute(
                        httpRequest,
                        timeout: .seconds(Int64(configuration.timeoutInterval))
                    )
                    
                    guard response.status == .ok else {
                        let errorData = try await response.body.collect(upTo: 1024 * 1024)
                        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                            throw AzureOpenAIError.apiError(errorResponse.error)
                        }
                        throw AzureOpenAIError.httpError(statusCode: response.status.code)
                    }
                    
                    // Process Server-Sent Events stream
                    var buffer = ""
                    for try await chunk in response.body {
                        let chunkString = String(buffer: chunk)
                        buffer += chunkString
                        
                        // Process complete SSE messages
                        while let dataRange = buffer.range(of: "data: ") {
                            if let endRange = buffer.range(of: "\n\n", range: dataRange.upperBound..<buffer.endIndex) {
                                let dataContent = String(buffer[dataRange.upperBound..<endRange.lowerBound])
                                buffer = String(buffer[endRange.upperBound...])
                                
                                if dataContent.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                
                                if !dataContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                   let data = dataContent.data(using: .utf8) {
                                    do {
                                        let chunk = try decoder.decode(ChatCompletionChunk.self, from: data)
                                        continuation.yield(chunk)
                                    } catch {
                                        // Log decoding error but continue processing
                                        continue
                                    }
                                }
                            } else {
                                break
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Embeddings
    
    /// Create embeddings for the given input
    /// - Parameters:
    ///   - request: The embedding request
    ///   - deploymentName: The name of your deployed embedding model
    /// - Returns: Embedding response
    public func embeddings(
        _ request: EmbeddingRequest,
        deploymentName: String
    ) async throws -> EmbeddingResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/embeddings"
        return try await performRequest(
            endpoint: endpoint,
            method: .POST,
            body: request
        )
    }
    
    // MARK: - Audio
    
    /// Transcribe audio
    /// - Parameters:
    ///   - request: The audio transcription request
    ///   - deploymentName: The name of your deployed Whisper model
    /// - Returns: Transcription response
    public func transcribeAudio(
        _ request: AudioTranscriptionRequest,
        deploymentName: String
    ) async throws -> TranscriptionResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/audio/transcriptions"
        let url = buildURL(endpoint: endpoint)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .POST
        httpRequest.headers.add(name: "api-key", value: configuration.apiKey)
        httpRequest.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
        
        let bodyData = createMultipartBody(
            for: request,
            boundary: boundary
        )
        
        httpRequest.body = .bytes(bodyData)
        
        let response = try await httpClient.execute(
            httpRequest,
            timeout: .seconds(Int64(configuration.timeoutInterval))
        )
        
        guard response.status == .ok else {
            let errorData = try await response.body.collect(upTo: 1024 * 1024)
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                throw AzureOpenAIError.apiError(errorResponse.error)
            }
            throw AzureOpenAIError.httpError(statusCode: response.status.code)
        }
        
        let buffer = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let responseData = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) ?? Data()
        
        // Handle different response formats
        if request.responseFormat == .text {
            let text = String(data: responseData, encoding: .utf8) ?? ""
            return TranscriptionResponse(text: text)
        } else {
            return try decoder.decode(TranscriptionResponse.self, from: responseData)
        }
    }
    
    /// Translate audio
    /// - Parameters:
    ///   - request: The audio translation request
    ///   - deploymentName: The name of your deployed Whisper model
    /// - Returns: Translation response
    public func translateAudio(
        _ request: AudioTranslationRequest,
        deploymentName: String
    ) async throws -> TranscriptionResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/audio/translations"
        let url = buildURL(endpoint: endpoint)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .POST
        httpRequest.headers.add(name: "api-key", value: configuration.apiKey)
        httpRequest.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
        
        let bodyData = createMultipartBody(
            for: request,
            boundary: boundary
        )
        
        httpRequest.body = .bytes(bodyData)
        
        let response = try await httpClient.execute(
            httpRequest,
            timeout: .seconds(Int64(configuration.timeoutInterval))
        )
        
        guard response.status == .ok else {
            let errorData = try await response.body.collect(upTo: 1024 * 1024)
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                throw AzureOpenAIError.apiError(errorResponse.error)
            }
            throw AzureOpenAIError.httpError(statusCode: response.status.code)
        }
        
        let buffer = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let responseData = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) ?? Data()
        
        // Handle different response formats
        if request.responseFormat == .text {
            let text = String(data: responseData, encoding: .utf8) ?? ""
            return TranscriptionResponse(text: text)
        } else {
            return try decoder.decode(TranscriptionResponse.self, from: responseData)
        }
    }
    
    // MARK: - Images
    
    /// Generate images from a text prompt
    /// - Parameters:
    ///   - request: The image generation request
    ///   - deploymentName: The name of your deployed DALL-E model
    /// - Returns: Image generation response
    public func createImages(
        _ request: ImageGenerationRequest,
        deploymentName: String
    ) async throws -> ImageGenerationResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/images/generations"
        return try await performRequest(
            endpoint: endpoint,
            method: .POST,
            body: request
        )
    }
    
    /// Create variations of an image
    /// - Parameters:
    ///   - request: The image variation request
    ///   - deploymentName: The name of your deployed DALL-E model
    /// - Returns: Image generation response
    public func createImageVariations(
        _ request: ImageVariationRequest,
        deploymentName: String
    ) async throws -> ImageGenerationResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/images/variations"
        let url = buildURL(endpoint: endpoint)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .POST
        httpRequest.headers.add(name: "api-key", value: configuration.apiKey)
        httpRequest.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
        
        let bodyData = createMultipartBody(for: request, boundary: boundary)
        httpRequest.body = .bytes(bodyData)
        
        let response = try await httpClient.execute(
            httpRequest,
            timeout: .seconds(Int64(configuration.timeoutInterval))
        )
        
        guard response.status == .ok else {
            let errorData = try await response.body.collect(upTo: 1024 * 1024)
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                throw AzureOpenAIError.apiError(errorResponse.error)
            }
            throw AzureOpenAIError.httpError(statusCode: response.status.code)
        }
        
        let responseData = try await response.body.collect(upTo: 10 * 1024 * 1024)
        return try decoder.decode(ImageGenerationResponse.self, from: responseData)
    }
    
    /// Edit an image using a prompt
    /// - Parameters:
    ///   - request: The image edit request
    ///   - deploymentName: The name of your deployed DALL-E model
    /// - Returns: Image generation response
    public func editImage(
        _ request: ImageEditRequest,
        deploymentName: String
    ) async throws -> ImageGenerationResponse {
        let endpoint = "/openai/deployments/\(deploymentName)/images/edits"
        let url = buildURL(endpoint: endpoint)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .POST
        httpRequest.headers.add(name: "api-key", value: configuration.apiKey)
        httpRequest.headers.add(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
        
        let bodyData = createMultipartBody(for: request, boundary: boundary)
        httpRequest.body = .bytes(bodyData)
        
        let response = try await httpClient.execute(
            httpRequest,
            timeout: .seconds(Int64(configuration.timeoutInterval))
        )
        
        guard response.status == .ok else {
            let errorData = try await response.body.collect(upTo: 1024 * 1024)
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                throw AzureOpenAIError.apiError(errorResponse.error)
            }
            throw AzureOpenAIError.httpError(statusCode: response.status.code)
        }
        
        let responseData = try await response.body.collect(upTo: 10 * 1024 * 1024)
        return try decoder.decode(ImageGenerationResponse.self, from: responseData)
    }
    
    // MARK: - Private Methods
    
    private func buildURL(endpoint: String) -> String {
        "\(configuration.baseURL)\(endpoint)?api-version=\(configuration.apiVersion)"
    }
    
    private func performRequest<Request: Encodable, Response: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        body: Request? = nil
    ) async throws -> Response {
        let url = buildURL(endpoint: endpoint)
        
        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = method
        httpRequest.headers.add(name: "api-key", value: configuration.apiKey)
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        
        if let body = body {
            let bodyData = try encoder.encode(body)
            httpRequest.body = .bytes(bodyData)
        }
        
        let response = try await httpClient.execute(
            httpRequest,
            timeout: .seconds(Int64(configuration.timeoutInterval))
        )
        
        guard response.status == .ok else {
            let errorData = try await response.body.collect(upTo: 1024 * 1024)
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: errorData) {
                throw AzureOpenAIError.apiError(errorResponse.error)
            }
            throw AzureOpenAIError.httpError(statusCode: response.status.code)
        }
        
        let responseData = try await response.body.collect(upTo: 10 * 1024 * 1024)
        return try decoder.decode(Response.self, from: responseData)
    }
    
    private func createMultipartBody(
        for request: AudioTranscriptionRequest,
        boundary: String
    ) -> Data {
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(request.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType(for: request.filename))\r\n\r\n".data(using: .utf8)!)
        body.append(request.file)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append(request.model.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add optional fields
        if let language = request.language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append(language.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let prompt = request.prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(prompt.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
            body.append(responseFormat.rawValue.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let temperature = request.temperature {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append(String(temperature).data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func createMultipartBody(
        for request: AudioTranslationRequest,
        boundary: String
    ) -> Data {
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(request.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType(for: request.filename))\r\n\r\n".data(using: .utf8)!)
        body.append(request.file)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append(request.model.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add optional fields
        if let prompt = request.prompt {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
            body.append(prompt.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
            body.append(responseFormat.rawValue.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let temperature = request.temperature {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append(String(temperature).data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func createMultipartBody(
        for request: ImageVariationRequest,
        boundary: String
    ) -> Data {
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(request.imageFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType(for: request.imageFilename))\r\n\r\n".data(using: .utf8)!)
        body.append(request.image)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add optional fields
        if let model = request.model {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append(model.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let n = request.n {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"n\"\r\n\r\n".data(using: .utf8)!)
            body.append(String(n).data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let responseFormat = request.responseFormat {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
            body.append(responseFormat.rawValue.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let size = request.size {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
            body.append(size.rawValue.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let user = request.user {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"user\"\r\n\r\n".data(using: .utf8)!)
            body.append(user.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func createMultipartBody(
        for request: ImageEditRequest,
        boundary: String
    ) -> Data {
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(request.imageFilename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType(for: request.imageFilename))\r\n\r\n".data(using: .utf8)!)
        body.append(request.image)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add prompt
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append(request.prompt.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add mask if provided
        if let mask = request.mask, let maskFilename = request.maskFilename {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"mask\"; filename=\"\(maskFilename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType(for: maskFilename))\r\n\r\n".data(using: .utf8)!)
            body.append(mask)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add size
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
        body.append(request.size.rawValue.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add optional fields
        if let model = request.model {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append(model.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        if let n = request.n {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"n\"\r\n\r\n".data(using: .utf8)!)
            body.append(String(n).data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    private func mimeType(for filename: String) -> String {
        let pathExtension = (filename as NSString).pathExtension.lowercased()
        switch pathExtension {
        case "mp3": return "audio/mpeg"
        case "mp4": return "audio/mp4"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }
}

