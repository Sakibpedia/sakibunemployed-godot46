# Rendering architecture — "S M Nazmuz Sakib is unemployed" (Godot 4.6, Forward+)

Developed by S M Nazmuz Sakib. © 2026 S M Nazmuz Sakib. All rights reserved.

Phase 1 set up the look of Dhaka: the frame pipeline, the environment and light configuration, quality tiers, the surface, face and cloth materials, the texture factory and the SVG interface kit. Phase 2 fixed the blur and haze, and added the open-world facade, parapet, road and ghost shaders. **Section 0 lists the Phase 2 changes; where it disagrees with a later section, section 0 is current.** Every number here is also in code; the code is the source of truth.

| File | What it does |
|---|---|
| `scripts/rendering/DhakaAtmosphere.gd` | Builds WorldEnvironment, sky, sun, moon, smog volume and dust; runs time of day |
| `scripts/rendering/RenderQuality.gd` | Four quality tiers (viewport, RenderingServer, Environment); saves the choice |
| `scripts/rendering/DhakaMaterials.gd` | Turns `art/textures` into cached materials: surfaces, faces, cloth, awnings, grille, decals |
| `shaders/dhaka_surface.gdshader` | Triplanar world-space PBR with street grime, soot runs and dust |
| `shaders/dhaka_facade.gdshader` | Phase 2: procedural Dhaka facades on every building (windows, grilles, sunshades, shutters, night windows) |
| `shaders/dhaka_road.gdshader` | Phase 2: asphalt with lane markings, zebra crossings and repairs |
| `shaders/ghost.gdshader` | Phase 2: additive translucent ghosts with a fresnel edge and dawn burn |
| `tools/generate_textures.py` | Pillow + numpy texture factory (all PBR maps, faces, sky cover) |
| `tools/generate_ui_svgs.py` | Writes the 37-file SVG interface kit |
| `project.godot` `[rendering]` | Project-wide defaults, close to the High tier; the saved tier overrides them at runtime |

---

## 0. Phase 2 changes (current)

### The blur and haze fix

The Phase 1 Low tier rendered at 67 % with FSR 1 and FXAA, and every tier added height fog, far depth of
field and a bloom wash. Together that made the whole frame soft and foggy. Phase 2:

| | Phase 1 | Phase 2 |
|---|---|---|
| Resolution | FSR at 67–77 % on Low to High | **native on every tier**; render scale is a separate opt-in setting (100 %, 85 %, 70 %) |
| Anti-aliasing | FXAA / FSR 2 temporal | **SMAA** on every tier; MSAA 2× on High, 4× on Ultra; no TAA |
| Distance haze | exponential height fog, density 0.04 at 25 m | **depth fog**: starts at `fog_b`, reaches `fog_max` opacity at `fog_e` (curve 1.6), no height density; ×0.3 indoors |
| Depth of field | far DOF from 90 m | **off** |
| Glow | bloom 0.08, threshold 0.9, intensity 0.55 | **bloom 0**, threshold 1.1, intensity 0.3 (only real highlights glow) |
| Tone mapping | AgX, white 6 | **ACES** (punchier, more saturated daylight) |
| Auto exposure | sensitivity 50–800, scale 0.35 | sensitivity 100–400, scale 0.4 |
| Smog volume | density 0.035 | 0.004 |
| Dust motes | 700 | 240 |
| Sun disc | 1.0° | 0.5° |
| Daytime sky | milky | paler blue tops (e.g. 12:00 top (0.5, 0.62, 0.78), horizon (0.82, 0.84, 0.86)) |

Depth-fog keys by hour (start → full, maximum opacity): night 40 → 380 m, 0.7; dawn 60 → 520 m, 0.6;
morning 90 → 700 m, 0.5; noon 110 → 800 m, 0.45; afternoon 90 → 700 m, 0.5; sunset 70 → 560 m, 0.6;
dusk 50 → 420 m, 0.65.

### Facade shader (`dhaka_facade.gdshader`)

One material for every building, driven per instance (MultiMesh `INSTANCE_CUSTOM`):
`x` = storeys, `y` = stair-core bay, `z` = flags (1 shop ground floor, 2 old plaster, 4 × power group),
`w` = seed. From world height and the face's UV it draws:

- floors every 3.2 m and bays of 3.2 m, with 1.5 × 1.2 m windows and steel grilles;
- a chajja sunshade above each window, a sill and the shadow of the glass;
- a stair-core stripe of glass blocks; drain pipes on the side faces;
- shop shutters on the ground floor of shop-houses (rolled down at night);
- at night, lit windows with warm or tube-white colours, multiplied by the district's power value, so a
  load-shedding district goes dark at once.

Clean plaster (`plaster_clean`, tile 2.5, tint 0.9) is the default; old houses use `plaster_peeling`.

### Parapets, roofs and street dressing

`ProceduralDhaka.gd` adds parapet walls with square openings (apartments, the Tower, commercial blocks),
boundary walls with sliding grille gates, roof tanks and rooms, rooftop gardens, laundry and dishes,
balconies, AC units, shopfronts with Bengali signs and awnings, poles with wires, and lamps. Night lamps
use a pool of 16 OmniLights placed on the lamps nearest Sakib that have power.

### Road shader (`dhaka_road.gdshader`)

Vertex colour carries the road kind (`COLOR.r`) and width (`COLOR.g` × 40 m). It draws lane markings,
zebra crossings at junctions and patched repairs on the asphalt.

### Ghost shader (`ghost.gdshader`)

Additive blend with a fresnel rim and value noise, uniforms `hurt` (flash when the torch hits),
`burn` (dawn) and `base_height` (fade toward the feet).

### Global shader uniforms

`project.godot` `[shader_globals]`: `dhaka_night` (0 day → 1 night), `dhaka_power_a` (vec4) and
`dhaka_power_b` (power per district group, 0 or 1). `GhostDirector` writes them every frame; the facade
shader and the lamp glow material read them.

### Renderers by platform

| Build | Renderer | Tier |
|---|---|---|
| Windows .exe | Forward+ | Low to Ultra (saved) |
| Android .apk | Mobile | forced Low; no MSAA, SDFGI, SSIL, volumetric fog or SSR; shadows ≤ 2048 |
| Web .html | Compatibility (WebGL 2) | forced Low; as Android, and no SMAA |

`RenderQuality.is_forward_plus()` decides this at run time; FSR is only used on Forward+.

## 1. The look we are after

Dhaka in this game is never clean air. Five things carry the mood:

1. **Haze that eats the blue.** Even at noon the sky is milky near the horizon; buildings 200 m away go grey-brown. Depth fog with aerial perspective plus a thick horizon band in the sky.
2. **Shafts of light in the lanes.** Sun cutting between tightly packed buildings through dust and exhaust. Volumetric fog with forward scattering, plus dust motes around the camera.
3. **Bounce light in tight alleys.** Sun-lit plaster walls light the shaded wall opposite. SDFGI with SSIL on top.
4. **A smog sunset.** The sun turns deep orange and the whole frame goes warm and soft from about 17:00 to 18:00, the hour of the roof curfew.
5. **Night is sodium and tube light.** Orange street lamps outside, cold-white tube lights inside flats. The horizon glows orange from the city, and the volumetric fog carries a faint emissive glow.

## 2. Frame pipeline (Forward+ clustered)

In the order Godot renders a frame, with the setting that drives each step:

1. **Depth pre-pass and normal/roughness buffer.** Feeds SSAO, SSIL, SSR and the SDFGI probes.
2. **SDFGI.** Four cascades from a 0.2 m minimum cell, Y scaled to 75 % for a city of tall facades. It reads sky light outdoors, uses occlusion, and bounce feedback is 0.45. Rays per probe and convergence frames come from the quality tier.
3. **SSAO** (radius 1.4 m, intensity 2.2, power 1.6) **and SSIL** (radius 6 m, intensity 1.1). Contact darkness in alleys and under awnings; coloured bounce between walls.
4. **Shadow maps.**
   - **Sun:** 4 cascades with splits at 6 / 18 / 45 % of 160 m, blended, PCSS-style softness from a 1° angular size.
   - **Moon:** 2 cascades over 80 m.
   - **Omni lights:** the positional shadow atlas.
5. **Opaque forward pass.** Clustered lighting for the sun or moon, tube lights and street lamps. Burley diffuse with Schlick-GGX specular.
6. **Sky.** ProceduralSkyMaterial with the smog panorama in `sky_cover`, radiance 256, updated incrementally as the time changes.
7. **Volumetric fog.** A froxel grid, with temporal reprojection at 0.9. Global density, plus the `StreetSmog` FogVolume thickening toward the ground. The sun's light drives it at 1.6×, which makes the shafts.
8. **Transparent pass.** Dust motes, the grille cut-outs (alpha scissor, so these are really opaque), particles.
9. **SSR.** Ultra tier only (tiles and glass).
10. **Glow.** Levels 3–7 weighted 1, 0.8, 1, 0.6, 0.3, with screen blend, HDR threshold 0.9 and bloom 0.08. The bloom is what makes highlights bleed into the haze.
11. **Tonemap.** AgX, white 6, auto exposure (CameraAttributesPractical: sensitivity 50–800, scale 0.35, speed 0.6), and the per-hour exposure key.
12. **Grade.**
    - Adjustments: contrast 1.08, and a per-hour saturation key (0.85–0.95).
    - A 1D colour-correction gradient: shadows lift toward teal (black becomes 0, 0.012, 0.02); highlights roll off warm (white becomes 1, 0.985, 0.95).
13. **Far depth of field.** From 90 m with a 60 m transition at 0.06 strength, so the haze has depth.
14. **Upscale and anti-aliasing.** FSR 2.2 at 77 % on High, or TAA + MSAA 2× at native resolution on Ultra. Then debanding.
15. **Interface.** CanvasLayers on top: HUD, gate card, dialogue, Sky lens panel.

### URP equivalents

If you know Unity's Universal Render Pipeline, this is the same idea mapped onto Godot's Forward+ renderer:

| URP / HDRP concept | Here |
|---|---|
| Volume profile | `Environment` built in `DhakaAtmosphere._build_environment()` |
| Physical sky / gradient sky | `ProceduralSkyMaterial` + `sky_smog_cover.png` |
| Adaptive Probe Volumes / baked GI | SDFGI (real-time, no baking) |
| SSAO renderer feature | Environment SSAO |
| Screen-space GI (HDRP) | SSIL + SDFGI |
| Volumetric fog / local fog volume | Environment volumetric fog + `FogVolume` with `FogMaterial` |
| Bloom | Glow (screen blend, levels 3–7) |
| Tonemapping (ACES / Neutral) | AgX |
| Color Adjustments / LUT | Adjustments + `GradientTexture1D` colour correction |
| Exposure (automatic) | `CameraAttributesPractical` auto exposure |
| Depth of field | Far DOF blur in camera attributes |
| Main light shadow cascades | DirectionalLight3D, 4 splits, blend |
| Render scale / FSR / TAA | Viewport `scaling_3d_mode` FSR2, `use_taa`, SMAA, MSAA |
| Lit shader / decals | `dhaka_surface.gdshader`, ORMMaterial3D, Decal nodes |
| Quality settings asset | `RenderQuality.gd` tiers |

## 3. Exact configuration

### Environment

| Property | Value |
|---|---|
| background_mode | BG_SKY |
| ambient_light_source / sky_contribution / colour | SKY / 0.85 / (0.62, 0.58, 0.52); energy from time key (×0.6 indoors) |
| reflected_light_source | SKY |
| tonemap_mode / tonemap_white / exposure | AGX / 6.0 / time key |
| ssao: radius, intensity, power, detail, horizon, sharpness, light_affect, ao_channel_affect | 1.4, 2.2, 1.6, 0.6, 0.06, 0.98, 0.15, 0.4 |
| ssil: radius, intensity, sharpness, normal_rejection | 6.0, 1.1, 0.98, 1.0 |
| sdfgi: occlusion, read_sky_light, bounce_feedback, cascades, min_cell_size, y_scale, energy, normal_bias, probe_bias | true, true (false indoors), 0.45, 4, 0.2, 75 %, 1.0, 1.1, 1.1 |
| ssr: max_steps, fade_in, fade_out, depth_tolerance | 48, 0.15, 2.0, 0.2 (enabled only on Ultra) |
| glow: normalized, intensity, strength, bloom, blend, hdr_threshold, hdr_scale, luminance_cap | false, 0.55, 1.0, 0.08, SCREEN, 0.9, 2.0, 12 |
| glow levels 1–7 | 0, 0, 1.0, 0.8, 1.0, 0.6, 0.3 |
| fog: mode, light_energy, sun_scatter, aerial_perspective, sky_affect, height, height_density | EXPONENTIAL, 1.0, 0.35, 0.55, 0.35, 25 m, 0.04; colour and density from time key |
| volumetric fog: emission_energy, gi_inject, anisotropy, length, detail_spread, ambient_inject, sky_affect, temporal reprojection | 1.0, 0.6, 0.55, 96 m, 2.0, 0.35, 0.25, on at 0.9; density, albedo and emission from time key |
| adjustments: brightness, contrast, saturation, colour correction | 1.0, 1.08, time key, 256-px GradientTexture1D |

### Sky (ProceduralSkyMaterial)

| Property | Value |
|---|---|
| sky_curve | 0.06 (a thick horizon band: the haze) |
| ground_bottom_color / ground_curve / ground_energy_multiplier | (0.12, 0.11, 0.10) / 0.04 / 0.6 |
| sun_angle_max / sun_curve | 18° / 0.08 (a wide, smeared halo) |
| sky_cover / sky_cover_modulate | `art/textures/shared/sky_smog_cover.png`, tinted and faded per hour |
| use_debanding | true |
| Sky radiance_size / process_mode | 256 / INCREMENTAL |

### Camera attributes (CameraAttributesPractical)

Auto exposure on, scale 0.35, speed 0.6, sensitivity 50–800. Far DOF on from 90 m, 60 m transition, amount 0.06.

### Sun and moon (DirectionalLight3D)

| | Sun | Moon |
|---|---|---|
| colour / energy | time key; faded below the horizon | (0.60, 0.68, 0.85) / 0.12 at night |
| indirect / volumetric fog energy | 1.0 / 1.6 | default / 0.8 |
| angular distance / specular | 1.0° / 0.6 | 0.5° / 0.3 |
| shadow | on, bias 0.03, normal bias 1.2, blur 1.5 | on, blur 2.0 |
| shadow mode / splits | PARALLEL_4: 0.06, 0.18, 0.45, blended | PARALLEL_2 |
| max distance / fade start / pancake | 160 m / 0.85 / 40 m | 80 m |
| sky mode | LIGHT_AND_SKY (draws the sun disc) | LIGHT_ONLY |

The sun's path:

- **Rise and set:** rises at 05:51 and sets at 18:03, peaking at 58° elevation.
- **Direction:** azimuth runs from 108° (east-south-east) to 252°.
- **Map orientation:** world -Z is north, so the sun crosses the south (+Z side) of every map at noon.
- **Street lamps:** they follow `lamp_amount()`, which ramps from sun elevation +6° down to −4°.

### Local volumes

- **StreetSmog** (FogVolume, box): the map's footprint plus 40 m, 10 m tall, centred 4 m up.
  - Density 0.035 (0.012 indoors), albedo (0.80, 0.76, 0.68).
  - Height falloff 0.12, so it is thickest at the kerb. Edge fade 0.3.
- **DustMotes** (GPUParticles3D):
  - 700 motes in a 24 × 10 × 24 m box that follows the active camera, each living 9 s.
  - Turbulence strength 0.4; billboards 1.2 cm across, lit per vertex.

### Time-of-day keys

Values blend with a smoothstep between keys; 19:00 equals midnight.

| Hour | Sun colour · energy | Horizon colour | Fog density | Volumetric density | Exposure | Feel |
|---|---|---|---|---|---|---|
| 00:00 | — · 0 (moon) | (0.16, 0.11, 0.09) city glow | 0.010 | 0.018 + faint orange emission | 1.35 | Sodium night |
| 05:00 | — · 0 | (0.18, 0.14, 0.14) | 0.011 | 0.022 | 1.35 | Before Fajr |
| 05:48 | (1.0, 0.55, 0.32) · 0.35 | (0.86, 0.58, 0.42) | 0.012 | 0.028 | 1.15 | Smoggy dawn |
| 07:30 | (1.0, 0.82, 0.62) · 0.9 | (0.82, 0.76, 0.66) | 0.008 | 0.020 | 1.0 | Morning |
| 12:00 | (1.0, 0.93, 0.82) · 1.25 | (0.80, 0.79, 0.74) milky | 0.006 | 0.014 | 0.95 | Washed-out noon |
| 16:00 | (1.0, 0.85, 0.66) · 1.05 | (0.85, 0.74, 0.60) | 0.008 | 0.018 | 1.0 | Afternoon |
| 17:18 | (1.0, 0.55, 0.25) · 0.8 | (0.98, 0.55, 0.28) | 0.012 | 0.030 | 1.1 | Smog sunset |
| 18:00 | (0.9, 0.35, 0.2) · 0.15 | (0.55, 0.28, 0.20) | 0.012 | 0.026 | 1.3 | Roof curfew |
| 19:00 | as midnight | | | | | |

## 4. Quality tiers (`RenderQuality.gd`)

The first run picks a tier from the GPU type: Low on integrated graphics, High otherwise. The main menu and the pause menu cycle tiers; the choice is saved in `user://settings.cfg`.

| | Low | Medium | High | Ultra |
|---|---|---|---|---|
| Typical GPU at 1080p | integrated | GTX 1060 / RX 580 | RTX 2060 / RX 6600 | RTX 3070+ |
| Resolution | native (render scale opt-in) | native | native | native |
| Anti-aliasing | SMAA | SMAA | SMAA + MSAA 2× | SMAA + MSAA 4× |
| SDFGI | off | off | 16 rays, 20 frames, half-res | 32 rays, 15 frames, full-res |
| SSIL | off | off | medium, half | high, full |
| SSAO | low, half | medium, half | high, half | ultra, full |
| Volumetric fog | off (depth fog stays) | 64³ | 96³ | 128³ |
| SSR | off | off | off | on, medium roughness |
| Sun shadows | 2 splits, 80 m, 2048 | 4 splits, 120 m, 4096 | 4 splits, 140 m, 4096 | 4 splits, 160 m, 8192 |
| Soft shadow filter | very low | low | medium | high |
| Dust motes | off | on | on | on |
| Mesh LOD threshold | 4 px | 2 px | 1 px | 1 px |

Budgets (High, 1080p):

- **Frame time:** ≈ 12 ms GPU.
- **Draws:** fewer than 60 MultiMesh draws for the static city. LevelBuilder groups boxes by surface, so a whole level is about 10 draws for walls and floors.
- **Lights:**
  - At most 26 interior tube lights and 14 lamps per level.
  - Interior lights cast no shadows.
  - Only the sun or the moon casts directional shadows.

## 5. Materials

### Surface shader (`shaders/dhaka_surface.gdshader`)

LevelBuilder draws the city from boxes of every size. Triplanar mapping in world space means a 2 m wall and a 30 m tower facade get the same texel density with no UVs. One material exists per surface; the MultiMesh instance colour arrives as `COLOR`.

| Stage | How |
|---|---|
| Projection | Three planar samples (X uses z,−y; Y uses x,−z; Z uses x,−y). Weights are abs(normal)^6, normalised. Image "up" always points up, so soot runs fall downwards. |
| Normals | OpenGL tangent normals, z rebuilt from xy (the RGTC-compressed case). Combined with Ben Golus's whiteout blend in world space, then converted to view space with VIEW_MATRIX. |
| Tint | `albedo × mix(1, instance colour, tint_strength)`: plaster takes the facade's paint colour; brick barely changes. |
| Macro variation | `grime_noise.png` R channel sampled at 1/77 m, ±20 % brightness, so long facades do not repeat visibly. |
| Street grime | Below `grime_height` (1.2 m) on vertical faces, darkened toward `grime_color`. |
| Soot runs | G channel of the grime noise stretched 40× vertically, thresholded, on vertical faces. |
| Dust | On faces pointing up (n.y > 0.55): toward `dust_color`, and rougher. |
| PBR | ORM texture: AO (0.25 light affect), roughness plus grime and dust, metallic scaled. |

| Surface | Texture set | Tile (m) | Tint | Grime / soot / dust | Used for |
|---|---|---|---|---|---|
| BRICK | brick_weathered | 0.96 | 0.12 | 0.4 / 0.3 / 0.2 | Some tall blocks and 2-storey blocks |
| PLASTER | plaster_peeling | 2.0 | 0.85 | 0.45 / 0.35 / 0.15 | Interior and Tower walls, pastel facades, minar, mosque |
| CONCRETE | concrete_moss | 2.0 | 0.3 | 0.3 / 0.2 / 0.3 | Slabs, parapets, pavements, ground, stairs, graves |
| ASPHALT | asphalt_cracked | 4.0 | 0.1 | 0 / 0 / 0.25 | Roads |
| TIN, TIN_PAINTED | tin_corrugated_rust / painted | 2.0 | 0.15 / 0.25 | 0.2 / 0.1 / 0.2 | Single-storey roofs, kiosk back walls |
| AWNING | six fabrics, picked per kiosk | 2.0 | 0 | 0 / 0 / 0.1 | Kiosk canopies |
| TILE | tile_rubber | 1.2 | 0.1 | 0.15 / 0 / 0.1 | Ground-floor interiors (the car-park tiles in the Tower photos) |

If a driver ever objects to the shader, set `DhakaMaterials.use_shader = false`. Surfaces then fall back to ORMMaterial3D with world triplanar and the same textures. With no textures at all, everything falls back to flat colours.

### Faces

Phase 2: each head is a sculpted mesh from `HeadSculpt.gd` with the same UV layout as a SphereMesh
(so the same face textures fit): Gaussian shaping for the nose, eye sockets, brow, cheekbones, lips and
chin, a narrowed jaw (more for women), flattened sides and a tucked underside, scaled (0.88, 1.07, 0.98).
The face is centred at u = 0.5, which is −Z, the direction Godot nodes face. The material is ORMMaterial3D:

- skin-mode subsurface scattering, strength 0.28;
- rim light 0.12 at tint 0.45;
- normal scale 0.8;
- anisotropic filtering.

Glossy corneas, ears, hair meshes (long panel, bun, bun with flowers, curly cap), caps and earrings are
separate meshes. The face textures carry a stylised-realism pass: flush, under-eye shading, contour,
highlights, pores and a T-zone sheen; plus kajal (normal or smoky), lipstick, bindi and glasses
(including tortoiseshell cat-eye).

Twenty-seven faces ship in `faces.json` (Sakib, 11 other men, 15 women). Every face except Sakib's is an
original design, not a likeness of a real person.

| Face | Who | Notes |
|---|---|---|
| sakib | man, 28 | curly hair, beard, from his own reference photo |
| m_young_clean | man, 21 | short hair |
| m_mustache | man, 38 | short hair, mustache |
| m_beard_full | man, 45 | short hair, beard |
| m_elder_white | man, 68 | receding hair, white beard, glasses |
| m_stubble_dark | man, 30 | cropped hair, stubble |
| m_goon_scar | man, 33 | cropped hair, goatee |
| m_henna_beard | man, 58 | receding hair, henna beard |
| m_curly_young | man, 22 | curly hair |
| m_glasses_mid | man, 41 | side parting hair, mustache, glasses |
| m_round_clean | man, 35 | short hair |
| m_beard_trim | man, 29 | cropped hair, beard |
| f_young | woman, 22 | long, centre parting hair |
| f_nosepin | woman, 29 | long, centre parting hair |
| f_wheat | woman, 25 | long, side parting hair |
| f_elder | woman, 62 | bun hair, glasses |
| f_lawyer_bun | woman, 32 | bun hair, gold hoop earrings |
| f_wavy_side | woman, 27 | long, side parting hair |
| f_soft_bun | woman, 38 | bun hair, stud earrings |
| f_cateye | woman, 30 | long, centre parting hair, glasses, jhumka earrings |
| f_straight_smile | woman, 24 | long, centre parting hair |
| f_round_bindi | woman, 28 | bun hair, jhumka earrings, bindi |
| f_matron_bindi | woman, 50 | bun hair, gold hoop earrings, bindi |
| f_saree_elder2 | woman, 58 | bun hair, gold hoop earrings |
| f_red_hair | woman, 26 | long, side parting hair, jhumka earrings |
| f_bold_kajal | woman, 34 | long, side parting hair, stud earrings |
| f_flower_bun | woman, 30 | bun with flowers hair, jhumka earrings, bindi |

`DhakaMaterials.pick_face(seed, female, elder)` hands them out and never gives away Sakib's face. Each face also has a lit, transparent `_portrait.png` for dialogue boxes and a flat `_front.png`.

### Cloth, awnings, grille, decals

These use UV-mapped ORMMaterial3D, via `cloth(name)`, `awning(name)`, `grille()` (alpha scissor 0.5, double-sided) and `decal_textures(name)` (albedo, normal and ORM for a Decal node). Cloth tiles are 0.3–0.5 m; set `uv_scale` to suit the limb.

## 6. Textures (`tools/generate_textures.py`)

All maps come from code: periodic Perlin, fractal and ridged noise, tileable Worley cells, FFT Gaussian blur (it wraps, so tiling survives) and height-to-normal and height-to-AO conversion.

- **Conventions:**
  - Albedo is sRGB; the other maps are linear.
  - Normal maps are OpenGL style (green up), which is Godot's default.
  - ORM packing: R = AO, G = roughness, B = metallic.
  - Tiling was checked numerically: on every noise-based set, the wrap-around edge differs no more than the texture's own neighbouring pixels.
- **Sets and how they are built:**
  - **brick_weathered:** wobbly half-bond grid, a 56-brick colour palette (including over-burnt and pale bricks), Worley chips at the corners, pitting, efflorescence, patches of old render with cracks, moss in the mortar, soot runs.
  - **asphalt_cracked:** Worley aggregate with per-stone tone, sun bleaching, alligator cracking (Worley F2 − F1) masked into patches, long cracks, dust in the cracks, oil, a repair patch.
  - **tin_corrugated_rust / painted:** a sine corrugation 16 times across, sheet overlaps with nails on the crests, zinc spangle, rust patches and rust runs bleeding from the nails. The painted variant fades on the crests and peels back to rust.
  - **concrete_moss:** board marks, tie holes, bug-holes, hairline cracks, vertical soot runs, black mould; moss where the AO cavity, the cracks and the seams meet.
  - **plaster_peeling:** off-white paint over grey render, flakes with curled edges, deep spots down to brick, damp tide lines.
  - **tile_rubber:** red, green and grey 300 mm studded tiles laid in a checker, as in the Tower car park photos.
  - **Awnings and tarps:** canvas or plastic weave, stripes or gamchha check, sun fade, dirt, sag and wrinkles. Tarps also get seams, stitches and grommets.
  - **Cloth:** woven twill checks, so the colours interlace like real lungi cloth; slub cotton panjabi; a small shirt check; block-printed kameez cloth. No dirt.
  - **grille_steel:** RGBA cut-out. **Decals:** soot streaks, a water stain, a torn poster.
  - **Shared:** grime_noise (RGBA), the 2048 × 1024 sky smog panorama.
- **Faces:**
  - Each face is painted front-on in a 1024² canvas with real proportions: the eyes sit on the middle line, an eye is a fifth of the head's width, the mouth is as wide as the pupils are apart.
  - Each feature is built from smooth shapes: almond eyes from two intersecting circles, irises with radial fibres, lids, a crease, kajal; eyebrows from about 200 individual hair strokes; the nose with bridge, tip, wings and nostrils; lips with a cupid's bow and the vermilion line; folds and age lines; mustache, goatee, glasses, a scar, a nose pin.
  - The canvas is then projected onto the sphere. Hairlines, beards, stubble and ears are painted directly in 3D, so they wrap round the jaw and the back of the head.
- **Commands:**
  - `python3 tools/generate_textures.py --preview` regenerates everything in about 2.5 minutes.
  - `--size 2048` doubles surface resolution (four times the disk space).
  - `--only faces` regenerates just the heads.

Godot import notes:

- Leave PNGs on VRAM compressed with mipmaps on.
- Normal maps are detected from their use (normal_texture or `hint_normal`) and stored as RGTC; the shader rebuilds z.
- Albedo must stay sRGB, and ORM must stay linear (the default).
- For the RGBA cut-outs and decals, keep the alpha channel (the default).

## 7. SVG interface kit (`art/ui`, `tools/generate_ui_svgs.py`)

**Visual language: "Jatrabari dusk glass."**

- Dark teal glass at 70–86 % opacity.
- Chamfered corners taken from rickshaw-art panel shapes.
- Marigold (#F2A93B) for neutral accents, rickshaw pink (#E5487F) as a secondary accent, red (#E5483C) for danger, green (#3FBF7F) for right answers, teal (#2EC4B6) for time and batteries.
- Alpana petal borders and nakshi kantha running stitches.
- **The matra.** Every panel meant to carry Bengali text has a horizontal headline bar with small hanging drops, echoing the stroke every Bengali word hangs from. The option badges carry a short matra, so the letters ক খ গ ঘ hang from it.

The SVGs contain no text, filters, patterns or CSS: Godot's ThorVG importer renders exactly what a browser shows, and the game draws all words.

| File | Size | Godot use |
|---|---|---|
| exam_panel_bg | 1600 × 900 | StyleBoxTexture, margins L64 T150 R64 B90 |
| exam_option_normal / hover / correct / wrong / struck | 1200 × 96 | Button style boxes (normal, hover, plus the two reveal states and struck-by-token); margins L110 T24 R40 B24 |
| exam_timer_ring + exam_timer_fill | 160 × 160 | TextureProgressBar under + progress, FILL_CLOCKWISE |
| bengali_text_backdrop | 1200 × 200 | StyleBoxTexture behind Bengali question lines; margins L40 T60 R40 B30 |
| bengali_title_plate | 900 × 160 | Level title cartouche |
| hud_bar_track / frame / fill_health / fill_alert / fill_timer | 360 × 28 | TextureProgressBar under / over / progress |
| hud_health_plate, hud_ammo_plate, ammo_round_full / empty | various | HUD clusters |
| marker_objective, marker_distance_plate, marker_enemy, marker_gatekeeper | various | World-space markers (unprojected on the HUD) |
| dialogue_box_bg, portrait_frame | 1100 × 280, 220 × 220 | Dialogue; the portrait shows `face_<id>_portrait.png` |
| toast_plate, objective_plate, clock_plate, prompt_key, crosshair, notebook_frame | various | HUD pieces |
| icon_health / ammo / alert_eye / token / battery / cash | 64 × 64 | Inventory and status |

Import the SVGs at scale 1.0 for 1080p and 2.0 for 4K (Import dock, `svg/scale`). `art/ui/_preview` has PNG renders of every file plus two composed mock-ups (`mockup_exam.jpg`, `mockup_hud.jpg`) that use a real bank question (31st BCS, Q1).

## 8. Integration in the current build

- `OpenWorld.gd` builds `ProceduralDhaka` from `city.json`, then a `DhakaAtmosphere` sized to the map, and
  applies the saved quality tier and render scale. The atmosphere follows `GameState.hour()`; lamp
  brightness follows `lamp_amount()` and the district's power.
- `ProceduralDhaka.gd` batches the city per 100 m chunk: one facade MultiMesh per chunk (with per-instance
  custom data), road meshes, kerbs, props and lamps, with visibility ranges so distant detail drops out.
- `HumanoidRig.gd` and `HeadSculpt.gd` build every person's body and head; `DhakaMaterials` provides the
  face, skin and cloth materials. Ghosts swap their materials for `ghost.gdshader`.
- The main menu (Settings) and the pause menu cycle the quality tier and the render scale; both are saved.

## 9. Not yet done

- Profiling on real hardware. The tier budgets above are targets; check them in Godot's Visual Profiler
  and adjust `RenderQuality.TIERS`.
- Decal placement (soot under sills) is ready in `DhakaMaterials.decal_textures` but not scattered yet.
- The Mobile and Compatibility renderers have not been checked visually; the facade and road shaders use
  only features those renderers support (global uniforms, instance custom data, vertex colour).
