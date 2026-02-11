import SwiftUI

/// The main content view hosting the immersive 3D sculpture and audio controls.
/// Features Liquid Glass design language with ultra-thin materials and fluid animations.
/// Fully accessible with VoiceOver support for describing Echo Sculptures.
struct ContentView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var aiAnalyzer: AIAnalyzer
    @EnvironmentObject var hapticEngine: HapticEngine
    
    // MARK: - State
    @State private var isControlBarExpanded = false
    @State private var controlBarScale: CGFloat = 1.0
    @State private var showVoiceOverDescription = false
    @State private var lastVoiceOverAnnouncement: String = ""
    
    // MARK: - Accessibility
    @AccessibilityFocusState private var isRecordButtonFocused: Bool
    
    var body: some View {
        ZStack {
            // Immersive 3D sculpture view
            ImmersiveView()
                .environmentObject(audioManager)
                .environmentObject(aiAnalyzer)
                .environmentObject(hapticEngine)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(sculptureAccessibilityLabel)
                .accessibilityHint("Double tap to hear a detailed description of the current Echo Sculpture")
                .accessibilityAction(named: "Describe Sculpture") {
                    announceSculptureDescription()
                }
            
            // Overlay controls with Liquid Glass effect
            VStack {
                // App branding
                soomBranding
                
                Spacer()
                
                // VoiceOver description panel
                if showVoiceOverDescription {
                    voiceOverPanel
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                liquidGlassControlBar
            }
        }
        .onAppear {
            // Trigger initial AI analysis
            Task {
                _ = await aiAnalyzer.analyze(audioCategory: "ambient calm")
            }
            
            // Set up VoiceOver announcement observer
            setupVoiceOverNotifications()
        }
        .onChange(of: aiAnalyzer.currentMood) { _, _ in
            // Announce mood changes to VoiceOver users
            if UIAccessibility.isVoiceOverRunning {
                announceMoodChange()
            }
        }
        .onChange(of: audioManager.soundClassification) { _, newClassification in
            // Announce sound classification to VoiceOver users
            if UIAccessibility.isVoiceOverRunning && newClassification != .unknown {
                announceSoundClassification(newClassification)
            }
        }
    }
    
    // MARK: - VoiceOver Support
    
    /// Generates an accessibility label describing the current sculpture
    private var sculptureAccessibilityLabel: String {
        let mood = aiAnalyzer.currentMood
        let classification = audioManager.soundClassification
        let power = Int(audioManager.normalizedPower * 100)
        
        var description = "Soom Echo Sculpture. "
        description += "Currently displaying a \(mood.shapeType.accessibilityName) shape. "
        description += "Mood is \(mood.accessibilityDescription). "
        
        if classification != .unknown {
            description += "Detected sound: \(classification.accessibilityDescription). "
        }
        
        description += "Sound intensity is \(power) percent."
        
        return description
    }
    
    /// Generates a detailed description of the sculpture for VoiceOver
    private func generateSculptureDescription() -> String {
        let mood = aiAnalyzer.currentMood
        let classification = audioManager.soundClassification
        let bands = audioManager.frequencyBands
        let power = Int(audioManager.normalizedPower * 100)
        
        var description = "Echo Sculpture Description: "
        
        // Shape description
        description += "The sculpture is a \(mood.shapeType.accessibilityName) made of liquid glass. "
        
        // Material description
        if mood.roughness < 0.3 {
            description += "It has a smooth, polished surface. "
        } else if mood.roughness < 0.6 {
            description += "It has a slightly textured surface. "
        } else {
            description += "It has a rough, crystalline texture. "
        }
        
        // Color and transparency
        description += "The color is \(mood.color.accessibilityName). "
        if mood.refraction > 0.7 {
            description += "It appears translucent and fluid. "
        } else if mood.refraction > 0.4 {
            description += "It has a semi-transparent quality. "
        } else {
            description += "It appears more solid and opaque. "
        }
        
        // Sound analysis
        if audioManager.isRunning {
            description += "Soom is actively listening. "
            
            if classification != .unknown {
                description += "Detected \(classification.accessibilityDescription). "
            }
            
            description += "Sound intensity is \(power) percent. "
            
            // Frequency description
            if bands.low > 0.5 {
                description += "Strong bass frequencies detected. "
            }
            if bands.high > 0.5 {
                description += "Bright high tones present. "
            }
        } else {
            description += "Soom is not currently listening. Tap the record button to begin."
        }
        
        return description
    }
    
    private func announceSculptureDescription() {
        let description = generateSculptureDescription()
        lastVoiceOverAnnouncement = description
        showVoiceOverDescription = true
        UIAccessibility.post(notification: .announcement, argument: description)
        
        // Hide panel after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                showVoiceOverDescription = false
            }
        }
    }
    
    private func announceMoodChange() {
        let mood = aiAnalyzer.currentMood
        let announcement = "Sculpture changed to \(mood.color.accessibilityName) \(mood.shapeType.accessibilityName)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    private func announceSoundClassification(_ classification: AudioManager.SoundClassification) {
        let announcement = "Soom hears: \(classification.accessibilityDescription)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    private func setupVoiceOverNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            if UIAccessibility.isVoiceOverRunning {
                // Announce app start for VoiceOver users
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Welcome to Soom. Tap the record button to start feeling sound."
                )
            }
        }
    }
    
    // MARK: - VoiceOver Panel
    
    private var voiceOverPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "ear.fill")
                    .foregroundStyle(.primary)
                Text("VoiceOver Description")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    withAnimation {
                        showVoiceOverDescription = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss description")
            }
            
            Text(lastVoiceOverAnnouncement)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Branding
    
    private var soomBranding: some View {
        VStack(spacing: 4) {
            Text("Soom")
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
                .accessibilityLabel("Soom")
                .accessibilityHint("Sound visualization app")
            
            Text("Feel the Sound")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Tagline: Feel the Sound")
        }
        .padding(.top, 60)
    }
    
    // MARK: - Liquid Glass Controls
    
    private var liquidGlassControlBar: some View {
        VStack(spacing: 16) {
            // Mood indicator with liquid glass
            if aiAnalyzer.isAnalyzing {
                analyzingIndicator
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Sound classification indicator
            if audioManager.isRunning && audioManager.soundClassification != .unknown {
                soundClassificationIndicator
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            HStack(spacing: 24) {
                // Main record button with liquid glass styling
                liquidRecordButton
                
                // Volume meter with glass effect
                liquidVolumeMeter
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .glassBackgroundEffect()
        )
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .scaleEffect(controlBarScale)
        .animation(.fluidAnimation(), value: audioManager.isRunning)
        .animation(.fluidAnimation(), value: aiAnalyzer.isAnalyzing)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    private var liquidRecordButton: some View {
        Button {
            withAnimation(.fluidAnimation()) {
                if audioManager.isRunning {
                    audioManager.stop()
                    hapticEngine.stop()
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Soom stopped listening"
                    )
                } else {
                    audioManager.start()
                    hapticEngine.prepareHaptics()
                    // Trigger AI analysis when starting
                    Task {
                        _ = await aiAnalyzer.analyze(audioCategory: "active listening")
                    }
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Soom started listening. Sculptures will appear as sounds are detected."
                    )
                }
            }
        } label: {
            ZStack {
                // Liquid glass background circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 72, height: 72)
                    .glassBackgroundEffect()
                
                // Icon with dynamic styling
                Image(systemName: audioManager.isRunning ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 48, weight: .light))
                    .symbolEffect(.bounce, value: audioManager.isRunning)
                    .foregroundStyle(
                        audioManager.isRunning ? 
                            .red.gradient :
                            aiAnalyzer.currentMood.color.gradient
                    )
            }
        }
        .buttonStyle(LiquidGlassButtonStyle())
        .pressEffect(scale: 0.92)
        .accessibilityLabel(audioManager.isRunning ? "Stop listening" : "Start listening")
        .accessibilityHint(audioManager.isRunning ? "Stops capturing and analyzing sound" : "Begins capturing sound and creating Echo Sculptures")
        .accessibilityFocused($isRecordButtonFocused)
    }
    
    private var liquidVolumeMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(audioManager.isRunning ? "Listening..." : "Tap to Start")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(audioManager.isRunning ? "Soom is listening for sounds" : "Tap the record button to start Soom")
                
                Spacer()
                
                // Current mood indicator
                Circle()
                    .fill(aiAnalyzer.currentMood.color)
                    .frame(width: 8, height: 8)
                    .animation(.fluidAnimation(), value: aiAnalyzer.currentMood.color)
                    .accessibilityLabel("Current mood color: \(aiAnalyzer.currentMood.color.accessibilityName)")
            }
            
            // Liquid glass progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .accessibilityHidden(true)
                    
                    // Active progress with glass effect
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            aiAnalyzer.currentMood.color.gradient
                                .opacity(0.8 + Double(audioManager.normalizedPower) * 0.2)
                        )
                        .glassBackgroundEffect()
                        .frame(width: max(0, geometry.size.width * CGFloat(audioManager.normalizedPower)))
                        .animation(.fluidAnimation(), value: audioManager.normalizedPower)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 8)
            .frame(width: 140)
            .accessibilityLabel("Sound intensity")
            .accessibilityValue("\(Int(audioManager.normalizedPower * 100)) percent")
        }
    }
    
    private var analyzingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: aiAnalyzer.currentMood.color))
                .scaleEffect(0.8)
            
            Text("Soom Analyzing Sound...")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .accessibilityLabel("Soom is analyzing the sound")
    }
    
    private var soundClassificationIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: classificationIcon)
                .foregroundStyle(aiAnalyzer.currentMood.color)
            
            Text(audioManager.soundClassification.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .accessibilityLabel("Detected sound: \(audioManager.soundClassification.accessibilityDescription)")
    }
    
    private var classificationIcon: String {
        switch audioManager.soundClassification {
        case .speech:
            return "bubble.left.fill"
        case .laughter:
            return "face.smiling.fill"
        case .music:
            return "music.note"
        case .siren:
            return "exclamationmark.triangle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .traffic:
            return "car.fill"
        case .applause:
            return "hands.clap.fill"
        case .babyCry:
            return "figure.child"
        case .dogBark:
            return "dog.fill"
        case .doorbell:
            return "bell.fill"
        case .footsteps:
            return "shoe.fill"
        case .nature:
            return "leaf.fill"
        case .silence:
            return "speaker.slash.fill"
        case .ambient, .unknown:
            return "waveform"
        }
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
    }
}

// MARK: - Press Effect Modifier

struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false
    let scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.fluidAnimation(), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func pressEffect(scale: CGFloat = 0.95) -> some View {
        modifier(PressEffectModifier(scale: scale))
    }
}

// MARK: - Accessibility Extensions

extension SculptureShapeType {
    var accessibilityName: String {
        switch self {
        case .sphere: return "sphere"
        case .box: return "cube"
        case .torus: return "ring"
        case .pyramid: return "pyramid"
        case .cylinder: return "column"
        }
    }
}

extension SculptureMood {
    var accessibilityDescription: String {
        var desc = ""
        if roughness < 0.3 {
            desc += "smooth and polished"
        } else if roughness < 0.6 {
            desc += "balanced texture"
        } else {
            desc += "rough and textured"
        }
        
        if metallic > 0.7 {
            desc += " with metallic shine"
        }
        
        return desc
    }
}

extension Color {
    var accessibilityName: String {
        // Convert Color to UIColor for comparison
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Simple color matching
        if red > 0.8 && green < 0.5 && blue < 0.5 {
            return "red"
        } else if red > 0.8 && green > 0.5 && blue < 0.5 {
            return "orange"
        } else if red > 0.9 && green > 0.8 && blue < 0.5 {
            return "yellow"
        } else if red < 0.5 && green > 0.7 && blue < 0.5 {
            return "green"
        } else if red < 0.5 && green > 0.7 && blue > 0.7 {
            return "cyan"
        } else if red < 0.5 && green < 0.5 && blue > 0.8 {
            return "blue"
        } else if red > 0.4 && green < 0.5 && blue > 0.8 {
            return "indigo"
        } else if red > 0.8 && green < 0.5 && blue > 0.8 {
            return "purple"
        } else if red > 0.9 && green > 0.7 && blue > 0.8 {
            return "pink"
        }
        
        return "custom"
    }
}

extension AudioManager.SoundClassification {
    var displayName: String {
        return rawValue.capitalized
    }
    
    var accessibilityDescription: String {
        switch self {
        case .unknown: return "Unknown sound"
        case .silence: return "Quiet environment"
        case .speech: return "Someone speaking"
        case .laughter: return "Laughter detected"
        case .music: return "Music playing"
        case .siren: return "Siren or alarm"
        case .rain: return "Rain sounds"
        case .traffic: return "Traffic noise"
        case .applause: return "Applause"
        case .babyCry: return "Baby crying"
        case .dogBark: return "Dog barking"
        case .doorbell: return "Doorbell ringing"
        case .footsteps: return "Footsteps"
        case .nature: return "Nature sounds"
        case .ambient: return "Ambient sounds"
        }
    }
}
