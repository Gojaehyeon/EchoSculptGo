# PRD - Soom

## 1. Project Vision
**Soom** (숨, meaning "breath" in Korean) aims to bridge the sensory gap for the hearing impaired by transforming sound into "Echo Sculptures"—fluid, 3D visual representations that capture not just the presence of sound, but its texture, emotion, and intensity. Using the 2026 Liquid Glass design language, it creates an intuitive, artistic, and functional accessibility experience.

## 2. Problem Statement
Existing sound-to-text apps focus on "information" (speech). However, sound is also "atmosphere" and "emotion." The hearing impaired miss out on the laughter at a party, the intensity of a siren, or the calm of a rainy day.

## 3. Key Features
- **Sound-to-Sculpture Synthesis**: Real-time sound analysis using Core ML to identify sound categories (laughter, music, traffic, alarm).
- **Semantic Texture Mapping**: On-device Foundation Models describe the "mood" of the sound (e.g., "warm and rhythmic" or "sharp and urgent").
- **Liquid Glass Visualization**: RealityKit renders dynamic 3D shapes with glass-like textures that react to sound frequencies and semantic moods.
- **Haptic Echo**: Taptic Engine pulses synchronized with the visual "sculpture" to provide a tactile sense of the sound's rhythm.

## 4. Technical Stack
- **Platform**: iOS 26+
- **UI**: SwiftUI (using 2026 Liquid Glass modifiers)
- **3D Engine**: RealityKit + Metal
- **AI/ML**: Core ML (Sound Analysis) + Foundation Models (Contextual reasoning)
- **Haptics**: Core Haptics

## 5. 3-Minute SSC Scenario
1. **Introduction**: Brief context about "feeling" sound.
2. **Real-time Demo**: App identifies background sounds (clapping, snapping) and creates instant sculptures.
3. **Emotional Playback**: Play a pre-recorded emotional clip (e.g., a baby's laugh), showing how the sculpture becomes "soft and bubbly."
4. **Conclusion**: Impact statement on inclusivity.

---

# Development Plan

## Phase 1: AR & UI Setup
- Initialize `.swiftpm` with RealityKit support.
- Implement the "Liquid Glass" container view in SwiftUI.
- Setup basic ARView for 3D object placement.

## Phase 2: Sound Processing
- Integrate `SoundAnalysis` framework.
- Map decibels and frequency to object scale and movement.

## Phase 3: Semantic Layer
- Implement `FoundationModels` to categorize sound "textures."
- Change 3D shader parameters (color, refraction, roughness) based on AI categories.

## Phase 4: Final Polish
- Refine physical animations for the 3D objects.
- Add Haptic feedback patterns.
- Final Accessibility audit.
