import SwiftUI
import RealityKit

/// A RealityKit-powered view that renders a 3D sphere whose scale reacts to real-time microphone levels.
struct ImmersiveView: View {
    @EnvironmentObject var audioManager: AudioManager

    @State private var sculptureEntity: ModelEntity?

    var body: some View {
        RealityView { content in
            let entity = makeSphereEntity()
            content.add(entity)
            sculptureEntity = entity
        }
        .onChange(of: audioManager.normalizedPower) { _, newValue in
            updateSphere(power: newValue)
        }
    }

    // MARK: - Sphere Factory

    private func makeSphereEntity() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: 0.08)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .cyan)
        material.roughness = .init(floatLiteral: 0.15)
        material.metallic = .init(floatLiteral: 0.8)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.85))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = SIMD3<Float>(0, 0, -0.5)
        return entity
    }

    // MARK: - Scale Update

    private func updateSphere(power: Float) {
        guard let entity = sculptureEntity else { return }

        let baseScale: Float = 1.0
        let scaleBoost: Float = 1.0 + power * 2.0
        let uniformScale = baseScale * scaleBoost

        entity.transform.scale = SIMD3<Float>(repeating: uniformScale)
    }
}
