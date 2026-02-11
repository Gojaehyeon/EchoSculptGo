import AVFoundation
import Combine

/// Captures real-time microphone input via AVAudioEngine and exposes normalized audio power levels.
@MainActor
final class AudioManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning = false

    /// Audio power normalized to 0...1 range (silent...loud).
    @Published private(set) var normalizedPower: Float = 0

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private var displayLink: CADisplayLink?

    /// Smoothed RMS value updated from the audio tap.
    private var currentRMS: Float = 0

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        configureSession()
        installTap()
        do {
            try audioEngine.start()
            startDisplayLink()
            isRunning = true
        } catch {
            print("[AudioManager] Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
        normalizedPower = 0
        currentRMS = 0
    }

    // MARK: - Audio Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
        } catch {
            print("[AudioManager] Failed to configure audio session: \(error)")
        }
    }

    // MARK: - AVAudioEngine Tap

    private func installTap() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
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

            Task { @MainActor [weak self] in
                self?.currentRMS = normalized
            }
        }
    }

    // MARK: - Display Link (UI refresh)

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Smooth the power value for fluid animation.
                let smoothing: Float = 0.3
                self.normalizedPower = self.normalizedPower * (1 - smoothing) + self.currentRMS * smoothing
            }
        }, selector: #selector(DisplayLinkTarget.tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
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
