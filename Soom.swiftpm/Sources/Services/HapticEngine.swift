import CoreHaptics
import SwiftUI

/// Provides tactile feedback synchronized with audio visualizations.
/// Uses Core Haptics to create custom haptic patterns that correspond to
/// sound characteristics and sculpture animations.
@MainActor
final class HapticEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isEngineRunning = false
    @Published private(set) var currentPattern: HapticPattern = .idle
    
    // MARK: - Private
    
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var patternPlayer: CHHapticPatternPlayer?
    
    /// Tracks the current haptic intensity for continuous feedback
    private var currentIntensity: Float = 0
    private var targetIntensity: Float = 0
    
    /// Timer for continuous haptic updates
    private var hapticTimer: Timer?
    
    // MARK: - Haptic Patterns
    
    /// Predefined haptic patterns for different sound characteristics
    enum HapticPattern: String, CaseIterable {
        case idle = "idle"
        case calm = "calm"
        case rhythmic = "rhythmic"
        case intense = "intense"
        case heartbeat = "heartbeat"
        case pulse = "pulse"
        case continuous = "continuous"
        
        var description: String {
            switch self {
            case .idle: return "No haptic feedback"
            case .calm: return "Gentle, subtle vibrations"
            case .rhythmic: return "Patterned rhythmic feedback"
            case .intense: return "Strong, sharp vibrations"
            case .heartbeat: return "Heartbeat-like pulsing"
            case .pulse: return "Regular pulsing pattern"
            case .continuous: return "Continuous vibration"
            }
        }
    }
    
    // MARK: - Lifecycle
    
    init() {
        prepareHaptics()
    }
    
    deinit {
        stop()
    }
    
    /// Prepares the haptic engine for use
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("[Soom HapticEngine] Haptics not supported on this device")
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                print("[Soom HapticEngine] Engine reset")
                do {
                    try self?.hapticEngine?.start()
                    self?.isEngineRunning = true
                } catch {
                    print("[Soom HapticEngine] Failed to restart: \(error)")
                }
            }
            
            // Handle engine stopped
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("[Soom HapticEngine] Engine stopped: \(reason)")
                self?.isEngineRunning = false
            }
            
            try hapticEngine?.start()
            isEngineRunning = true
            print("[Soom HapticEngine] Engine started successfully")
            
        } catch {
            print("[Soom HapticEngine] Failed to create engine: \(error)")
        }
    }
    
    /// Stops all haptic feedback and the engine
    func stop() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        
        continuousPlayer?.cancel()
        continuousPlayer = nil
        
        patternPlayer?.stop(atTime: 0)
        patternPlayer = nil
        
        hapticEngine?.stop()
        isEngineRunning = false
        currentPattern = .idle
    }
    
    // MARK: - Pattern Playback
    
    /// Plays a predefined haptic pattern
    func playPattern(_ pattern: HapticPattern, intensity: Float = 1.0) {
        guard isEngineRunning else { return }
        
        currentPattern = pattern
        
        switch pattern {
        case .idle:
            stopPattern()
            
        case .calm:
            playCalmPattern(intensity: intensity)
            
        case .rhythmic:
            playRhythmicPattern(intensity: intensity)
            
        case .intense:
            playIntensePattern(intensity: intensity)
            
        case .heartbeat:
            playHeartbeatPattern(intensity: intensity)
            
        case .pulse:
            playPulsePattern(intensity: intensity)
            
        case .continuous:
            playContinuousPattern(intensity: intensity)
        }
    }
    
    /// Updates continuous haptic intensity based on audio power
    func updateIntensity(_ intensity: Float) {
        targetIntensity = intensity
        
        // Smooth the intensity transition
        let smoothing: Float = 0.2
        currentIntensity = currentIntensity * (1 - smoothing) + targetIntensity * smoothing
        
        // Update continuous player if active
        if currentPattern == .continuous, let player = continuousPlayer {
            do {
                let dynamicParameters = [
                    CHHapticDynamicParameter(
                        parameterID: .hapticIntensityControl,
                        value: currentIntensity,
                        relativeTime: 0
                    )
                ]
                try player.sendParameters(dynamicParameters, atTime: 0)
            } catch {
                print("[Soom HapticEngine] Failed to update intensity: \(error)")
            }
        }
    }
    
    /// Plays a transient haptic tick
    func playTransient(intensity: Float = 1.0, sharpness: Float = 0.5) {
        guard isEngineRunning else { return }
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
            
        } catch {
            print("[Soom HapticEngine] Failed to play transient: \(error)")
        }
    }
    
    // MARK: - Private Pattern Methods
    
    private func stopPattern() {
        continuousPlayer?.cancel()
        continuousPlayer = nil
        patternPlayer?.stop(atTime: 0)
        patternPlayer = nil
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
    
    private func playCalmPattern(intensity: Float) {
        stopPattern()
        
        do {
            // Create gentle rising and falling pattern
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0,
                    duration: 0.5
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.1 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0.5,
                    duration: 0.5
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            patternPlayer = try hapticEngine?.makePlayer(with: pattern)
            try patternPlayer?.start(atTime: 0)
            
            // Loop the pattern
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                try? self?.patternPlayer?.start(atTime: 0)
            }
            
        } catch {
            print("[Soom HapticEngine] Failed to play calm pattern: \(error)")
        }
    }
    
    private func playRhythmicPattern(intensity: Float) {
        stopPattern()
        
        do {
            // Create rhythmic pattern with varying intensities
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.25
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.5
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            patternPlayer = try hapticEngine?.makePlayer(with: pattern)
            try patternPlayer?.start(atTime: 0)
            
            // Loop every 0.75 seconds
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
                try? self?.patternPlayer?.start(atTime: 0)
            }
            
        } catch {
            print("[Soom HapticEngine] Failed to play rhythmic pattern: \(error)")
        }
    }
    
    private func playIntensePattern(intensity: Float) {
        stopPattern()
        
        do {
            // Strong, sharp haptic events
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.1,
                    duration: 0.3
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            patternPlayer = try hapticEngine?.makePlayer(with: pattern)
            try patternPlayer?.start(atTime: 0)
            
            // Loop every 0.5 seconds
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                try? self?.patternPlayer?.start(atTime: 0)
            }
            
        } catch {
            print("[Soom HapticEngine] Failed to play intense pattern: \(error)")
        }
    }
    
    private func playHeartbeatPattern(intensity: Float) {
        stopPattern()
        
        do {
            // Simulate heartbeat pattern (lub-dub)
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.15
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            patternPlayer = try hapticEngine?.makePlayer(with: pattern)
            try patternPlayer?.start(atTime: 0)
            
            // Loop every 0.8 seconds (approximate heartbeat rate)
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
                try? self?.patternPlayer?.start(atTime: 0)
            }
            
        } catch {
            print("[Soom HapticEngine] Failed to play heartbeat pattern: \(error)")
        }
    }
    
    private func playPulsePattern(intensity: Float) {
        stopPattern()
        
        do {
            // Regular pulsing pattern synced to audio
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 * intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0,
                    duration: 0.2
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            patternPlayer = try hapticEngine?.makePlayer(with: pattern)
            try patternPlayer?.start(atTime: 0)
            
            // Loop every 0.4 seconds
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                try? self?.patternPlayer?.start(atTime: 0)
            }
            
        } catch {
            print("[Soom HapticEngine] Failed to play pulse pattern: \(error)")
        }
    }
    
    private func playContinuousPattern(intensity: Float) {
        stopPattern()
        
        do {
            // Continuous haptic feedback with dynamic intensity control
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0,
                    duration: 60.0 // Long duration, controlled dynamically
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            continuousPlayer = try hapticEngine?.makeAdvancedPlayer(with: pattern)
            
            // Set initial intensity
            let dynamicParameters = [
                CHHapticDynamicParameter(
                    parameterID: .hapticIntensityControl,
                    value: intensity,
                    relativeTime: 0
                )
            ]
            try continuousPlayer?.sendParameters(dynamicParameters, atTime: 0)
            try continuousPlayer?.start(atTime: 0)
            
        } catch {
            print("[Soom HapticEngine] Failed to play continuous pattern: \(error)")
        }
    }
    
    // MARK: - Sound Classification Mapping
    
    /// Maps sound classifications to appropriate haptic patterns
    func patternForSoundClassification(_ classification: AudioManager.SoundClassification) -> HapticPattern {
        switch classification {
        case .silence, .unknown:
            return .idle
        case .rain, .nature:
            return .calm
        case .speech:
            return .rhythmic
        case .laughter:
            return .heartbeat
        case .music:
            return .rhythmic
        case .siren:
            return .intense
        case .traffic:
            return .pulse
        case .applause:
            return .rhythmic
        case .babyCry:
            return .pulse
        case .dogBark:
            return .intense
        case .doorbell:
            return .intense
        case .footsteps:
            return .pulse
        case .ambient:
            return .calm
        }
    }
    
    /// Maps sculpture mood to haptic pattern
    func patternForMood(_ mood: SculptureMood) -> HapticPattern {
        switch mood.shapeType {
        case .sphere:
            return mood.roughness < 0.3 ? .calm : .heartbeat
        case .box:
            return .intense
        case .torus:
            return .pulse
        case .pyramid:
            return .intense
        case .cylinder:
            return .rhythmic
        }
    }
}
