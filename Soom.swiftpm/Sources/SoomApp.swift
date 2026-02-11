import SwiftUI

/// Soom (숨) - Main app entry point
/// An accessibility app that transforms sound into 3D Echo Sculptures
/// using Liquid Glass design language and Core Haptics.
@main
struct SoomApp: App {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var aiAnalyzer = AIAnalyzer()
    @StateObject private var hapticEngine = HapticEngine()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioManager)
                .environmentObject(aiAnalyzer)
                .environmentObject(hapticEngine)
                .onAppear {
                    setupAudioCategoryCallbacks()
                    setupAccessibility()
                }
        }
    }
    
    /// Sets up callbacks for audio category changes to trigger AI analysis
    private func setupAudioCategoryCallbacks() {
        audioManager.onCategoryChange = { category in
            Task {
                // Trigger AI analysis when audio category changes
                _ = await aiAnalyzer.analyze(audioCategory: category.description)
            }
        }
    }
    
    /// Configures app-wide accessibility settings
    private func setupAccessibility() {
        // Configure accessibility preferences
        UIAccessibility.post(
            notification: .screenChanged,
            argument: "Welcome to Soom. An app that helps you feel sound through 3D sculptures."
        )
        
        // Log app launch for debugging
        print("[Soom] App launched successfully")
        print("[Soom] Haptics supported: \(CHHapticEngine.capabilitiesForHardware().supportsHaptics)")
    }
}

// MARK: - CoreHaptics Import for Capability Check
import CoreHaptics
