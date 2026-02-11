import Foundation
import FoundationModels
import RealityKit
import SwiftUI

/// Represents the emotional and physical characteristics of a 3D sculpture
/// derived from audio analysis using on-device AI.
struct SculptureMood: Sendable {
    var color: Color
    var roughness: Float
    var refraction: Float
    var shapeType: SculptureShapeType
    var metallic: Float
    
    /// Predefined moods for common audio categories
    static let calm = SculptureMood(
        color: .cyan,
        roughness: 0.1,
        refraction: 0.9,
        shapeType: .sphere,
        metallic: 0.3
    )
    
    static let energetic = SculptureMood(
        color: .orange,
        roughness: 0.4,
        refraction: 0.3,
        shapeType: .box,
        metallic: 0.9
    )
    
    static let melancholic = SculptureMood(
        color: .indigo,
        roughness: 0.7,
        refraction: 0.5,
        shapeType: .torus,
        metallic: 0.2
    )
    
    static let joyful = SculptureMood(
        color: .yellow,
        roughness: 0.2,
        refraction: 0.7,
        shapeType: .sphere,
        metallic: 0.5
    )
    
    static let intense = SculptureMood(
        color: .red,
        roughness: 0.6,
        refraction: 0.2,
        shapeType: .pyramid,
        metallic: 0.95
    )
}

/// The geometric shape type for the sculpture
enum SculptureShapeType: String, Sendable, CaseIterable {
    case sphere
    case box
    case torus
    case pyramid
    case cylinder
}

/// AI-powered analyzer that uses on-device Foundation Models to determine
/// sculpture mood from audio characteristics.
@MainActor
final class AIAnalyzer: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var currentMood: SculptureMood = .calm
    @Published private(set) var isAnalyzing = false
    
    // MARK: - Private
    
    private var languageSession: LanguageModelSession?
    
    // MARK: - Lifecycle
    
    init() {
        setupSession()
    }
    
    private func setupSession() {
        // Configure the on-device language model session
        languageSession = LanguageModelSession()
    }
    
    // MARK: - Analysis
    
    /// Analyzes an audio category and returns a corresponding sculpture mood.
    /// Uses Foundation Models for semantic understanding of audio characteristics.
    /// - Parameter audioCategory: A placeholder category or description of the audio
    /// - Returns: A SculptureMood representing the AI's interpretation
    func analyze(audioCategory: String) async -> SculptureMood {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            let mood = try await performAIAnalysis(audioCategory: audioCategory)
            await MainActor.run {
                currentMood = mood
            }
            return mood
        } catch {
            print("[Soom AIAnalyzer] Analysis failed: \(error)")
            // Fallback to rule-based mapping
            return fallbackMood(for: audioCategory)
        }
    }
    
    /// Performs AI analysis using FoundationModels framework
    private func performAIAnalysis(audioCategory: String) async throws -> SculptureMood {
        guard let session = languageSession else {
            throw AIAnalyzerError.sessionNotAvailable
        }
        
        let prompt = """
        Analyze this sound description and create a 3D sculpture mood for Soom:
        "\(audioCategory)"
        
        Respond with a color name (cyan, orange, indigo, yellow, red, purple, green, pink),
        roughness (0.0-1.0), refraction (0.0-1.0), metallic (0.0-1.0), and shape (sphere, box, torus, pyramid, cylinder).
        Format: COLOR|ROUGHNESS|REFRACTION|METALLIC|SHAPE
        """
        
        let response = try await session.respond(to: prompt)
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse the response
        return parseAIResponse(text)
    }
    
    /// Parses the AI response into a SculptureMood
    private func parseAIResponse(_ text: String) -> SculptureMood {
        let components = text.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        guard components.count >= 5 else {
            return fallbackMood(for: text)
        }
        
        let color = colorFromString(components[0])
        let roughness = Float(components[1]) ?? 0.5
        let refraction = Float(components[2]) ?? 0.5
        let metallic = Float(components[3]) ?? 0.5
        let shape = SculptureShapeType(rawValue: components[4].lowercased()) ?? .sphere
        
        return SculptureMood(
            color: color,
            roughness: roughness,
            refraction: refraction,
            shapeType: shape,
            metallic: metallic
        )
    }
    
    /// Converts a string to a SwiftUI Color
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "cyan": return .cyan
        case "orange": return .orange
        case "indigo": return .indigo
        case "yellow": return .yellow
        case "red": return .red
        case "purple": return .purple
        case "green": return .green
        case "pink": return .pink
        case "blue": return .blue
        case "mint": return .mint
        case "teal": return .teal
        default: return .cyan
        }
    }
    
    /// Fallback mood mapping when AI is unavailable
    private func fallbackMood(for category: String) -> SculptureMood {
        let lowercased = category.lowercased()
        
        if lowercased.contains("calm") || lowercased.contains("quiet") || lowercased.contains("soft") || lowercased.contains("rain") {
            return .calm
        } else if lowercased.contains("energy") || lowercased.contains("fast") || lowercased.contains("loud") || lowercased.contains("siren") {
            return .energetic
        } else if lowercased.contains("sad") || lowercased.contains("slow") || lowercased.contains("melancholy") {
            return .melancholic
        } else if lowercased.contains("happy") || lowercased.contains("joy") || lowercased.contains("bright") || lowercased.contains("laughter") {
            return .joyful
        } else if lowercased.contains("intense") || lowercased.contains("heavy") || lowercased.contains("aggressive") {
            return .intense
        }
        
        return .calm
    }
}

// MARK: - Errors

enum AIAnalyzerError: Error {
    case sessionNotAvailable
    case parsingFailed
    case analysisFailed(String)
}
