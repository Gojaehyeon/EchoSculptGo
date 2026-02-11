import SwiftUI
import RealityKit
import MetalKit

/// A RealityKit-powered view that renders a 3D sculpture whose appearance
/// dynamically changes based on AI-analyzed mood and real-time microphone levels.
/// Features Liquid Glass shaders and particle effects that react to frequency bands.
struct ImmersiveView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var aiAnalyzer: AIAnalyzer
    @EnvironmentObject var hapticEngine: HapticEngine
    
    @State private var sculptureEntity: ModelEntity?
    @State private var particleEntity: Entity?
    @State private var currentMaterial: PhysicallyBasedMaterial?
    
    // MARK: - Animation States
    @State private var targetScale: Float = 1.0
    @State private var currentScale: Float = 1.0
    @State private var rotationAngle: Float = 0
    @State private var time: Float = 0
    
    // MARK: - Frequency-Based Visual States
    @State private var lowFreqPulse: Float = 0
    @State private var midFreqWave: Float = 0
    @State private var highFreqSparkle: Float = 0
    @State private var veryHighFreqGlow: Float = 0

    var body: some View {
        RealityView { content in
            // Create initial sculpture with Liquid Glass material
            let entity = createSculptureEntity(mood: aiAnalyzer.currentMood)
            content.add(entity)
            sculptureEntity = entity
            
            // Create particle system
            let particles = createParticleSystem(mood: aiAnalyzer.currentMood)
            content.add(particles)
            particleEntity = particles
            
            // Add lighting for better material visibility
            setupLighting(content: content)
            
            // Add environment for reflections
            setupEnvironment(content: content)
            
        } update: { content in
            // Update when mood changes
            updateSculptureMaterial()
            updateParticleSystem()
        }
        .onChange(of: audioManager.normalizedPower) { _, newValue in
            updateSculptureScale(power: newValue)
            updateHapticFeedback(power: newValue)
        }
        .onChange(of: audioManager.frequencyBands) { _, newBands in
            updateFrequencyBasedEffects(bands: newBands)
        }
        .onChange(of: audioManager.soundClassification) { _, newClassification in
            handleClassificationChange(newClassification)
        }
        .onChange(of: aiAnalyzer.currentMood) { _, newMood in
            handleMoodChange(newMood)
        }
        .onAppear {
            // Start subtle rotation animation
            startRotationAnimation()
            startTimeAnimation()
        }
    }
    
    // MARK: - Sculpture Creation
    
    private func createSculptureEntity(mood: SculptureMood) -> ModelEntity {
        let mesh = generateMesh(for: mood.shapeType)
        let material = createLiquidGlassMaterial(for: mood)
        currentMaterial = material
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = SIMD3<Float>(0, 0, -0.5)
        entity.name = "soomSculpture"
        
        // Add collision for interaction
        entity.generateCollisionShapes(recursive: false)
        
        return entity
    }
    
    /// Generates the appropriate mesh based on shape type
    private func generateMesh(for shapeType: SculptureShapeType) -> MeshResource {
        switch shapeType {
        case .sphere:
            return MeshResource.generateSphere(radius: 0.08)
        case .box:
            return MeshResource.generateBox(size: 0.16)
        case .torus:
            return MeshResource.generateTorus(
                innerRadius: 0.04,
                outerRadius: 0.08
            )
        case .pyramid:
            // Custom pyramid using cone with 4 segments
            return MeshResource.generateCone(
                height: 0.16,
                radius: 0.08
            )
        case .cylinder:
            return MeshResource.generateCylinder(
                height: 0.16,
                radius: 0.08
            )
        }
    }
    
    /// Creates a Liquid Glass PBR material based on the mood parameters
    private func createLiquidGlassMaterial(for mood: SculptureMood) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        
        // Convert SwiftUI Color to UIColor then to PhysicallyBasedMaterial color
        let uiColor = UIColor(mood.color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Base color with subtle tint
        material.baseColor = .init(
            tint: .init(
                red: Float(red),
                green: Float(green),
                blue: Float(blue),
                alpha: Float(alpha)
            )
        )
        
        // Physical properties for Liquid Glass effect
        material.roughness = .init(floatLiteral: mood.roughness * 0.3) // Very smooth
        material.metallic = .init(floatLiteral: mood.metallic)
        
        // Glass-like refraction effect - higher refraction for more "liquid" look
        let opacity = max(0.1, 1.0 - mood.refraction * 0.7)
        material.blending = .transparent(opacity: .init(floatLiteral: Float(opacity)))
        
        // Specular highlights for glass-like appearance
        material.specular = .init(floatLiteral: 1.0)
        
        // Clear coat for liquid glass effect
        material.clearcoat = .init(floatLiteral: 1.0)
        material.clearcoatRoughness = .init(floatLiteral: 0.05)
        
        // Anisotropic reflections for liquid effect
        material.anisotropicAngle = .init(floatLiteral: 0.5)
        material.anisotropicScale = .init(floatLiteral: 0.3)
        
        // Subsurface scattering for translucency
        material.subsurface = .init(floatLiteral: mood.refraction * 0.5)
        
        return material
    }
    
    // MARK: - Particle System
    
    private func createParticleSystem(mood: SculptureMood) -> Entity {
        let particleEntity = Entity()
        particleEntity.position = SIMD3<Float>(0, 0, -0.5)
        particleEntity.name = "soomParticles"
        
        // Create particle emitter component
        var emitter = ParticleEmitterComponent()
        
        // Configure particle settings for frequency-reactive effects
        emitter.emitterShape = .sphere(radius: 0.1)
        emitter.birthRate = 50
        emitter.emissionDuration = .infinity
        emitter.idleDuration = 0
        
        // Particle appearance
        emitter.particleColor = .single(mood.color.toRealityKitColor() ?? .white)
        emitter.particleColorEvolution = .init(
            initialColor: mood.color.toRealityKitColor() ?? .white,
            finalColor: .init(red: 1, green: 1, blue: 1, alpha: 0)
        )
        
        // Size and lifetime
        emitter.particleSize = 0.005
        emitter.sizeGrowthSpeed = 0.5
        emitter.lifespan = 1.5
        
        // Velocity and acceleration
        emitter.mainEmitter.velocity = SIMD3<Float>(0, 0.05, 0)
        emitter.mainEmitter.acceleration = SIMD3<Float>(0, 0.02, 0)
        
        // Add some spread
        emitter.mainEmitter.spreadingAngle = .degrees(45)
        
        // Add physics
        emitter.simulationSpace = .world
        
        particleEntity.components[ParticleEmitterComponent.self] = emitter
        
        return particleEntity
    }
    
    // MARK: - Lighting Setup
    
    private func setupLighting(content: RealityViewContent) {
        // Add ambient light for base illumination
        let ambientLight = Entity()
        ambientLight.components[AmbientLightComponent.self] = AmbientLightComponent(
            color: .white,
            intensity: 0.4
        )
        content.add(ambientLight)
        
        // Add directional light for shadows and depth
        let directionalLight = Entity()
        directionalLight.components[DirectionalLightComponent.self] = DirectionalLightComponent(
            color: .white,
            intensity: 2.0,
            isRealWorldProxy: false
        )
        directionalLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, -1, 0])
        content.add(directionalLight)
        
        // Add point light near the sculpture for glass highlights
        let pointLight = Entity()
        pointLight.position = SIMD3<Float>(0.3, 0.3, -0.3)
        pointLight.components[PointLightComponent.self] = PointLightComponent(
            color: aiAnalyzer.currentMood.color.toRealityKitColor() ?? .white,
            intensity: 150,
            attenuationRadius: 2.0
        )
        pointLight.name = "soomMoodLight"
        content.add(pointLight)
        
        // Add rim light for edge highlighting
        let rimLight = Entity()
        rimLight.position = SIMD3<Float>(-0.4, 0.2, -0.6)
        rimLight.components[PointLightComponent.self] = PointLightComponent(
            color: .white,
            intensity: 100,
            attenuationRadius: 1.5
        )
        rimLight.name = "soomRimLight"
        content.add(rimLight)
    }
    
    // MARK: - Environment Setup
    
    private func setupEnvironment(content: RealityViewContent) {
        // Configure environment for better reflections
        var environment = EnvironmentComponent()
        environment.background = .color(.black)
        environment.lighting = .none
        
        let environmentEntity = Entity()
        environmentEntity.components[EnvironmentComponent.self] = environment
        content.add(environmentEntity)
    }
    
    // MARK: - Dynamic Updates
    
    private func updateSculptureScale(power: Float) {
        targetScale = 1.0 + power * 2.5
        
        // Smooth interpolation using fluid animation concept
        withAnimation(.fluidAnimation()) {
            currentScale = currentScale * 0.7 + targetScale * 0.3
        }
        
        sculptureEntity?.transform.scale = SIMD3<Float>(repeating: currentScale)
        
        // Add subtle wobble based on power
        let wobble = sin(time * 3) * power * 0.1
        sculptureEntity?.transform.rotation *= simd_quatf(angle: wobble, axis: [1, 0, 0])
        
        // Update light intensity based on audio
        if let pointLight = sculptureEntity?.parent?.findEntity(named: "soomMoodLight") {
            let lightIntensity = 100 + Int(power * 200)
            pointLight.components[PointLightComponent.self]?.intensity = lightIntensity
        }
    }
    
    private func updateFrequencyBasedEffects(bands: AudioManager.FrequencyBands) {
        // Update frequency-based visual states with smoothing
        lowFreqPulse = lowFreqPulse * 0.8 + bands.low * 0.2
        midFreqWave = midFreqWave * 0.8 + bands.mid * 0.2
        highFreqSparkle = highFreqSparkle * 0.8 + bands.high * 0.2
        veryHighFreqGlow = veryHighFreqGlow * 0.8 + bands.veryHigh * 0.2
        
        guard let entity = sculptureEntity else { return }
        
        // Apply frequency-based deformations
        var transform = entity.transform
        
        // Low frequency creates pulsing scale
        let pulse = 1.0 + lowFreqPulse * 0.3
        transform.scale.x = currentScale * pulse
        transform.scale.y = currentScale * (1.0 / pulse) // Conservation of volume
        
        // Mid frequency creates wave rotation
        let waveRotation = simd_quatf(angle: midFreqWave * 0.2, axis: [0, 1, 0])
        transform.rotation = waveRotation * transform.rotation
        
        entity.transform = transform
        
        // Update particle system based on high frequencies
        if var emitter = particleEntity?.components[ParticleEmitterComponent.self] {
            // Higher frequencies increase particle birth rate
            emitter.birthRate = 30 + Int(highFreqSparkle * 150)
            
            // Very high frequencies affect particle speed
            let speedMultiplier = 1.0 + veryHighFreqGlow * 2.0
            emitter.mainEmitter.velocity = SIMD3<Float>(
                sin(time * 2) * 0.02 * speedMultiplier,
                0.05 * speedMultiplier,
                cos(time * 2) * 0.02 * speedMultiplier
            )
            
            particleEntity?.components[ParticleEmitterComponent.self] = emitter
        }
    }
    
    private func updateHapticFeedback(power: Float) {
        hapticEngine.updateIntensity(power)
    }
    
    private func handleClassificationChange(_ classification: AudioManager.SoundClassification) {
        // Update haptic pattern based on sound classification
        let pattern = hapticEngine.patternForSoundClassification(classification)
        hapticEngine.playPattern(pattern, intensity: audioManager.normalizedPower)
        
        // Trigger AI analysis for new classification
        Task {
            _ = await aiAnalyzer.analyze(audioCategory: classification.rawValue)
        }
    }
    
    private func handleMoodChange(_ newMood: SculptureMood) {
        guard let entity = sculptureEntity else { return }
        
        // Update haptic pattern for new mood
        let pattern = hapticEngine.patternForMood(newMood)
        hapticEngine.playPattern(pattern, intensity: audioManager.normalizedPower)
        
        // Animate shape change with morphing effect
        withAnimation(.fluidAnimation(duration: 1.0)) {
            // Update the mesh for shape change
            let newMesh = generateMesh(for: newMood.shapeType)
            entity.model?.mesh = newMesh
            
            // Update material properties with Liquid Glass effect
            let newMaterial = createLiquidGlassMaterial(for: newMood)
            entity.model?.materials = [newMaterial]
            currentMaterial = newMaterial
            
            // Update lighting color
            if let pointLight = entity.parent?.findEntity(named: "soomMoodLight") {
                pointLight.components[PointLightComponent.self]?.color = newMood.color.toRealityKitColor() ?? .white
            }
        }
        
        // Update particle system color
        if var emitter = particleEntity?.components[ParticleEmitterComponent.self] {
            emitter.particleColor = .single(newMood.color.toRealityKitColor() ?? .white)
            emitter.particleColorEvolution = .init(
                initialColor: newMood.color.toRealityKitColor() ?? .white,
                finalColor: .init(red: 1, green: 1, blue: 1, alpha: 0)
            )
            particleEntity?.components[ParticleEmitterComponent.self] = emitter
        }
    }
    
    private func updateSculptureMaterial() {
        // Called during RealityView update cycle
        // Continuous material updates based on frequency bands
        guard let material = currentMaterial else { return }
        
        // Adjust roughness based on high frequencies (sparkle effect)
        var updatedMaterial = material
        updatedMaterial.roughness = .init(floatLiteral: max(0.05, aiAnalyzer.currentMood.roughness * 0.3 - highFreqSparkle * 0.1))
        
        // Adjust subsurface scattering based on low frequencies (glow effect)
        updatedMaterial.subsurface = .init(floatLiteral: aiAnalyzer.currentMood.refraction * 0.5 + lowFreqPulse * 0.3)
        
        sculptureEntity?.model?.materials = [updatedMaterial]
    }
    
    private func updateParticleSystem() {
        // Called during RealityView update cycle
        // Particle updates are handled in updateFrequencyBasedEffects
    }
    
    // MARK: - Animation
    
    private func startRotationAnimation() {
        // Continuous subtle rotation using timer
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, let entity = self.sculptureEntity else { return }
            
            self.rotationAngle += 0.005 + self.midFreqWave * 0.02
            let rotation = simd_quatf(angle: self.rotationAngle, axis: [0, 1, 0])
            let wobble = simd_quatf(angle: sin(self.rotationAngle * 2) * 0.05 * (1 + self.lowFreqPulse), axis: [1, 0, 0])
            
            entity.orientation = rotation * wobble
        }
    }
    
    private func startTimeAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.time += 0.05
        }
    }
}

// MARK: - Color Extension

extension Color {
    /// Converts SwiftUI Color to RealityKit color format
    func toRealityKitColor() -> RealityKit.Material.Color? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return RealityKit.Material.Color(
            red: Float(red),
            green: Float(green),
            blue: Float(blue),
            alpha: Float(alpha)
        )
    }
}

// MARK: - Animation Extension

extension Animation {
    /// Fluid animation for Liquid Glass design language
    static func fluidAnimation(duration: TimeInterval = 0.4) -> Animation {
        .spring(response: duration, dampingFraction: 0.85, blendDuration: 0.2)
    }
}
