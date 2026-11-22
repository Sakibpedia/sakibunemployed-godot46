# এস এম নাজমুয সাকিব বেকার — *S M Nazmuz Sakib is unemployed*

Godot 4.6 open-world game. Developed by S M Nazmuz Sakib. © 2026 S M Nazmuz Sakib. All rights reserved.

Sakib has an LLB, a pile of guidebooks and no job. The open world is Jatrabari in Dhaka: Dania College,
Sontek, Kajla and Jurain. Every gatekeeper, rival, police officer and dying man fires exam questions at
him: BCS, other government and bank jobs, and the Bar Council. Shortcut Coaching sells leaked papers.
The game is in Bengali, with English as an option.

- Full design (story, characters, missions, rules): `docs/DESIGN.md`
- Code contract (modules, data files, signals): `docs/ARCHITECTURE.md`
- Rendering (atmosphere, shaders, quality tiers, textures, faces): `docs/RENDERING.md`
- Building the .exe, the web version and the Android .apk: `docs/EXPORT.md`

## Open and play

1. Install **Godot 4.6** (standard build).
2. In the Project Manager choose **Import**, pick `project.godot`, then **Edit**. The first import of the
   textures takes a few minutes.
3. Press **F5**. The main menu (in Bengali) has: continue, new game, BCS / job / Bar practice, settings,
   credits, copyright and quit.

This build has not been opened in Godot here (no Godot in the build workspace). Expect a few script
errors on the first run; the Output and Debugger panels name the file and line.

## Exports: .exe, .html, .apk

`export_presets.cfg` has three presets (Windows Desktop, Web, Android). Build all three with
`export_all.bat` (Windows) or `./export_all.sh` (Linux/macOS), or with no local setup through the
GitHub Actions workflow in `.github/workflows/export.yml`. Details, signing and limits: `docs/EXPORT.md`.
On phones and phone browsers the game shows an on-screen stick, a look pad and Bengali action buttons.

## Controls (keyboard and mouse)

| Action | Key |
|---|---|
| Move · sprint · crouch · jump | W A S D (or arrows) · Shift · C or Ctrl · Space |
| Look · aim · shoot or punch | Mouse · right button · left button |
| Talk / use / read a poster | E |
| Enter or leave a vehicle · horn | F · G |
| Change weapon (fists, iron rod, pistol) | Q or mouse wheel |
| Reload · bandage · torch | R · H · T |
| First / third person | V |
| Map · missions | M · Tab |
| Answer an exam question | 1 2 3 4 (ক খ গ ঘ) or click |
| Bribe · flee an exam · skip a line | B · X · Enter |
| Pause · help | Esc · F1 |

## What is in the game

- **An open Jatrabari**: five districts built from `Data/World/city.json` (highways N1 and N8, the Mayor
  Hanif flyover, the railway and rail gate, lanes, ponds, the graveyard, Dania College, the Tower, the
  mosque, Shortcut Coaching, the police station and more), modelled on the reference photos: plastered
  blocks with grilled windows and sunshades, parapets, roof tanks, boundary walls with sliding grille
  gates, shopfronts with signs and awnings, wires on every pole.
- **People with their own lives**: pedestrians, rickshaws, CNGs, buses, cars, motorbikes and trucks.
  People walk, talk, gossip about what you did, flee gunfire and fight back, and crimes bring the police.
  Everyone speaks Bengali (subtitles plus pre-rendered Bengali voice audio, with the device's
  text-to-speech as a fallback).
- **Enterable buildings**: 11 landmarks (Dania College, Shortcut Coaching, the superstore, the library,
  the police station, a clinic, a mess, the tower and more) have real walkable interiors with stair
  flights, flats, offices and roof access; ordinary buildings stream in a lightweight entrance proxy
  and build their interior in place when you open the door. Doors and windows animate open and shut,
  stairs and ramps connect every floor, and the facade is hidden while you're inside and restored when
  you leave.
- **33 story missions in six acts, plus job and side missions** (`Data/Story/missions.json`):
  25 story, 4 job and 4 side missions — talks, choices, exams, chases, deliveries, defending the tea
  stall, escorts through load-shedding, driving, ghost banishing, a boss ghost and four endings.
  Every step has Bengali and English text, all pre-rendered to voice (`audio/voice/bn` and `en`).
- **Exams everywhere**: 2,571 original practice questions in Bengali (maths, ICT, Bangladesh,
  international affairs, science, English, Bangla, law and banking) plus 173 real past-paper
  questions with citations. Gatekeepers, tuition, interviews, the Bar test, police quizzes, street duels,
  posters and the viva board all draw from them, never repeating a question until the pool is used up.
- **Dying questions and ghosts**: a person Sakib brings down bleeds out for 50 seconds and asks three
  questions. Fail them and the dead man returns at night as a ghost that taunts him with his question
  until Sakib answers it.
- **The night rule**: after sunset the dead walk. Stay indoors or within 8 m of a working street lamp,
  carry a torch, and watch for load-shedding, which switches whole districts dark. Dawn burns every
  ghost away.
- **Police heat** from zero to five stars: at one star an officer stops Sakib with a quiz; from two
  stars they attack. Arrest costs money and a night at the station.

## Tools (Python 3; Pillow and numpy for textures)

| Command | Does |
|---|---|
| `python3 tools/make_city.py` | Lays out the city and writes `Data/World/city.json` and `docs/img/city_map.png` |
| `python3 tools/make_story.py` | Writes `Data/Story/missions.json` |
| `python3 tools/check_story.py` | Checks missions, characters, POIs, faces, Bengali text and the name spelling |
| `python3 tools/generate_questions.py` | Writes the 2,571-question practice bank (`--sample 20` to preview) |
| `python3 tools/check_bank.py` | Checks the cited past-paper bank |
| `python3 tools/generate_textures.py --preview` | Textures, faces and previews in `art/textures/` |
| `python3 tools/generate_ui_svgs.py --preview` | The SVG interface kit in `art/ui/` |

## Folder map

- `autoload/` — GameState, Services, AudioEventBus, PhysicsEventBus
- `scripts/core/` — Game (input, settings, language, scene flow)
- `scripts/world/` — OpenWorld, CityData, ProceduralDhaka, pedestrians, traffic, vehicles, posters, heat, ghosts
- `scripts/actors/` — HumanoidRig, HeadSculpt, PersonGenerator, Citizen, ActorAI, ActorHealth, ActorVisuals, Ghost, ActorFactory
- `scripts/player/` — Player
- `scripts/exam/` — QuestionBank, ExamSession, ExamDirector
- `scripts/dialogue/` — Voice, TauntBank, ChatterAI
- `scripts/missions/` — MissionDirector
- `scripts/ui/` — Main menu, HUD, CityMap, ExamPanel, DialogueBox, TouchControls, Credits, Copyright, UiKit
- `scripts/rendering/` — DhakaAtmosphere, RenderQuality, DhakaMaterials
- `shaders/` — facade, road, surface and ghost shaders
- `Data/` — city, story, questions, text, sound bank
- `art/` — generated textures, faces and SVG interface
- `tools/` — generators and checks · `docs/` — design and technical docs
- `legacy/` — the old 20-level game, ignored by Godot (kept for reference)

## Rules kept in this build

No external assets: every texture, face, model and interface piece is generated by code. No rain, no
thunder and no continuous music. Sakib's face follows the developer's own reference photo; every other
face is an original design and not the likeness of a real person.
