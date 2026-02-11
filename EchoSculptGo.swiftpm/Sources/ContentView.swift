import SwiftUI

/// The main content view hosting the immersive 3D sculpture and audio controls.
struct ContentView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ZStack {
            ImmersiveView()
                .environmentObject(audioManager)
                .ignoresSafeArea()

            VStack {
                Spacer()
                controlBar
            }
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 24) {
            Button {
                if audioManager.isRunning {
                    audioManager.stop()
                } else {
                    audioManager.start()
                }
            } label: {
                Image(systemName: audioManager.isRunning ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Volume")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(audioManager.normalizedPower))
                    .tint(.cyan)
                    .frame(width: 120)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.bottom, 40)
    }
}
