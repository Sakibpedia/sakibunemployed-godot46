# Face and Body Upgrade Documentation

## Approach: Best-Effort Procedural with MakeHuman Integration

### Current Status
- MakeHuman test OBJ export with skin/eyes/brows/lashes/teeth/hair/textures confirmed working
- Godot integration/head cropping/materials/alpha hair/orientation/scale still unproven
- No Blender available in this environment
- MakeHuman models can be exported as OBJ with full rigging data

### Disclaimer
**Avoid reproducing real celebrity likenesses.** The following uses original high-quality South Asian faces inspired by regional features (Bengali/Bangladeshi facial characteristics). Any resemblance to real persons is unintentional.

### MakeHuman to Godot Pipeline (Manual Workflow)

Since automatic Godot integration is not yet proven, the following manual pipeline is recommended:

#### 1. MakeHuman Setup
- Create character in MakeHuman with:
  - South Asian facial features (high cheekbones, broader nose base, darker skin tone)
  - Realistic eye shape and color
  - Detailed eyebrows, eyelashes
  - Natural hair styles appropriate for the region
- Export as OBJ with:
  - Skin texture
  - Eye textures
  - Brow/lash textures
  - Tooth textures
  - Hair texture with alpha channel
  - Full skeleton rig

#### 2. Godot Import Settings
- Import OBJ as `ResourceSaver`
- Convert to `MeshInstance3D` with `PolygonMesh`
- Import as `AnimatedSprite3D` or `VRM` if available
- Important: The OBJ forward direction is typically `-Z`, Godot expects `+Y` up
- Apply the following transform to correct orientation:
  ```gdscript
  Basis(Vector3.UP, -90)  # Rotate from MakeHuman's -Z forward to Godot's +Y forward
  ```

#### 3. Head Cropping and Scaling
- MakeHuman body is full height (~1.7m); need to crop to head/shoulders
- Scale factor: heads are typically ~0.25m in MakeHuman, need ~0.14m in Godot
- Use Godot's `Viewport` to capture head texture region
- Apply shader to mask body and show only head/neck

#### 4. Material Setup
- Use `StandardMaterial3D` with:
  - `albedo_texture` from MakeHuman head texture
  - `roughness` ~0.3 for skin
  - `metallic` ~0.1 for skin
- For hair: `Transparency` set to `ALPHA`, `cull_mode` = `CULL_DISABLED`
- Apply `shader` to handle alpha-hair properly

#### 5. Alternative: Pure Procedural Approach
If MakeHuman integration proves too complex, use procedural generation:

```gdscript
func generate_south_asian_face() -> Dictionary:
    """Generate a random but realistic South Asian facial feature set."""
    features = {
        "eye_shape": ["almond", "round", "hooded"][rng.randi_range(0, 2)],
        "nose_width": rng.randf(0.8, 1.3),
        "cheekbone_height": rng.randf(0.6, 1.0),
        "lip_thickness": rng.randf(0.4, 0.8),
        "skin_tone": Color(
            rng.randf(0.65, 0.85),  # R
            rng.randf(0.55, 0.75),  # G  
            rng.randf(0.45, 0.65)   # B
        )
    }
    return features
```

### Body Anatomy Improvement
- Current humanoid rig: standard capsule controller (r=0.3, h=1.76)
- Improvements planned:
  - Better step height adaptation for stairs
  - Capsule sliding on railings and edges
  - Animatable joint systems for gestures
  - Dress overlay system for different outfits

### Priority
1. **First**: Get core gameplay working with current assets
2. **Second**: Integrate MakeHuman heads (manual pipeline)
3. **Third**: Improve procedural face diversity if time permits
4. **Fourth**: Body animation refinements

### Next Steps
1. Test MakeHuman OBJ import into Godot 4.6
2. Create a "prototype head" with correct scaling
3. Document the exact transform chain needed
4. Create fallback procedural faces for minor characters
5. Test with actual gameplay scenes