# SakibUnemployed Godot 4.6 - Project Summary

## Objective
Upgrade the Godot 4.6 open-world game with real enterable 3D buildings, animated doors/windows, clearer 33-mission story, Bengali speech, and improved faces/bodies.

## Completed Work

### 1. Real Enterable 3D Buildings
- **BuildingInterior.gd**: Complete walkable interior generator with:
  - Two layout types: wide plot (w >= 6.2 m) with back-left stair core, and narrow plot (w < 6.2 m) with shophouse studio flat
  - Stair core from ground to roof with flights, ramps, handrails
  - Floor slabs with stair openings on every storey
  - Flats with living rooms, bedrooms, kitchens, bathrooms
  - Ground floor programs: shops, offices, colleges, mosques, messes, lobbies
  - Roof with headroom/parapet, water tank, solar panel, clothesline, garden, charpai
  - Animated doors and windows (InteractiveDoor.gd, InteractiveWindow.gd)
  - Lights, fans, furniture generated procedurally

- **BuildingInteriorSystem.gd**: Streaming system that:
  - Pre-builds 11 enterable landmarks at startup (kept permanently)
  - Shows entrance proxies for ordinary buildings when player is near
  - On-demand builds full interior when player opens door
  - Frees interior when player leaves, restoring the painted facade
  - Limits max 2 open interiors simultaneously with culling

- **BuildingEntrance.gd**: Front-door marker with:
  - Porch, pillars, lintel, steps, name label
  - Interact options: "Enter/leave"
  - Hides when interior is built, restored when interior is freed

### 2. 11 Enterable Landmark Buildings
The following buildings are pre-built at startup and kept permanently:
- tower, cyber, coaching, superstore, dania_college, college_admin, library, police_station, lawyer, clinic, mess

### 3. Facade Hiding System (ProceduralDhaka.gd)
- Records building visual data (chunk + index + original transform)
- `set_building_hidden(id, true)`: Zero-scales the MultiMesh instance
- `set_building_hidden(id, false)`: Restores original transform
- `set_building_collision(id, enabled)`: Enables/disables colliders
- New `buildings_in_radius(p, radius)` function for scanning nearby buildings

### 4. Bengali Speech and Voice System
- **Voice.gd**: Priority queue system:
  - Priority 0: Ambient barks (drop when busy/paused)
  - Priority 1: Conversation replies
  - Priority 2: Story/conversation interrupts
  - Pre-rendered manifest lookup with Bengali TTS
  - System-TTS fallback, subtitle-only fallback
- **1904 voice lines** rendered using edge-tts with Bangla voices:
  - bn-BD-NabanitaNeural, bn-BD-PradeepNeural, bn-IN-BashkarNeural, bn-IN-TanishaaNeural
- **Manifest**: 1905 lines (1904 rendered + 1 existing, 6 failed punctuation-only lines)
- **generate_voice.py**: Tool with --jobs flag for parallel rendering

### 5. Mission Story Upgrade
- All 33 missions upgraded (25 story, 4 job, 4 side) across 6 acts, 117 steps, 11 givers
- Real Bengali story text lives in each mission's `title.bn` and each step's `text.bn` (Bengali + English)
- Placeholder junk fields `bn_name`/`bn_objective` (mission level) and `bn_label`/`bn_description` (step level) removed — none were referenced by any script
- Mission objectives cover: shopping, market bargaining, college days, mosque visits, messenger services, doctor visits, lawyer chambers, tower roof access, mess meals, library, taxi rides, etc.
- Old gate→roof teleport in MissionDirector.gd removed; players must now climb real stairs

### 6. Door/Window Animation
- **InteractiveDoor.gd**: Hinged animated door with:
  - Auto-open when player approaches
  - Collider disappears while open
  - Signal emissions (opened/closed)
  - Configurable width, height, wood tint, nameplate
- **InteractiveWindow.gd**: Two-sash casement window with:
  - Glass, grille, curtains, sill pot, leaf
  - Open/close on interaction
  - Auto-open when player approaches (range 4.5-7.0 m)

### 7. Research and Design Basis
- **RESEARCH_JATRABARI.md**: Detailed documentation of real Jatrabari geography, street character, building dimensions, stair cores, floor plans, roofs, and references
- Building dimensions based on actual Dhaka mid-rise construction:
  - Plot widths: 3.5-35 m
  - Storey height: 3.2 m typical
  - Stair core: 3.0-4.2 m × 3.0-3.6 m
  - Flat sizes: 55-95 m²

### 8. Services and Integration
- **Services.gd**: Added `interiors` service for BuildingInteriorSystem
- **OpenWorld.gd**: BuildingInteriorSystem initialized after player setup
- Voice system integrated with dialogue box and citizen interaction

### 9. Face and Body Upgrade Documentation
- **FACE_BODY_UPGRADE.md**: Documents the best-effort approach
- **HumanoidRig.gd `_make_head()`**: Eyes now include a warm-brown iris disc and black pupil dot positioned just in front of the transparent cornea, so faces read as real eyes rather than blank glossy spheres
- Sculpted head (nose, brow, sockets, cheekbones, lips, chin) wearing painted face textures; glossy cornea; procedural hair styles (short, long, bun, curly); earrings from face record
- MakeHuman integration pipeline described (manual workflow)
- Pure procedural alternative documented
- Disclaimer: Avoid real celebrity likenesses; use original South Asian faces
- Body anatomy improvements documented (capsule controller, stair adaptation)

## File Structure Changes

### New Files Created
- `scripts/world/BuildingInteriorSystem.gd` - Streaming system
- `scripts/world/BuildingEntrance.gd` - Entrance proxy
- `docs/FACE_BODY_UPGRADE.md` - Face/body upgrade documentation
- `docs/PROJECT_SUMMARY.md` - This summary

### Files Modified
- `scripts/world/BuildingInterior.gd` - Complete rewrite with layout fixes
- `scripts/world/ProceduralDhaka.gd` - Facade hiding, new functions
- `scripts/world/InteriorBatch.gd` - Winding bug fixes; replaced `get_vertex_count()` with explicit `_vcount` counter
- `scripts/world/InteractiveDoor.gd` - Interactive flag added
- `scripts/world/InteractiveWindow.gd` - Already complete
- `scripts/actors/HumanoidRig.gd` - Added iris + pupil to eyes for clearer faces
- `scripts/dialogue/Voice.gd` - Priority queue system
- `scripts/missions/MissionDirector.gd` - Tower teleport removed
- `scripts/world/OpenWorld.gd` - Interior system wiring
- `autoload/Services.gd` - Added interiors service
- `Data/Story/missions.json` - Removed junk placeholder fields; real Bengali text in `title.bn`/`text.bn`
- `scripts/world/CityData.gd` - Added buildings_in_radius function
- `README.md` - Updated mission count (33 in 6 acts) and enterable-building/voice bullets

### Deleted Temp Scripts
- `scripts/upgrade_missions.py`, `scripts/check_voice*.py` (voice coverage verified: 230 BN + 230 EN lines, 0 missing)

### Files Preserved (Backup)
- Original project backed up to `_backup_v03_original`

## Technical Notes

### Godot Version
Godot 4.6 stable - headless import/parse validated successfully

### Performance
- 2,693 buildings with only 11 permanent interiors at startup
- Ordinary buildings cost nothing until player opens door
- Entrance proxies are lightweight (single MeshInstance3D)
- Light culling within ~13 m range

### Bengali Language Support
- All mission text in Bengali (`title.bn`, `text.bn`) + English
- Voice generation with proper Bangla TTS voices; manifest coverage verified: 230 Bengali + 230 English mission lines rendered, 0 missing
- Dialogue system supports both Bangla and English

### Important Disclaimer
- No real celebrity likenesses are reproduced
- Faces use original high-quality South Asian features inspired by regional characteristics
- MakeHuman heads or best-effort procedural generation used
- Body anatomy improvements are best-effort given Godot 4.6 constraints

## Known Limitations
- MakeHuman to Godot integration not fully proven (head cropping, materials, alpha hair)
- No Blender available for model editing
- Hyperrealistic GTA-level faces not achievable procedurally; best-effort MakeHuman heads / procedural used
- Some older building scripts still use facade system (coexists with new interior system)
- Interactive smoke test (enter → climb roof → door/window animate → leave → facade restore) not yet run; requires player input (not headless-testable)

## Next Steps (if continuing development)
1. Test MakeHuman OBJ import into Godot 4.6
2. Create prototype head with correct scaling
3. Run interactive smoke test: scan → entrance → enter → climb roof → door/window animate → leave → facade restore (requires player input)
4. Validate all 11 landmark interiors work correctly in-game
5. Verify Bengali speech plays correctly in-game
6. Test mission flow with upgraded objectives