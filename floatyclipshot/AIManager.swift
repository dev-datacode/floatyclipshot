//
//  AIManager.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/18/25.
//
//  Handles local AI processing using Vision and NaturalLanguage frameworks.
//  Privacy-first: All processing happens on-device.
//

import Foundation
import Vision
import NaturalLanguage
import AppKit

class AIManager {
    static let shared = AIManager()
    
    private init() {}
    
    // MARK: - OCR (Optical Character Recognition) 
    
    /// Extract text from an image using Apple's Vision framework
    /// - Parameter image: The image to process
    /// - Returns: The extracted text, or nil if no text found/error
    func extractText(from image: NSImage) async -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let recognizedText = observations.compactMap {
                    observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText.isEmpty ? nil : recognizedText)
            }
            
            // Configure for accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ OCR failed: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Text Classification
    
    enum ContentCategory: String, Codable {
        case code = "Code"
        case url = "URL"
        case email = "Email"
        case date = "Date"
        case address = "Address"
        case phoneNumber = "Phone"
        case plainText = "Text"
        case unknown = "Unknown"
    }
    
    /// Analyze text to determine its category
    func categorize(_ text: String) -> ContentCategory {
        // 1. Check for specific patterns (Regex)
        if text.contains("http://") || text.contains("https://") {
            return .url
        }
        
        if text.contains("@") && text.contains(".") {
            // Simple heuristic for email
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
                if matches.contains(where: { $0.url?.scheme == "mailto" }) {
                    return .email
                }
            }
        }
        
        // 2. Check for code-like patterns
        if isCode(text) {
            return .code
        }
        
        // 3. Use Natural Language Tagging for Named Entities
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var tagCounts: [NLTag: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace]) { tag, _ in
            if let tag = tag {
                tagCounts[tag, default: 0] += 1
            }
            return true
        }
        
        if let _ = tagCounts[.personalName] {
            // Could be a contact or address, but treat as text for now
            return .plainText
        }
        
        return .plainText
    }
    
    /// Heuristic to detect if text looks like code
    private func isCode(_ text: String) -> Bool {
        let codeIndicators = [
            "func ", "var ", "let ", "import ", "class ", "struct ", "if ", "else ", "return",
            "{", "}", ";", "=>", "def ", "pub ", "fn ", "#include", "std::", "print(", "console.log"
        ]
        
        let lines = text.components(separatedBy: .newlines)
        // If it has many lines and contains code keywords, it's likely code
        let matchCount = codeIndicators.filter { text.contains($0) }.count
        
        return matchCount >= 2 || (lines.count > 1 && (text.contains("{") || text.contains(";")))
    }
}
