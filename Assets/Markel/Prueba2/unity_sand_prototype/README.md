# Unity 6 – Sand Technical Art Prototype

This folder contains a clean starting point for the orange/terracotta night-sand prototype described in the design prompt.

## Included

- `DuneGenerator.cs`: central playable area + smooth transition + procedural mountain boundary + MeshCollider.
- `Sand.shader`: upgraded version of the existing `Custom/Sand` HLSL shader, keeping the original visual layers and adding footprints + warmer sand variation + separate grain/glitter textures + organic wind ripples.
- `SandInteractionManager.cs`: ping-pong RenderTextures that store persistent footstep impressions.
- `FootprintEmitter.cs`: distance-based footstep stamps from a player transform / optional foot bones.
- `FootstepDustEmitter.cs`: small burst of sand particles on every step.
- `SandInteractionStamp.shader`: hidden blit shader used to update the interaction map.

## Unity setup

### 1. Terrain

Create a GameObject called `DuneTerrain` and add:

- MeshFilter
- MeshRenderer
- MeshCollider
- DuneGenerator

Start with:

- Resolution: 160
- Size: 100
- Playable Radius: 20
- Transition Width: 18
- Flat Height: 0
- Flat Noise Scale: 0.10
- Flat Noise Strength: 0.35
- Mountain Base Height: 6
- Mountain Height: 16
- Mountain Noise Scale: 0.035
- Mountain Noise Strength: 1
- Mountain Octaves: 4
- Boundary Warp: 8
- Boundary Noise Scale: 0.02

Use the component context menu `Generate Terrain` when you want to regenerate while editing.

### 2. Sand material

Create a material using `Custom/Sand` from `Sand.shader`.

Assign it to the terrain MeshRenderer.

Create two small random RGB textures:

- Grain texture: used for micro normal variation.
- Glitter texture: used for sparkle orientations.

For both textures enable mipmaps and Repeat wrapping. Start with 512x512.

### 3. Interaction material

Create a material using:

`Hidden/Sand/InteractionStamp`

Assign that material to `SandInteractionManager.interactionMaterialTemplate`.

### 4. Interaction manager

Create a GameObject called `SandInteraction` and add `SandInteractionManager`.

Recommended values:

- Texture Size: 512
- World Size: same as terrain size (100)
- World Center: (0, 0, 0)
- Erosion Per Second: 0.003
- Sand Material: your `Custom/Sand` material

### 5. Player

Add `FootprintEmitter` to the player.

Assign:

- Sand Interaction
- Player Root
- Left Foot (optional)
- Right Foot (optional)
- Footstep Dust (optional)

Start with:

- Step Distance: 1.4
- Minimum Move Speed: 0.35
- Footprint Size: 0.34 x 0.65
- Footprint Strength: 0.8

Put the terrain on a `Ground` layer and set the emitter's Ground Mask accordingly.

### 6. Footstep dust

Create a regular Particle System and make it loop off. Turn off automatic emission and use a simple unlit transparent particle material.

Add `FootstepDustEmitter` somewhere convenient and assign that ParticleSystem.

The emitter is intentionally lightweight: it creates only a handful of particles per step using Unity 6 `ParticleSystem.Emit(EmitParams, count)`.

### 7. Night setup

Use a Directional Light as moonlight:

- Rotation: angled across the dunes.
- Color: slightly blue/cold.
- Intensity: tune until the sand remains warm but moonlit.

Use a large emissive-looking sphere or a billboard for the visible full moon.

For Bloom in URP, enable post-processing on the Camera and create a Global Volume with a Bloom override. Keep bloom subtle; the moon and occasional glitter can exceed 1.0 HDR while the bloom supplies the glow.

### 8. Suggested sand starting values

- Sand Color: `(0.72, 0.32, 0.12, 1)`
- Sand Variation: `0.08`
- Sand Darkness: `0.18`
- Grain Tiling: `18`
- Mip Bias: `-0.5`
- Sand Normal Strength: `0.35`
- Diffuse Y Scale: `0.3`
- Diffuse Contrast: `4`
- Ocean Strength: `0.55`
- Glitter Threshold: `0.985`
- Glitter Strength: `5`
- Ripple Strength: `0.12`
- Ripple Frequency: `7`
- Ripple Tiling: `0.08`
- Ripple Noise Strength: `0.35`
- Ripple Speed: `0.08`
- Footprint Depth: `0.3`
- Footprint Normal Strength: `0.8`
- Footprint Darkness: `0.18`

## Important prototype limitation

The footprint map is intentionally a visual interaction layer rather than a true terrain deformation system. The first milestone should be judged from the gameplay camera: the player should leave obvious but integrated depressions, darker footprints and a tiny disturbed-sand edge.

A later pass can add actual vertex displacement in the footprint area, camera-relative interaction, better foot-contact timing from animation events, and more sophisticated erosion.
