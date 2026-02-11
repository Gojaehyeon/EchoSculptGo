import AVFoundation
import SoundAnalysis
import Combine

/// Captures real-time microphone input via AVAudioEngine and provides accurate
/// sound classification using the SoundAnalysis framework.
/// Publishes normalized audio power levels and detected sound classifications.
@MainActor
final class AudioManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning = false

    /// Audio power normalized to 0...1 range (silent...loud).
    @Published private(set) var normalizedPower: Float = 0
    
    /// Real-time frequency band analysis for visual effects
    @Published private(set) var frequencyBands: FrequencyBands = .init()
    
    /// Detected sound classification from SoundAnalysis framework
    @Published private(set) var soundClassification: SoundClassification = .unknown
    
    /// Detailed classification results with confidence scores
    @Published private(set) var classificationResults: [SoundClassifierResult] = []
    
    /// Callback for audio category changes - used to trigger AI analysis
    var onCategoryChange: ((AudioCategory) -> Void)?

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private var displayLink: CADisplayLink?
    private var soundAnalyzer: SNAudioStreamAnalyzer?
    private var analysisQueue = DispatchQueue(label: "com.soom.soundanalysis", qos: .userInitiated)
    
    /// Smoothed RMS value updated from the audio tap.
    private var currentRMS: Float = 0
    
    /// Power history for pattern detection
    private var powerHistory: [Float] = []
    private let historySize = 30
    private var lastCategory: AudioCategory = .silent
    
    /// FFT setup for frequency analysis
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize = 1024
    
    // MARK: - Sound Classification Types
    
    /// Environmental sound classifications supported by Soom
    enum SoundClassification: String, CaseIterable {
        case unknown = "unknown"
        case silence = "silence"
        case speech = "speech"
        case laughter = "laughter"
        case music = "music"
        case siren = "siren"
        case rain = "rain"
        case traffic = "traffic"
        case applause = "applause"
        case babyCry = "baby crying"
        case dogBark = "dog bark"
        case doorbell = "doorbell"
        case footsteps = "footsteps"
        case nature = "nature sounds"
        case ambient = "ambient"
        
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
    
    /// Frequency bands for visual effects
    struct FrequencyBands: Sendable {
        var low: Float = 0      // 20-250 Hz
        var mid: Float = 0      // 250-2000 Hz
        var high: Float = 0     // 2000-8000 Hz
        var veryHigh: Float = 0 // 8000+ Hz
        
        var maxBand: Float {
            return max(low, mid, high, veryHigh)
        }
    }
    
    /// Classification result with confidence
    struct SoundClassifierResult: Identifiable, Sendable {
        let id = UUID()
        let classification: SoundClassification
        let confidence: Double
    }

    // MARK: - Audio Category (Legacy Support)
    
    /// Categories of audio for AI mood mapping
    enum AudioCategory: String, CaseIterable {
        case silent = "silent"
        case calm = "calm whisper"
        case ambient = "ambient sound"
        case speech = "human speech"
        case music = "musical tones"
        case energetic = "energetic loud"
        case intense = "intense peak"
        
        var description: String {
            return rawValue
        }
        
        /// Maps sound classification to audio category
        init(from classification: SoundClassification) {
            switch classification {
            case .silence, .unknown:
                self = .silent
            case .rain, .nature:
                self = .calm
            case .ambient, .traffic, .footsteps:
                self = .ambient
            case .speech, .laughter, .babyCry:
                self = .speech
            case .music:
                self = .music
            case .applause, .doorbell, .dogBark:
                self = .energetic
            case .siren:
                self = .intense
            }
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        configureSession()
        setupSoundAnalysis()
        installTap()
        do {
            try audioEngine.start()
            startDisplayLink()
            isRunning = true
        } catch {
            print("[Soom AudioManager] Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        
        // Stop sound analysis
        if let analyzer = soundAnalyzer {
            analyzer.removeAllRequests()
            soundAnalyzer = nil
        }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
        normalizedPower = 0
        currentRMS = 0
        frequencyBands = FrequencyBands()
        soundClassification = .unknown
        classificationResults = []
    }

    // MARK: - Audio Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
        } catch {
            print("[Soom AudioManager] Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Sound Analysis Setup
    
    private func setupSoundAnalysis() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        soundAnalyzer = SNAudioStreamAnalyzer(format: format)
        
        // Create sound classification request
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            try soundAnalyzer?.add(request, withObserver: self)
        } catch {
            print("[Soom AudioManager] Failed to setup sound classification: \(error)")
        }
    }

    // MARK: - AVAudioEngine Tap

    private func installTap() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: UInt32(fftSize), format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            self.analyzeAudioBuffer(buffer)
        }
    }
    
    /// Analyzes audio buffer for power and frequency content
    private func analyzeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (root mean square) for the buffer.
        var sumOfSquares: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumOfSquares += sample * sample
        }
        let rms = sqrtf(sumOfSquares / Float(frameLength))
        
        // Convert RMS to a dB-like normalized value clamped to 0...1.
        let minDb: Float = -60
        let db = 20 * log10f(max(rms, 1e-7))
        let clamped = max(minDb, min(db, 0))
        let normalized = (clamped - minDb) / (0 - minDb)
        
        // Perform frequency analysis
        let bands = performFrequencyAnalysis(channelData, frameLength: frameLength, sampleRate: Float(buffer.format.sampleRate))
        
        Task { @MainActor [weak self] in
            self?.currentRMS = normalized
            self?.frequencyBands = bands
        }
    }
    
    /// Performs FFT-based frequency analysis
    private func performFrequencyAnalysis(_ data: UnsafePointer<Float>, frameLength: Int, sampleRate: Float) -> FrequencyBands {
        guard frameLength >= fftSize else { return FrequencyBands() }
        
        var realInput = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        
        // Copy audio data to real input
        for i in 0..<fftSize {
            realInput[i] = data[i] * hanningWindow(i, size: fftSize)
        }
        
        // Perform FFT using Accelerate framework
        guard let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) else {
            return FrequencyBands()
        }
        defer { vDSP_DFT_DestroySetupD(fftSetup) }
        
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)
        
        vDSP_DFT_Execute(fftSetup, realInput, imaginary, &realOutput, &imagOutput)
        
        // Calculate magnitudes
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrtf(realOutput[i] * realOutput[i] + imagOutput[i] * imagOutput[i])
        }
        
        // Calculate frequency bands
        let binSize = sampleRate / Float(fftSize)
        var lowSum: Float = 0, midSum: Float = 0, highSum: Float = 0, veryHighSum: Float = 0
        var lowCount = 0, midCount = 0, highCount = 0, veryHighCount = 0
        
        for i in 0..<fftSize/2 {
            let frequency = Float(i) * binSize
            
            if frequency < 250 {
                lowSum += magnitudes[i]
                lowCount += 1
            } else if frequency < 2000 {
                midSum += magnitudes[i]
                midCount += 1
            } else if frequency < 8000 {
                highSum += magnitudes[i]
                highCount += 1
            } else if frequency < 20000 {
                veryHighSum += magnitudes[i]
                veryHighCount += 1
            }
        }
        
        // Normalize bands
        let normalize: (Float, Int) -> Float = { sum, count in
            guard count > 0 else { return 0 }
            return min(sum / Float(count) * 10, 1.0)
        }
        
        return FrequencyBands(
            low: normalize(lowSum, lowCount),
            mid: normalize(midSum, midCount),
            high: normalize(highSum, highCount),
            veryHigh: normalize(veryHighSum, veryHighCount)
        )
    }
    
    private func hanningWindow(_ index: Int, size: Int) -> Float {
        return 0.5 - 0.5 * cosf(2.0 * .pi * Float(index) / Float(size - 1))
    }

    // MARK: - Display Link (UI refresh)

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Smooth the power value for fluid animation.
                let smoothing: Float = 0.3
                self.normalizedPower = self.normalizedPower * (1 - smoothing) + self.currentRMS * smoothing
                
                // Detect audio category based on power levels
                self.detectAudioCategory()
            }
        }, selector: #selector(DisplayLinkTarget.tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    // MARK: - Audio Category Detection
    
    private func detectAudioCategory() {
        // Add current power to history
        powerHistory.append(normalizedPower)
        if powerHistory.count > historySize {
            powerHistory.removeFirst()
        }
        
        guard powerHistory.count >= 10 else { return }
        
        // Calculate statistics
        let average = powerHistory.reduce(0, +) / Float(powerHistory.count)
        let maxPower = powerHistory.max() ?? 0
        let variance = powerHistory.map { pow($0 - average, 2) }.reduce(0, +) / Float(powerHistory.count)
        
        // Determine category based on power characteristics
        let newCategory: AudioCategory
        
        if maxPower < 0.05 {
            newCategory = .silent
        } else if maxPower < 0.2 && variance < 0.01 {
            newCategory = .calm
        } else if maxPower < 0.4 && variance < 0.02 {
            newCategory = .ambient
        } else if maxPower < 0.5 && variance > 0.03 {
            newCategory = .speech
        } else if maxPower < 0.6 && variance > 0.02 {
            newCategory = .music
        } else if maxPower < 0.8 {
            newCategory = .energetic
        } else {
            newCategory = .intense
        }
        
        // Only update if category changed
        if newCategory != lastCategory {
            lastCategory = newCategory
            onCategoryChange?(newCategory)
        }
    }
}

// MARK: - SNResultsObserving

extension AudioManager: SNResultsObserving {
    nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        
        // Get top classifications
        let topClassifications = result.classifications.prefix(3)
        var results: [SoundClassifierResult] = []
        var topClassification: SoundClassification = .unknown
        var maxConfidence: Double = 0
        
        for classification in topClassifications {
            let identifier = classification.identifier.lowercased()
            let confidence = classification.confidence
            
            // Map SNClassification to Soom's SoundClassification
            let soomClassification = mapClassification(identifier)
            results.append(SoundClassifierResult(
                classification: soomClassification,
                confidence: confidence
            ))
            
            if confidence > maxConfidence {
                maxConfidence = confidence
                topClassification = soomClassification
            }
        }
        
        Task { @MainActor in
            if maxConfidence > 0.3 {
                self.soundClassification = topClassification
                self.classificationResults = results
            }
        }
    }
    
    nonisolated func request(_ request: SNRequest, didFailWithError error: Error) {
        print("[Soom AudioManager] Sound analysis failed: \(error)")
    }
    
    nonisolated func requestDidComplete(_ request: SNRequest) {
        // Analysis completed
    }
    
    /// Maps SoundAnalysis framework classifications to Soom's classifications
    private func mapClassification(_ identifier: String) -> SoundClassification {
        switch identifier {
        case let id where id.contains("speech"):
            return .speech
        case let id where id.contains("laughter"):
            return .laughter
        case let id where id.contains("music"):
            return .music
        case let id where id.contains("siren") || id.contains("alarm"):
            return .siren
        case let id where id.contains("rain"):
            return .rain
        case let id where id.contains("traffic") || id.contains("vehicle"):
            return .traffic
        case let id where id.contains("applause") || id.contains("clapping"):
            return .applause
        case let id where id.contains("baby") || id.contains("cry"):
            return .babyCry
        case let id where id.contains("dog") || id.contains("bark"):
            return .dogBark
        case let id where id.contains("doorbell") || id.contains("door"):
            return .doorbell
        case let id where id.contains("footstep") || id.contains("walk"):
            return .footsteps
        case let id where id.contains("nature") || id.contains("bird") || id.contains("wind"):
            return .nature
        case let id where id.contains("silence") || id.contains("quiet"):
            return .silence
        default:
            return .ambient
        }
    }
}

// MARK: - DisplayLink Helper

private class DisplayLinkTarget {
    let callback: () -> Void

    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }

    @objc func tick() {
        callback()
    }
}

// MARK: - Accelerate Framework Import

import Accelerate
