# এস এম নাজমুয সাকিব বেকার — Game design document

*S M Nazmuz Sakib is unemployed* · Phase 2 (open world) · Godot 4.6

Developed by S M Nazmuz Sakib. © 2026 S M Nazmuz Sakib. All rights reserved.

This document describes the game as built: the world, the people, the story, every mission, and the
rules that make it play. Code structure is in `ARCHITECTURE.md`; the look is in `RENDERING.md`; builds
are in `EXPORT.md`. Numbers quoted here are the values in the scripts and data at the time of writing.

---

## Contents

1. Pitch
2. Pillars
3. Language and voice
4. The world: Jatrabari
5. Architecture and streets (from the reference photos)
6. Time, light and the night rule
7. Load-shedding
8. People: bodies, faces and clothes
9. People: minds, chatter and street quizzes
10. Exams: the core verb
11. The question banks
12. Dying questions, spirits and ghosts
13. Police heat
14. Posters
15. Vehicles and driving
16. Combat, weapons and health
17. Economy, respect, honesty and knowledge
18. Characters
19. Story: five acts
20. Missions (story)
21. Jobs and side missions
22. Endings
23. Interface
24. Controls (keyboard, mouse, touch)
25. Audio
26. Saving and settings
27. Platforms and builds
28. Tuning table
29. Content rules

---

## 1. Pitch

Sakib has an LLB from Dhaka, a stack of guidebooks and no job. The BCS circular is out, the admit card
is stuck in a clerk's drawer, the coaching centre down the road sells leaked papers, and the people of
Jatrabari have opinions about all of it. In this city every argument is settled with a question: the
shopkeeper quizzes you before he sells a pen, the gate guard before he opens a gate, the police before
they let you go, and a dying man asks three questions before he dies. Fail him, and he comes back after
dark to ask again.

A GTA-style open world, in Bengali, where the weapon that matters most is what you know.

## 2. Pillars

1. **Knowledge is power, literally.** Exams gate doors, settle fights, calm police, free ghosts and decide the ending.
2. **Jatrabari as it is.** Streets, buildings, signs, vehicles and people modelled on the reference photos of the area; Bengali everywhere.
3. **Consequences that come back.** Killing without answering leaves a ghost. Bribes cost honesty. Gossip spreads what you did.
4. **The night is different.** After sunset the dead walk; light and shelter are survival.
5. **Satire with a straight face.** Coaching-centre guarantees, tea money, "100% common" leak posters; the jokes are in the world, not in winks at the player.

## 3. Language and voice

- Every line in the game is stored as `{"bn": …, "en": …}`. Bengali is the default; English can be chosen
  in Settings, and a second English line can be shown under Bengali subtitles.
- Menus, HUD, mission text, posters, exam panels, taunts, chatter and the ending are all in Bengali.
  Numbers in Bengali text use Bengali digits (০–৯), and exam options are lettered ক খ গ ঘ.
- The developer's name is written **এস এম নাজমুয সাকিব** everywhere; `tools/check_story.py` fails if the
  wrong spelling appears in any data file, script or doc.
- **Voices.** Lines are spoken through the operating system's text-to-speech (`Voice.gd`). With a
  Bengali voice installed, Bengali lines are spoken in Bengali; otherwise the English line is spoken
  and the Bengali subtitle still shows. Each character has a pitch and rate so voices differ.
- **Taunts.** `TauntBank.gd` holds 124 taunts in 14 situations (wrong answer, slow answer, a grudging
  "right", guns, ghosts, dying, strangers, police, coaching, night, bribes, losing, goons, idling).

## 4. The world: Jatrabari

The map is 1,400 m × 1,100 m, laid out by `tools/make_city.py` and built in-engine by
`ProceduralDhaka.gd` in 100 m chunks.

| District | Character |
|---|---|
| Jatrabari | The crossing, the bus stand, the kitchen market, the police station; traffic and noise |
| Kajla | The flyover and Kalam Mama's tea stall under it, Kajla Superstore, Shortcut Coaching; the gang's ground |
| Sontek | Older lanes, the pond, the mosque, the Tower |
| Dania | Dania College (gate, office, exam hall), Adarsha High School, the library |
| Jurain | Sakib's mess, the graveyard and caretaker's shed, the rail gate; the darkest district at night |

**Roads.** Highways N1 and N8, R110 and Gulistan Road, the Mayor Hanif flyover (driveable, with
collision) and the railway with a working rail gate. 102 road segments with markings and zebra crossings.

**Places (POIs).** Tower gate, Tower roof, Sontek pond, mosque, cyber café, Shortcut Coaching, Kajla
Superstore, the tea stall under the flyover, Dania College gate, exam hall and office, Adarsha High
School, the library, Jatrabari bus stand, the police station, the lawyer's chamber, Janata Clinic, the
kitchen market, Sakib's mess, Jurain Graveyard and its shed, the Jurain rail gate and the Jatrabari crossing.

**Size of the build.** 2,693 buildings (1,153 apartment blocks, 763 shop-houses, 430 old houses,
293 shacks, 49 commercial blocks, the college, the Tower and the mosque), 1,819 street lamps, 380 trees,
158 posters, 8,032 pedestrian path nodes and 8 safe zones.

## 5. Architecture and streets (from the reference photos)

The buildings follow the reference photos of Jatrabari rather than generic city blocks.

- **Facades** (`dhaka_facade.gdshader`): floors from world height, 3.2 m bays, 1.5 × 1.2 m windows with
  steel grilles, a chajja sunshade over every window, sills and glass shadow, a stair-core stripe of
  glass blocks, drain pipes on the side walls. Ground floors of shop-houses carry rolling shutters
  (closed at night). At night windows light up — unless load-shedding has cut the district.
- **Plaster** comes clean or old (peeling, stained); old houses and shacks use the old set.
- **Roofs**: parapets with square openings on apartments, towers and commercial blocks; water tanks,
  rooftop rooms, gardens, laundry lines and satellite dishes.
- **Street edge**: boundary walls with sliding grille gates, balconies, AC units, shopfronts with
  Bengali signs (Label3D) and awnings.
- **Landmarks**: the mosque with dome and minaret, the Tower, the college buildings; enterable
  landmarks have lit interiors.
- **Streets**: concrete poles carrying tangled wires, lamps, trees, black-and-yellow kerbs, bazar stalls,
  parked buses, ponds and grass, a backdrop ring of distant buildings at the map edge, graves at Jurain.

## 6. Time, light and the night rule

- **Clock.** 30 game seconds pass per real second, so a day lasts 48 real minutes. A new game starts
  at 8:30 in the morning. Sleeping at the mess or waiting skips time.
- **Sky.** `DhakaAtmosphere.gd` moves the sun and moon, sky colours and smog with the clock. Haze is
  depth fog only (no height fog, no depth of field, no bloom), so the city stays sharp.
- **The night rule** (Minecraft-style). When the sun drops below −1° of elevation, the dead come out:
  - every unanswered spirit (section 12) hunts Sakib from dusk to dawn, every night, until it is freed;
  - even with a clean record, wandering *nishi* spirits rise near the graveyard and in dark lanes, more
    the longer Sakib stays outside;
  - **safe**: indoors (homes, the mosque, shops, the college) or within **8 m of a working street lamp**.
    Ghosts hover at the edge of the light and taunt;
  - the **torch** (T) makes a ghost flicker and back off, at the cost of batteries;
  - at **dawn** every ghost burns away (and comes back the next night if not freed).
- **Streets at night.** Fewer people after dark, almost none after 22:00.
- **Story use.** Rina Apa's first warning (m01), the first dusk (m05), the graveyard missions (m17–m21)
  and the load-shedding escort (m18) teach the rule step by step.

## 7. Load-shedding

Each district belongs to a power group. At night `GhostDirector` cuts the power to a district for a
while: its street lamps go out, its windows go dark (the facade shader reads the power values from the
global shader uniforms `dhaka_power_a/b`), and lamp light no longer protects anyone there. Missions can
force a cut (m18 walks Rina Apa home through a dark Jatrabari).

## 8. People: bodies, faces and clothes

- **Bodies** (`HumanoidRig.gd`): a 19-bone skeleton with one skinned, lofted body mesh. Men and women
  have different torso profiles built on real proportions — shoulder and chest width, pectorals or bust,
  waist, hips and glutes, trapezius — with shaped deltoids, biceps, thighs and calves. Heights and
  builds vary per person.
- **Clothes** are shells over the body: shirts, lungi, panjabi, kameez with sash, saree, trousers.
- **Faces** (`HeadSculpt.gd` plus generated textures): a sculpted head (nose, eye sockets, brow,
  cheekbones, lips, chin, narrowed jaw) wearing a stylised-realistic face texture — "hyper-realistic
  cartoon": flush, under-eye shading, contour, highlights, pores and T-zone sheen. Glossy corneas, ears,
  hair (long, bun, bun with flowers, curly cap), caps, earrings (gold hoops, jhumka, studs), glasses
  (including tortoiseshell cat-eye), kajal, lipstick and bindi.
- **27 faces**: Sakib (curly hair, beard), 11 other men and 15 women of different ages and styles.
  Sakib's face follows the developer's own reference photo and is never given to anyone else. Every
  other face is an original design, not the likeness of a real person.
- **Animation** is procedural: walk, run, idle, talk, sit, cower, fight, aim, fall, kneel bleeding,
  and the floating ghost pose.

## 9. People: minds, chatter and street quizzes

- **Pedestrians** spawn on the path network in a ring 45–95 m around Sakib and are recycled 130 m
  behind him. A few thugs walk Kajla and Jatrabari; a few police walk everywhere.
- **Minds** (`ActorAI.gd`): a state machine (idle, wander, go to, flee, cower, fight, follow, guard,
  approach, offer) with a sight cone and hearing through `AudioEventBus`. People react to gunshots,
  bodies and ghosts; thugs and police fight.
- **Chatter** (`ChatterAI.gd`): lines put together from the speaker's profession and temperament, the
  hour, the district, the night (load-shedding, ghosts) and what Sakib did lately
  (`GameState.recent_events`), so gossip about a fight or a freed ghost spreads. No language model:
  rules and phrase banks, so every line is fit to print and it runs on any device.
- **Street quizzes**: by day, a stranger who likes a challenge may walk up and offer a question duel,
  with a small bet. Win: the bet and +2 respect. Lose: pay the bet and −1 respect.

## 10. Exams: the core verb

`ExamDirector` runs every exam. The tree pauses, the exam panel opens, and the speaker's portrait,
name and stakes are shown.

| Mode | Where it happens |
|---|---|
| Gate | A clerk, guard or shopkeeper won't let Sakib pass without answers |
| Duel | Street question fights, the tea-stall tournament |
| Tuition | Teaching Rafi |
| Interview | Shortcut's "interview", the bank interview |
| Bar | Advocate Shirin's Bar Council practice and model test |
| Police | OC Haque's questioning, and any officer at one star of heat |
| Poster | A quiz offered by a poster |
| Dying | The three questions of someone bleeding out |
| Ghost | A spirit's question at night |
| Prelim | The BCS preliminary (cited past-paper questions only) |
| Viva | The final board |

**On the panel**: question in Bengali, four options ক খ গ ঘ, a timer ring, and three ways out —
**bribe** (B; costs money and 6 honesty, only where allowed), **flee** (X), or answer. A wrong answer
earns a taunt; the panel closes early once the pass mark is reached or can no longer be reached.

**No repeats.** Each filter (family, subject, category, cited-only, difficulty) keeps a shuffled bag in
the save file; a question is not drawn again until its bag is empty. When a filter has too few
questions it relaxes step by step (category, then subject, cited-only, difficulty, family).

**Learning.** Every answer is recorded per category, and right answers count toward the ending statistics.

## 11. The question banks

- **Cited bank** (`question_bank.json`): 173 real past-paper questions (BCS, other government jobs,
  Bar Council), each with its source exam, paper and an evidence link; 157 are verified and used.
  These are the only questions used in the preliminary (m22), and they are marked "cited" in play.
- **Practice bank** (`practice_bank.json`): 2,571 **original practice questions** in the style of those
  exams, every one in Bengali, generated by `tools/generate_questions.py` with the basis of each item
  recorded:
  - computed (so the answer is exact): arithmetic, percentages, profit and loss, interest, ratios,
    averages, LCM, square roots, algebra, geometry, unit conversions, number series, number systems
    and logic gates;
  - from fact tables (one checkable fact per row): Bangladesh divisions and districts, capitals,
    currencies, headquarters of international bodies, world geography, elements and SI units, general
    science, computing basics, English synonyms, antonyms, one-word substitutes, idioms, spelling and
    grammar, Bangla sandhi, synonyms, antonyms and literature, the Constitution's articles, sections of
    the Penal Code, CrPC, CPC, Evidence Act, Limitation Act, Specific Relief Act, Contract Act and
    Transfer of Property Act, years of enactment, legal maxims, Bar Council basics, banking terms and facts.
  - The English section keeps its English words and options with a Bengali instruction; acronyms keep
    their English full forms, as in Bengali-medium papers.
- By family (an item can serve several): BCS 2,150 · job 1,792 · Bar 572.

## 12. Dying questions, spirits and ghosts

1. **Brought down, not dead.** Anyone Sakib defeats kneels, bleeding out, for **50 seconds**.
2. **Last questions.** Press E beside them: they ask **three questions**; **two right** lets them die
   in peace (often with something useful: a key, a name, intel).
3. **A spirit is born** if Sakib ignores them, fails, or finishes them off. The record (name, face,
   look, questions, district, day) goes into `GameState.spirits`.
4. **The ghost.** From that night on, the spirit rises as a *bhoot* (additive, translucent shader with
   a fresnel edge) and hunts Sakib, taunting him with its question. Touch drains health.
5. **Freedom (mukti).** Stand your ground and press E: the ghost asks its question. Right — it is freed
   for good. Wrong — it grows stronger.
6. **Generic spirits**: *nishir dak* (the night caller), *petni* and *mecho bhoot* wander on any night.
7. **Boss**: the First Examiner, an invigilator murdered by the leak ring years ago, rises in m20 and is
   faced in m21 with a longer exam.
8. The number of ghosts at once is capped by the graphics tier (3 on Low up to 8 on Ultra).
9. The ending counts the spirits still waiting at Sakib's door.

## 13. Police heat

| Stars | What happens |
|---|---|
| 0 | Police ignore Sakib |
| 1 | An officer stops him with a question (police quiz). Answer and walk free |
| 2–5 | Police attack, in numbers that grow with heat |

Crimes add heat: assault 0.6, shooting 1.0, murder 2.0, vehicle hijack 1.0, hit-and-run 1.2,
trespass 0.4. Heat cools when no officer has seen Sakib for a while. **Arrest** (an officer beside him for
3 s while he stands still, or knocked out with heat): a fine, and eight hours pass at the station.

## 14. Posters

158 posters on walls, drawn once in a SubViewport so Bengali shapes correctly: coaching adverts
("১০০% গ্যারান্টি!"), BCS circulars and recruitment notices, bank and teacher job notices, Bar Council
courses, "100% common" leak adverts, To-Let and lost-certificate notices. Reading one (E) teaches a fact
(a question with its answer) or offers a quiz. Leak posters can be **torn down** (honesty up; the gang
notices) or **used** (honesty down; a study token). m04 and s05 build on them.

## 15. Vehicles and driving

Rickshaws, CNG auto-rickshaws, buses, cars, motorbikes and trucks follow lanes with their own speeds.
CNGs, cars and motorbikes can be driven (F); taking one with a driver in it is a hijack (a crime).
G sounds the horn. Missions use driving for fares (s01), the highway truck (m13) and the race to the exam
hall (m22).

## 16. Combat, weapons and health

- Weapons: fists, an iron rod (from the tournament, m09) and a pistol (36 rounds after m10). Q or the
  mouse wheel switches; R reloads.
- Health 100. Bandages (H) heal 35. Ghost touch and gunfire hurt. When Sakib falls he wakes at Janata
  Clinic.
- Fighting is never required to win an argument the game can settle with questions; but goons, the
  raid on the tea stall and the gang's guards will fight.

## 17. Economy, respect, honesty and knowledge

| Value | Starts | Changes with |
|---|---|---|
| Money (taka) | 300 | fares, tuition, prizes, duel bets; spent on bribes, fines and mission costs |
| Respect | 10 | missions (+1 to +10), duels (+2 won, −1 lost or fled) |
| Honesty | 60 | bribes (−6), using leak posters, deals with Shahjahan (down); refusing, tearing posters, telling the truth (up) |
| Knowledge | empty | right and wrong answers per category (shown in the ending statistics) |

Inventory at the start: a torch, two bandages, two batteries and one study token. Later: the iron rod,
the pistol and ammunition, more tokens, and mission items (certificate, papers, the ledger, the key).

## 18. Characters

| Character | Who they are |
|---|---|
| Sakib (সাকিব) | LLB graduate, unemployed, lives in a Jurain mess. The player |
| Rina Apa | Runs the mess kitchen; mothers Sakib and scolds him for staying out after dark |
| Kalam Mama | Tea seller under the Kajla flyover; knows every piece of news, if not every answer |
| Habib Sir | Retired teacher of Adarsha High School: "there are no shortcuts" |
| Nadia | Studies at the library every day; better at maths than Sakib and says so |
| Tanvir | Sakib's roommate; failed the prelims three times; eyeing the leaked paper |
| Advocate Shirin Akter | Jatrabari lawyer; sees Sakib's LLB and pushes him to the Bar Council exam |
| Rumana | Journalist chasing the leak story; needs proof |
| The Principal | Principal of Dania College; strict but fair |
| Motin the clerk | College office; no tea money, no file |
| Shortcut Shahjahan | Owner of Shortcut Coaching and head of the leak ring; sells jobs with a smile |
| Bulu Bhai | Shahjahan's right hand; his word is law in Kajla |
| Dulal the courier | Delivers leaked papers by motorbike |
| OC Haque | Officer in charge of the police station; nobody knows whose side he is on |
| Ramzan the guard | Guards the Tower gate; lets nobody in without a question |
| Fakir Chan | Caretaker of Jurain Graveyard; knows the ghosts by name |
| Jamal | Rickshaw puller and union leader; knows every lane |
| Moushumi Khala | Needs a tutor for her son; a master at haggling |
| Rafi | SSC candidate who drives his tutors mad with questions |
| Liton | Owns the cyber café; files applications at twenty taka an hour |
| Selim Bhai | Owns Kajla Superstore; sells "export quality" pens |
| Chair of the viva board | The last examiner; every shortcut ends at his table |
| The First Examiner | An invigilator murdered by the leak ring; still seeks answers in Jurain's soil |

## 19. Story: five acts

1. **Act 1 — The circular** (m01–m05). An unemployed morning, a pen, an admit card, a city of posters,
   the first dusk. Teaches movement, talking, exams, posters, waiting and the night rule.
2. **Act 2 — Shortcut** (m06–m11). Tuition money, Shortcut's offer (refuse, or agree to gather proof
   from inside), the courier chase, the tea-stall tournament, Bulu Bhai's raid, and Dulal's last
   questions — the first dying-question scene.
3. **Act 3 — Proof** (m12–m16). The journalist, the highway truck, lessons in law, the police station
   (hand over the proof or only photocopies), and Tanvir (save him by studying together, or let him go).
4. **Act 4 — The dead** (m17–m21). The graveyard caretaker, load-shedding, the rail-gate ambush, the
   ledger dug up at night, and the First Examiner.
5. **Act 5 — The exam** (m22–m25). The race to the preliminary, the Tower, the last choice with
   Shahjahan (expose, deal or fight), and the viva board.

## 20. Missions (story)

| # | Title | What happens |
|---|---|---|
| m01 | সকাল · Morning | Wake at the mess; Rina Apa's warning about the night; take a CNG to Kalam Mama's stall |
| m02 | পরীক্ষার কলম · The exam pen | Selim Bhai quizzes Sakib before selling a pen (bribe allowed) |
| m03 | প্রবেশপত্র · The admit card | Motin the clerk wants answers (or tea money); the Principal signs (8:00–16:30) |
| m04 | পোস্টারের শহর · City of posters | Read five posters, tear down two leak posters, report to Habib Sir |
| m05 | প্রথম সন্ধ্যা · The first dusk | Study until late afternoon, get home before dark; a torch and batteries |
| m06 | টিউশনি · The tuition | Moushumi Khala hires Sakib; Rafi's maths questions; the first fee |
| m07 | শর্টকাটের অফার · Shortcut's offer | Shahjahan's "interview"; refuse (+8 honesty) or agree as an inside man (−4, Tk 2,000) |
| m08 | কুরিয়ার · The courier | Chase Dulal from the superstore through Sontek; take the leaked-paper packet |
| m09 | চায়ের দোকানের টুর্নামেন্ট · The tea-stall tournament | Three duel rounds (BCS, job, Bar); win the iron rod |
| m10 | বুলু ভাইয়ের হামলা · Bulu Bhai's raid | Defend the stall from two waves of goons; a pistol and 36 rounds |
| m11 | দুলালের শেষ প্রশ্ন · Dulal's last question | Stop Dulal at the mosque and hear his last questions |
| m12 | সাংবাদিক · The journalist | Rumana's sting at the bus stand: prove you're a buyer, get the price list |
| m13 | মহাসড়কের ট্রাক · The highway truck | Drive to the Kajla ramp, deal with the guards, take the box of papers |
| m14 | আইনের পাঠ · Lessons in law | Advocate Shirin's Bar Council practice (5 questions, pass 4) |
| m15 | থানা · The police station | OC Haque's questioning; hand over the proof or photocopies only |
| m16 | তানভীর · Tanvir | Find Tanvir at the coaching centre; save him with a quiz, or let him go |
| m17 | কবরস্থানের কেয়ারটেকার · The graveyard caretaker | Wait for night and free one ghost |
| m18 | লোডশেডিং · Load-shedding | Walk Rina Apa home through a power cut with the torch |
| m19 | রেলগেটের ফাঁদ · Ambush at the rail gate | Stop Bulu and his four guards; hear his last questions; take his key |
| m20 | হিসাবের খাতা · The ledger | Dig up the ledger at 21:00; the First Examiner wakes; survive until 23:00 |
| m21 | প্রথম পরীক্ষক · The First Examiner | The boss ghost's exam at the graveyard |
| m22 | প্রিলিমিনারি · The preliminary | Reach Dania College before 9:30 with Shahjahan's men on the way; 10 cited questions |
| m23 | টাওয়ার · The Tower | Ramzan's gate questions; up the stairs; the guards on the roof |
| m24 | শর্টকাট · Shortcut | Face Shahjahan: expose (+10 honesty), deal (−25 honesty, Tk 50,000) or fight |
| m25 | ভাইভা বোর্ড · The viva board | Eight questions before the board (pass 5); the ending |

Most missions have opening hours (when the giver is available); failing a step either retries,
continues with a flag, or fails the mission, as set per step.

## 21. Jobs and side missions

| # | Title | Unlocks after | What happens |
|---|---|---|---|
| s01 | সিএনজি ভাড়া · CNG fares | m02 | Drive Jamal's passenger; half the fare |
| s02 | রাফির টিউশনি · Rafi's tuition | m06 | Repeatable tuition (15:00–19:30) |
| s03 | ব্যাংক ইন্টারভিউ · The bank interview | m05 | Liton's bank interview (8 questions, pass 6); a job offer |
| s04 | বার কাউন্সিল মডেল টেস্ট · Bar Council model test | m14 | Ten law questions at the chamber; a fee |
| s05 | পোস্টার শিকারি · Poster hunter | m04 | Read thirty posters for Habib Sir |
| s06 | মুক্তি · Release | m17 | Free three ghosts for Fakir Chan |
| s07 | হারানো সনদ · The lost certificate | m03 | Find Rina Apa's certificate at the kitchen market |
| s08 | মহল্লার কুইজ মাস্টার · Quiz master | m09 | Win ten street duels |

## 22. Endings

| Ending | Condition |
|---|---|
| শর্টকাট · The Shortcut | Took Shahjahan's deal: a cadre who cannot face his reflection |
| সৎ ক্যাডার · The Honest Cadre | Passed the viva with honesty 60 or more |
| ব্যাংকের চাকরি · The Bank Job | Otherwise, if the bank offer (s03) was won |
| আবার চেষ্টা · Try Again | Otherwise: the circular will come again |

The ending adds a line for spirits still unfreed, a line if Tanvir was saved, the final honesty,
respect, right answers and spirits freed, and closes with **ডেভেলপ করেছেন এস এম নাজমুয সাকিব**.

## 23. Interface

Built from the generated SVG kit (`art/ui`) with Bengali system fonts.

- **HUD**: radar minimap, health bar, clock, money, wanted stars, a danger warning at night, the mission
  objective, weapon and inventory, the interaction prompt, toasts, subtitles and big messages.
- **Map** (M): the whole city with waypoints. **Missions** (Tab): active and available missions.
- **Exam panel**, **dialogue box** with portraits and choices, **options list** for posters and people.
- **Pause menu**: map, render scale, language, voices, main menu. **Settings** (main menu): graphics
  quality, render scale, language, English second line, voices. Mouse sensitivity and invert-Y are kept
  in `user://settings.cfg`.
- **Main menu**: continue, new game, BCS / job / Bar practice rooms (exams outside the story),
  settings, credits and copyright (Bengali first, English below).

## 24. Controls

Keyboard and mouse: see the table in `README.md`.

Touch (phones, tablets, phone browsers; `TouchControls.gd`): a movement stick on the left, drag
anywhere on the right to look, and buttons — মারো (attack, hold), লাফ (jump), দৌড় (sprint), কথা
(talk/use), গাড়ি (vehicle), তাক (aim, toggle), বসো (crouch, toggle), রিলোড, অস্ত্র (weapon), টর্চ, পট্টি
(bandage), ক্যামেরা, মানচিত্র, মিশন, হর্ন (in a vehicle) and বিরতি (pause). Exam answers and menus are tapped.

## 25. Audio

No recorded music or ambience ships. `AudioEventBus` synthesises short sounds (shots, punches, steps,
horns, bells, ghost wails, interface clicks) and plays recorded files instead when they are added to
`Data/Audio/sound_bank.json`. **No rain, no thunder, no continuous music.** Voices are text-to-speech.

## 26. Saving and settings

The game autosaves to `user://save_openworld.json`: clock, money, health, inventory, respect, honesty,
knowledge, flags, mission progress, posters read and torn, spirits, exam bags, statistics and recent
events. Settings are in `user://settings.cfg`.

## 27. Platforms and builds

| Platform | Renderer | Notes |
|---|---|---|
| Windows (.exe) | Forward+ | Four quality tiers (Low to Ultra), SDFGI, SSAO, SSIL, volumetric fog |
| Web (.html) | Compatibility (WebGL 2) | Low tier; single-threaded build for any static host |
| Android (.apk) | Mobile | Low tier; landscape; touch controls |

See `EXPORT.md`.

## 28. Tuning table

| Setting | Value | Script |
|---|---|---|
| Time scale | 30 game s per real s (48 min day) | `GameState.TIME_SCALE` |
| Start time | 08:30 | `GameState.START_HOUR` |
| Night begins | sun below −1° | `GhostDirector` |
| Lamp safe radius | 8 m | `GhostDirector.LAMP_SAFE` |
| Ghost cap (Low / Medium / High / Ultra) | 3 / 4 / 6 / 8 | `GhostDirector.MAX_GHOSTS` |
| Bleed-out time | 50 s | `ActorHealth.BLEED_SECONDS` |
| Dying questions | 3, pass 2 | `ActorHealth` |
| Bribe honesty cost | 6 | `ExamDirector` |
| Bandage heal | 35 | `Player` |
| Crime weights | assault 0.6, shooting 1.0, murder 2.0, hijack 1.0, hit-and-run 1.2, trespass 0.4 | `HeatSystem.WEIGHT` |
| Pedestrian ring | 45–95 m, recycled at 130 m | `PedestrianSystem` |

## 29. Content rules

- No external assets: every texture, face, mesh and interface piece is generated by code in this project.
- No rain, no thunder, no continuous music.
- Practice questions are labelled original and are never presented as past papers; only the cited bank
  carries exam names and years.
- Credits read "Developed by S M Nazmuz Sakib", with a copyright section in his name; his face is the logo.
- Real people's photos are never reproduced as in-game faces, except Sakib's own reference.
