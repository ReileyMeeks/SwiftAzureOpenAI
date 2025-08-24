//
//  ImageModels.swift
//  SwiftAzureOpenAI
//
//  Created by Reiley Meeks on 26/07/2025.
//

import Foundation

// MARK: - Image Generation Request Models

/// Request for image generation
public struct ImageGenerationRequest: Codable, Sendable {
    public let prompt: String
    public let model: String?
    public let n: Int?
    public let quality: ImageQuality?
    public let responseFormat: ImageResponseFormat?
    public let size: ImageSize?
    public let style: ImageStyle?
    public let user: String?
    
    public init(
        prompt: String,
        model: String? = nil,
        n: Int? = nil,
        quality: ImageQuality? = nil,
        responseFormat: ImageResponseFormat? = nil,
        size: ImageSize? = nil,
        style: ImageStyle? = nil,
        user: String? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.quality = quality
        self.responseFormat = responseFormat
        self.size = size
        self.style = style
        self.user = user
    }
}

// MARK: - Image Variation Request Models

/// Request for image variations
public struct ImageVariationRequest: Sendable {
    public let image: Data
    public let imageFilename: String
    public let model: String?
    public let n: Int?
    public let responseFormat: ImageResponseFormat?
    public let size: ImageSize?
    public let user: String?
    
    public init(
        image: Data,
        imageFilename: String,
        model: String? = nil,
        n: Int? = nil,
        responseFormat: ImageResponseFormat? = nil,
        size: ImageSize? = nil,
        user: String? = nil
    ) {
        self.image = image
        self.imageFilename = imageFilename
        self.model = model
        self.n = n
        self.responseFormat = responseFormat
        self.size = size
        self.user = user
    }
}

/// Quality of generated images
public enum ImageQuality: String, Codable, Sendable {
    case standard
    case hd
}

/// Format for image response
public enum ImageResponseFormat: String, Codable, Sendable {
    case url
    case b64Json = "b64_json"
}

/// Available image sizes
public enum ImageSize: String, Codable, Sendable {
    case size256x256 = "256x256"
    case size512x512 = "512x512"
    case size1024x1024 = "1024x1024"
    case size1792x1024 = "1792x1024"
    case size1024x1792 = "1024x1792"
}

/// Style of generated images
public enum ImageStyle: String, Codable, Sendable {
    case vivid
    case natural
}

// MARK: - Image Generation Response Models

/// Response containing generated images
public struct ImageGenerationResponse: Codable, Sendable {
    public let created: Int
    public let data: [ImageData]
}

/// Individual image data
public struct ImageData: Codable, Sendable {
    public let url: String?
    public let b64Json: String?
    public let revisedPrompt: String?
}

// MARK: - Image Edit Request Models

/// Request for image editing
public struct ImageEditRequest: Sendable {
    public let image: Data
    public let imageFilename: String
    public let prompt: String
    public let mask: Data?
    public let maskFilename: String?
    public let model: String?
    public let n: Int?
    public let size: ImageSize
    
    public init(
        image: Data,
        imageFilename: String,
        prompt: String,
        mask: Data? = nil,
        maskFilename: String? = nil,
        model: String? = nil,
        n: Int? = nil,
        size: ImageSize
    ) {
        self.image = image
        self.imageFilename = imageFilename
        self.prompt = prompt
        self.mask = mask
        self.maskFilename = maskFilename
        self.model = model
        self.n = n
        self.size = size
    }
}
