//
//  AudioModels.swift
//  SwiftAzureOpenAI
//
//  Created by Reiley Meeks on 26/07/2025.
//

import Foundation

// MARK: - Audio Request Models

/// Request for audio transcription
public struct AudioTranscriptionRequest: Sendable {
    public let file: Data
    public let filename: String
    public let model: String
    public let language: String?
    public let prompt: String?
    public let responseFormat: AudioResponseFormat?
    public let temperature: Double?
    
    public init(
        file: Data,
        filename: String,
        model: String = "whisper-1",
        language: String? = nil,
        prompt: String? = nil,
        responseFormat: AudioResponseFormat? = nil,
        temperature: Double? = nil
    ) {
        self.file = file
        self.filename = filename
        self.model = model
        self.language = language
        self.prompt = prompt
        self.responseFormat = responseFormat
        self.temperature = temperature
    }
}

/// Available audio response formats
public enum AudioResponseFormat: String, Sendable {
    case json
    case text
    case srt
    case verboseJson = "verbose_json"
    case vtt
}

// MARK: - Audio Response Models

/// Basic transcription response
public struct TranscriptionResponse: Codable, Sendable {
    public let text: String
}

/// Verbose transcription response with additional metadata
public struct VerboseTranscriptionResponse: Codable, Sendable {
    public let task: String
    public let language: String
    public let duration: Double
    public let text: String
    public let segments: [TranscriptionSegment]?
}

/// Individual segment of transcribed audio
public struct TranscriptionSegment: Codable, Sendable {
    public let id: Int
    public let seek: Int
    public let start: Double
    public let end: Double
    public let text: String
    public let tokens: [Int]
    public let temperature: Double
    public let avgLogprob: Double
    public let compressionRatio: Double
    public let noSpeechProb: Double
}

// MARK: - Audio Translation Models

/// Request for audio translation
public struct AudioTranslationRequest: Sendable {
    public let file: Data
    public let filename: String
    public let model: String
    public let prompt: String?
    public let responseFormat: AudioResponseFormat?
    public let temperature: Double?
    
    public init(
        file: Data,
        filename: String,
        model: String = "whisper-1",
        prompt: String? = nil,
        responseFormat: AudioResponseFormat? = nil,
        temperature: Double? = nil
    ) {
        self.file = file
        self.filename = filename
        self.model = model
        self.prompt = prompt
        self.responseFormat = responseFormat
        self.temperature = temperature
    }
}
