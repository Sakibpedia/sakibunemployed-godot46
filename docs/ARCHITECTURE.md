# Code architecture — Phase 2 open world

Developed by S M Nazmuz Sakib. © 2026 S M Nazmuz Sakib. All rights reserved.

This is the contract every script follows: what each module owns, the functions other modules may call, and the data files it reads. Rendering (sky, fog, quality tiers, surface and face materials) is in `docs/RENDERING.md`. Story, missions and rules are in `docs/DESIGN.md`.

## 1. Conventions

- **World units and axes:** metres. +X is east, −Z is north, so a map's `z` grows southward, exactly like an image's rows.
- **Map space:** `city.json` stores `[x, z]` in metres from the map's north-west corner, so the world origin is that corner.
- **Typing:** all GDScript is typed (`var a: int`, `-> void`). We never infer a type with `:=` from a Dictionary or Array lookup; Godot rejects that.
- **Text:** every player-facing line is a Dictionary `{"bn": "…", "en": "…"}`. `Game.text(line)` picks the language from settings and falls back to the other.
- **Determinism:** generators take a seed (`tools/make_city.py --seed`, `PersonGenerator.make(seed)`). The same seed always gives the same city and the same people.

## 2. Autoloads (project.godot order)

| Name | Script | Owns |
|---|---|---|
| `Game` | `scripts/core/Game.gd` | Input map, settings (language, voice, quality, render scale), scene switching, fades, `text()` |
| `GameState` | `autoload/GameState.gd` | Everything saved: clock, money, health, inventory, respect, honesty, knowledge, flags, missions, posters, spirits, exam bags, stats |
| `Services` | `autoload/Services.gd` | Dependency-injection container: holds world systems, hands them to actors |
| `AudioEventBus` | `autoload/AudioEventBus.gd` | Synthesised SFX and hearing events (`hear()` on nodes in group `listeners`) |
| `PhysicsEventBus` | `autoload/PhysicsEventBus.gd` | Impacts, falls, explosions |
| `Voice` | `scripts/dialogue/Voice.gd` | Text-to-speech through the OS voices, subtitles |
| `Exams` | `scripts/exam/ExamDirector.gd` | Question bank, the no-repeat exam session, the exam panel |
| `Missions` | `scripts/missions/MissionDirector.gd` | Story and side missions, mission markers, random encounters |

These were removed and archived in `legacy/` (ignored by Godot): WorldState, LLMBridge, IREEBridge, ExamGate, CareerAdvice, CrowdAggregate, LastWishDirector, plus the old Level, LevelBuilder, Actor, Humanoid, Player, HUD and the behaviour-tree classes.

## 3. Data files

| File | Made by | Read by |
|---|---|---|
| `Data/World/city.json` | `tools/make_city.py` | `CityData`, `ProceduralDhaka`, minimap, traffic, pedestrians, missions |
| `Data/Questions/question_bank.json` | hand-cited (173 real past-paper items) | `QuestionBank` |
| `Data/Questions/practice_bank.json` | `tools/generate_questions.py` (2,000+) | `QuestionBank` |
| `Data/Story/characters.json` | hand-written | `MissionDirector`, `ActorFactory` |
| `Data/Story/missions.json` | `tools/make_story.py`, checked by `tools/check_story.py` | `MissionDirector` |
| `art/textures/**` | `tools/generate_textures.py` | `DhakaMaterials` |
| `art/ui/*.svg` | `tools/generate_ui_svgs.py` | `UiKit` |

### city.json

```
size [W, H]; seed
districts[]   {id, name{bn,en}, rect[x0,z0,x1,z1], style, power_group}
roads[]       {id, name{bn,en}, kind: highway|main|lane|alley, width, points[[x,z]…], sidewalk}
flyovers[]    {id, name, points[[x,z]…], width, height}
rail[]        {points[[x,z]…]}
buildings[]   {id, x, z, w, d, rot (radians about Y), floors, storey, style, color[r,g,b], accent[r,g,b],
               shop (kind or ""), sign{bn,en} or null, district, roof{tank, room, garden, laundry, dish},
               balconies, stripe, landmark (id or ""), enterable}
ponds[]       {rect}
trees[]       [x, z, radius]
lamps[]       [x, z, district]
poles[]       [[x,z]…] chains of electric poles; wires hang between consecutive poles
posters[]     {id, x, y, z, nx, nz, kind: coaching|circular|job|bar|leak|notice}
props[]       {kind, x, z, rot}   (tea_stall, fruit_cart, rickshaw_stand, garbage, bench, banner, tank, generator)
ped_nodes[]   [x, z];  ped_edges[] [a, b]
lanes[]       {road, points[[x,z]…], speed}   one-way traffic lanes (each road gives one per direction)
pois[]        {id, name{bn,en}, x, z, kind, building}
safe_zones[]  {id, rect[x0,z0,x1,z1], kind: home|mosque|shop|college}
spawn         [x, z]
```

## 4. World (`scenes/World.tscn` → `scripts/world/OpenWorld.gd`)

`OpenWorld._ready()` builds, in order:

1. `CityData` (load and index `city.json`)
2. `ProceduralDhaka` (meshes and collision)
3. `DhakaAtmosphere`
4. `Player`
5. `HUD`, and `TouchControls` when `Game.touch_mode` is on (phones, tablets, phone browsers)
6. `TrafficSystem`, `PedestrianSystem`, `PosterSystem`, `HeatSystem`, `GhostDirector`

It then registers every system in `Services` and calls `Missions.attach_world(self)`.

| Class | Key API |
|---|---|
| `CityData` (RefCounted) | `load_city()`, `size() -> Vector2`, `district_at(p: Vector3) -> Dictionary`, `nearest_ped_node(p) -> int`, `ped_node_pos(i) -> Vector3`, `ped_neighbors(i) -> PackedInt32Array`, `poi(id) -> Dictionary`, `poi_pos(id) -> Vector3`, `is_safe_zone(p) -> bool`, `lamp_lit_at(p, power_on: Callable) -> bool`, `ground_height(p) -> float` |
| `ProceduralDhaka` (Node3D) | `build(city: CityData)`; `signal built` |
| `TrafficSystem` (Node3D) | `setup(city, player)`, `nearest_vehicle(p, max_d) -> Vehicle` |
| `Vehicle` (CharacterBody3D) | `kind`, `setup(kind, lane, t)`, `enter(player)`, `exit_vehicle()`, `is_player_driven() -> bool` |
| `PedestrianSystem` (Node3D) | `setup(city, player)`, `active_count() -> int` |
| `PosterSystem` (Node3D) | `setup(city)`, `read(poster_id)`, `tear(poster_id)` |
| `HeatSystem` (Node) | `level() -> int`, `add_crime(kind: String, pos: Vector3)`, `clear()`; `signal heat_changed(level)` |
| `TouchControls` (CanvasLayer) | `player` (set by OpenWorld); presses the normal input actions through `Input.parse_input_event`, and calls `Player.look(rel)` for the look pad |
| `GhostDirector` (Node3D) | `is_night() -> bool`, `player_exposed() -> bool`, `power_on(district_id) -> bool`, `spawn_ghost(spirit, near)`; `signal danger_changed(exposed)` |

## 5. People

```
Citizen (CharacterBody3D, class_name Citizen)
 ├─ ActorVisuals (Node3D)   → HumanoidRig (Skeleton3D + skinned body + clothes + face + hair)
 ├─ ActorAI (Node)          state machine, senses, chatter, quizzing
 └─ ActorHealth (Node)      health, bleed-out, dying questions, spirit hand-off
```

| Class | Key API |
|---|---|
| `ActorFactory` (RefCounted) | `static spawn(profile: Dictionary, parent: Node, pos: Vector3) -> Citizen`; it injects `Services` into the citizen and its three components |
| `PersonGenerator` (RefCounted) | `static make(seed: int, role: String, district: String) -> Dictionary` returns a profile: `id`, `name{bn,en}`, `gender`, `age`, `profession`, `face`, `outfit`, `look`, `personality{kind, temper, brains, curiosity}`, `voice{pitch, rate}`, `role` |
| `Citizen` | `setup(profile, services)`, `profile`, `ai`, `health`, `visuals`, `say(line: Dictionary, seconds)`, `move_to(target: Vector3, speed)`, `stop_moving()`, `face_toward(p)`, `is_alive()`, `interact_options(player) -> Array`, `interact(player, option_id)` |
| `ActorAI` | `state`, `set_state(s)`, `order_goto(p)`, `order_follow(node)`, `order_attack(node)`, `order_guard(p)`, `hear(event, pos, level)`, `notify_crime(kind, pos)` |
| `ActorHealth` | `hp`, `take_damage(amount, source: Node, kind: String)`, `heal(n)`, `is_dying()`, `signal died(citizen, peaceful: bool)`, `signal downed(citizen)` |
| `ActorVisuals` | `rig`, `bubble(text, seconds)`, `set_marker(kind)` |
| `HumanoidRig` (Node3D) | `build(look: Dictionary)`, `animate(delta, speed, state)`, `gesture(name)`, `look_at_point(p)`, `set_ghost(on)`; states `idle`, `walk`, `run`, `crouch`, `aim`, `talk`, `sit`, `kneel`, `dead`, `cower`, `punch`, `phone`, `float`, `drive` |
| `Ghost` (CharacterBody3D) | `setup(spirit: Dictionary, services)`, `banish()`, `burn()`, `hurt_by_light(amount)` |
| `TauntBank` | `static pick(category: String, rng) -> Dictionary`; categories `wrong`, `slow`, `right_grudging`, `gun`, `ghost`, `dying`, `stranger`, `police`, `coaching`, `night`, `bribe`, `idle` |
| `ChatterAI` (RefCounted) | `static line(profile, topic: String, ctx: Dictionary) -> Dictionary`; topics `greet`, `smalltalk`, `rumour`, `exam`, `warn_night`, `react_gun`, `react_ghost`, `bye`, `quiz_offer`, `quiz_win`, `quiz_lose` |

### Spirit records (`GameState.spirits`)

`{id, name{bn,en}, face, outfit, questions: [item ids], died_at: {x, z, day}, strength, banished: false}`

A record is created by `ActorHealth` when a person the player killed dies without their dying questions answered. `GhostDirector` spawns ghosts from the unbanished records at night.

## 6. Exams

| Class | Key API |
|---|---|
| `QuestionBank` (RefCounted) | `load_all()`, `count(filter) -> int`, `ids(filter) -> PackedStringArray`, `item(id) -> Dictionary`, `categories(family) -> PackedStringArray` |
| `ExamSession` (RefCounted) | `draw(filter: Dictionary, n: int) -> Array` (no repeats inside a pool until it is exhausted; bags persist in `GameState.exam_bags`), `record(id, correct)` |
| `Exams` autoload | `start(ctx: Dictionary, done: Callable)`, `is_open() -> bool` |

A normalised item: `{id, family: bcs|job|bar, category, difficulty 1–3, q{bn,en}, options[4], options_en[4] or [], answer 0–3, source, cited: bool}`.

`ctx` keys:

- `mode`: gate, duel, dying, ghost, police, viva, interview, poster or tuition.
- Who is asking: `speaker{bn,en}`, `face`.
- What to draw: `family`, `category`, `count`, `pass`.
- Pressure: `seconds` per question and `stakes{bn,en}`.
- Escape routes: `allow_bribe` (with `bribe_cost`) and `allow_flee`.

`done` receives `{passed, right, wrong, total, bribed, fled, timed_out, items[]}`. The world pauses while the panel is open.

## 7. Missions (`Data/Story/missions.json`)

A mission is `{id, act, kind: story|side|job, title{bn,en}, giver, start_poi, requires[], hours[from,to], intro[], steps[], rewards{money, respect, honesty, item}, on_fail}`.

Step types:

| Type | What it does |
|---|---|
| `goto` | Reach a POI |
| `talk` | Hear lines, then pick a choice that sets a flag |
| `exam` | Pass a quiz |
| `kill` | Take down a target, who asks dying questions |
| `collect`, `deliver` | Pick up an item; hand it to someone |
| `escort` | Take someone to a POI |
| `chase` | Catch someone fleeing |
| `defend` | Hold off waves of attackers |
| `survive` | Live through the night until an hour |
| `wait` | Let the clock reach an hour |
| `posters` | Read or tear posters |
| `banish` | Free ghosts |
| `drive` | Take a vehicle to a POI against a timer |
| `choice` | A branching decision with honesty and respect effects |
| `cutscene` | Lines played over a camera move |

`check_story.py` checks that every POI, character, item and question filter a mission names exists.

## 8. Signals across systems

- `GameState.money_changed(v)`, `respect_changed(v)`, `honesty_changed(v)`, `time_changed(hour)`, `flag_set(key)`
- `Services.crime(kind, pos, by_player)`, `Services.gunshot(pos)`, `Services.person_died(citizen, peaceful)`, `Services.ghost_banished(spirit_id)`, `Services.poster_read(poster)`
- `Missions.mission_started(id)`, `mission_passed(id)`, `mission_failed(id, reason)`, `objective_changed(text_line)`
- `Exams.exam_finished(ctx, result)`

## 9. Performance rules

- **City:** cut into 100 m chunks. Each chunk is a handful of MultiMesh draws (facades, balconies, roof props, poles, signs) with a visibility range.
- **Lamps:** street lamps share a pool of at most 16 OmniLights placed on the lamps nearest the player at night.
- **People and traffic:** live in a ring around the player and recycle when they fall behind:

  | Tier | Pedestrians | Vehicles | Ghosts |
  |---|---|---|---|
  | Low | 14 | 8 | 3 |
  | Medium | 22 | 12 | 4 |
  | High | 30 | 18 | 6 |
  | Ultra | 40 | 24 | 8 |

- **Exam panel:** pauses the tree; UI nodes use `PROCESS_MODE_ALWAYS`.
