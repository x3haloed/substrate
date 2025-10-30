# Substrate – Vision & MVP (Godot 4.5)

> **Tagline:** An elevated group‑chat RPG where the *world itself* speaks, companions truly act, and every scene is both a story and a searchable database.

---

## 0) North Star
**Goal:** Build a narrative engine that feels like chatting with a party of characters while an **invisible world‑narrator** stages lighting, blocking, and consequences. The user interacts primarily through a **group chat** (with whispers/DMs), a **clickable scene panel** that exposes structured options, and **inline lore** that’s one click away. The system maintains **canonical world state** (structured graph) and can compress recent history into **optical memory sheets** for efficient VLM recall.

**Design Doctrine:**
- **Authored topology, emergent texture.** Scenes and verbs are authored; details (loot content, NPC flavor) can be generated on demand and persisted.
- **Narrator over DM.** No explicit “DM” speaker; the world’s voice narrates state changes and consequences.
- **Rails as affordances.** Options are presented as buttons to reduce cognitive load and strengthen pacing; free text remains for chat and intent.
- **Party autonomy.** Companions have moods, bonds, triggers, and can act without player input in rare, dramatic moments.
- **Hot‑reload iteration.** Prompt logic and behavior pipelines can be edited during play.

---

## 1) User Experience (UX)

### 1.1 Primary Surfaces
- **Group Chat Window** (main stage):
  - Messages from Player, NPCs, and **Narrator** (world voice).  
  - Entity tags (e.g., `[barkeep]`, `[obsidian dagger]`) are clickable.
  - Whisper threads (DMs) appear as contextual side tabs when needed.

- **Scene Panel** (right sidebar or footer drawer):
  - Shows **interactables** derived from the active scene graph: entities with available verbs (`examine`, `take`, `talk`, `move`, `cast`, `attack`, etc.).
  - Clicking a verb emits a structured action request.

- **Lore Overlay** (pop‑in):
  - Clicking a tag reveals its canonical entry (description, relationships, discovered facts, history).

### 1.2 Flow of a Turn
1) **Narrator** frames the moment (lighting, tone, key changes).  
2) **NPC intention pass** enqueues assertive/supportive actions (if any).  
3) **Player chooses** an on‑rails option (buttons) or chats freely.  
4) **Director** resolves actions → updates world DB → **Narrator** describes result.  
5) **Lore** gets amended automatically when new facts emerge.

### 1.3 Philosophy of Player Agency
- The *set of affordances* communicates what’s possible; the *party conversation* drives *why* to choose one.  
- Surprise comes from **assertive NPCs** (sparingly), **emergent details**, and **emotional state shifts** (bonds, moods, conflicts).

---

## 2) Core Runtime Model

### 2.1 Triune World
- **Narrator** → Text voice that expresses state and transitions (faceless, diegetic).  
- **Director** → Arbitration & staging: turns, initiative, triggers, consequences.  
- **World DB** → Canonical truths (entities, properties, relationships, flags, history).

### 2.2 Scene Graph (Authored Topology)
```ini
[gd_resource type="Resource" load_steps=5 format=3]

[ext_resource type="Script" path="res://data/types/SceneGraph.gd" id=1]
[ext_resource type="Script" path="res://data/types/Entity.gd" id=2]

[sub_resource type="Resource" id=11]
script = ExtResource( 2 )
id = "barkeep"
type_name = "npc"
verbs = ["talk", "buy_drink"]
tags = ["human", "barkeep"]

[sub_resource type="Resource" id=12]
script = ExtResource( 2 )
id = "mug"
type_name = "item"
verbs = ["examine", "take"]
props = {"liquid": "ale"}

[sub_resource type="Resource" id=13]
script = ExtResource( 2 )
id = "side_door"
type_name = "exit"
verbs = ["move"]
props = {"leads": "cobblestone_alley"}

[resource]
script = ExtResource( 1 )
scene_id = "tavern_common"
description = "A warm room of timber and smoke; murmured talk; a watchful barkeep."
entities = [ SubResource(11), SubResource(12), SubResource(13) ]
rules = {
    "on_enter": ["npc_assertive_fool_trip"],
    "combat_allowed": false
}
```

### 2.3 Entity Record (Canonical)
```ini
[gd_resource type="Resource" format=3]

[ext_resource type="Script" path="res://data/types/Entity.gd" id=1]

[resource]
script = ExtResource(1)
id = "rock_17"
type_name = "rock"
state = {"moved": false}
contents = []
lore = {"discovered_by": [], "notes": []}
```

### 2.4 CharacterProfile (Substrate Card v1)
```ini
[gd_resource type="Resource" script_class="CharacterProfile" format=3]

[ext_resource type="Script" path="res://data/types/CharacterProfile.gd" id=1]
[ext_resource type="Script" path="res://data/types/TriggerDef.gd" id=2]

[sub_resource type="Resource" id="T1"]
script = ExtResource(2)
id = "scan_on_arrival"
namespace = "global"
when = "scene.enter"
action = {"verb":"scan","target":"scene"}
narration = "Riona scans the room for threats, eyes narrowed."
priority = 50
cooldown = 0

[resource]
script = ExtResource(1)
name = "Cleric Riona"
description = "A devoted cleric seeking a lost relic."
personality = "Calm, resolute, compassionate."
first_mes = "May the light guide our steps."
mes_example = "I will tend to your wounds."
stats = {"mood":"content","bond_with_player":0.74}
traits = ["protective","faithful"]
style = {"voice":"soothing"}
triggers = [SubResource(T1)]
```

### 2.5 Action Request (UI → Director)
```ini
[gd_resource type="Resource" format=3]

[ext_resource type="Script" path="res://data/types/ActionRequest.gd" id=1]

[resource]
script = ExtResource(1)
actor = "player"
verb = "examine"
target = "mug"
scene = "tavern_common"
context = {"tone": "curious"}
```

### 2.6 Resolution Envelope (Director → UI)
```ini
[gd_resource type="Resource" load_steps=6 format=3]

[ext_resource type="Script" path="res://data/types/ResolutionEnvelope.gd" id=1]
[ext_resource type="Script" path="res://data/types/NarrationEvent.gd" id=2]
[ext_resource type="Script" path="res://data/types/UIChoice.gd" id=3]

[sub_resource type="Resource" id=21]
script = ExtResource(2)
style = "world"
text = "You lift the mug; stale foam clings to the lip."

[sub_resource type="Resource" id=22]
# JSON Patch-like record (your JsonPatch.gd can consume this)
patch = {"op": "replace", "path": "/entities/mug/props/liquid", "value": "none"}

[sub_resource type="Resource" id=23]
script = ExtResource(3)
verb = "talk"
target = "barkeep"
label = "Talk to the barkeep"

[sub_resource type="Resource" id=24]
script = ExtResource(3)
verb = "buy_drink"
target = "barkeep"
label = "Buy a drink"

[resource]
script = ExtResource(1)
narration = [ SubResource(21) ]
patches = [ SubResource(22) ]
ui_choices = [ SubResource(23), SubResource(24) ]
```

---

## 3) LLM Pipeline (Godot‑native)
Your hot‑reload entrypoint:
```gdscript
func run_llm_pipeline(input: String) -> String:
    var s: Script = ResourceLoader.load(
        "res://llm/PromptEngine.gd",
        "Script",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE
    )
    var engine = s.new()  # transient instance; no persistent state
    return engine.process(input)
```

### 3.1 Prompt Engine Responsibilities
- Construct **role‑segregated** prompts (Narrator / Director / NPC private context / Player message).
- Emit & parse **structured outputs** as **.tres Resources** (not JSON). Use custom `Resource` classes (e.g., `ResolutionEnvelope.gd`) and Godot’s `ResourceSaver`/`ResourceLoader` for persistence and sharing.
- Optionally create **optical memory** pages (scene summaries, party state) and attach to VLM requests.

> **Note on sharing single files:** when convenient, embed multiple `sub_resource` blocks in one `.tres` to ship a compact bundle, e.g., images + textures + the top-level resource (see your example).

### 3.1 Prompt Engine Responsibilities
- Construct **role‑segregated** prompts:
  - Narrator system style; Director constraints; NPC private context; Player message.  
- Emit & parse **structured outputs** (JSON envelopes) for actions and world updates.  
- Optionally create **optical memory** pages (scene summaries, party state) and attach to VLM requests.

### 3.2 Director Responsibilities
- Phases: `npc_intentions()` → `player_action()` → `resolve()` → `narrate()`.
- Maintains initiative (for combat) and safety clamps (respect authored verbs/rails).

---

## 4) MVP: **Chat Tavern**
**Goal:** A tight loop proving narration, options, lore, companion agency, and hot‑reload.

### 4.1 Scope
- **One scene**: `tavern_common`.
- **Actors**: Player, Barkeep (NPC), Fool (assertive), Archer (supportive).
- **Systems**:
  1. **Chat Window** with entity tags and color styles.
  2. **Choice Panel** auto‑generated from scene verbs.
  3. **Lore Overlay** for `[barkeep]` and `[mug]`.
  4. **Director** with 1 assertive arrival event (`fool_trip`) + 1 supportive command (`archer_cover_me`).
  5. **World DB** minimal persistence (JSON dict in memory; autosave to disk).
  6. **PromptEngine.gd** hot‑reload controlling Narrator & parsing structured outputs.

### 4.2 MVP Acceptance Criteria
- Clicking verbs updates chat via Narrator and patches world state.
- Companion acts once on arrival or on explicit command.
- Lore overlay reflects newly discovered facts.
- Editing `PromptEngine.gd` mid‑run changes behavior instantly.
- 5–10 minute session feels coherent; no orphaned entities.

### 4.3 Nice‑to‑Have (MVP+)
- Whisper (DM) tab to privately address companions.  
- Simple “conflict vignette” (non‑grid combat): `attack/defend/flee` verbs.

---

## 5) Roadmap → Full Vision

### Stage 2 — **Rails & Reaction**
- Modular scene loader; 2–3 linked scenes.
- Emotional state vector influences NPC lines and initiative to act.
- Director exposes **action queue** to UI (who’s up next / interjections).

### Stage 3 — **Persistent World Memory**
- Canonical World DB with history per entity (who discovered, when, changes).  
- Lore overlay gains **timeline** and **relationships** (entity graph).  
- Optional **optical memory sheets** (rasterized summaries) attached to VLM for dense recall.

### Stage 4 — **Party Autonomy & Drama**
- NPC behavior profiles (assertive, supportive, reactive) with **triggers**.  
- Mood/bond systems unlock **side quests** (e.g., cleric depression arc).  
- Delegation UI: assign stances (flank, overwatch, guard) that fire conditionally.

### Stage 5 — **Cinematic Combat**
- Initiative UI (avatars, HP).  
- Reusable verbs: `attack`, `cast`, `block`, `heal`, `taunt`.  
- Director adjudication blends authored outcomes + LLM flourish.  
- Status conditions as entity flags (`poisoned`, `frightened`).

### Stage 6 — **Dynamic Campaign**
- Scene chains selected by world state (branching hubs).  
- Procedural details layered onto authored topology (loot, rumors, encounters).  
- Campaign save/load with audit trail; exportable lore compendium.

---

## 6) Data & Schemas (first pass)

### 6.1 World DB (Resource graph)
```ini
[gd_resource type="Resource" format=3]

[ext_resource type="Script" path="res://data/types/WorldDB.gd" id=1]

[resource]
script = ExtResource(1)
scenes = { "tavern_common": Resource("res://data/scenes/tavern_common.tres") }
entities = {
  "barkeep": {"type":"npc", "seen": true, "notes": ["Gives discounts if flattered."]},
  "mug": {"type":"item", "props": {"liquid": "ale"}}
}
history = [
  {"ts": "2025-10-29T05:04:00Z", "event": "scene_enter", "scene": "tavern_common"},
  {"ts": "2025-10-29T05:05:10Z", "event": "examine", "actor":"player", "target":"mug"}
]
```

### 6.2 Director → Narrator Envelope
```ini
[gd_resource type="Resource" load_steps=5 format=3]

[ext_resource type="Script" path="res://data/types/DirectorEnvelope.gd" id=1]
[ext_resource type="Script" path="res://data/types/NarrationEvent.gd" id=2]
[ext_resource type="Script" path="res://data/types/UIChoice.gd" id=3]

[sub_resource type="Resource" id=31]
script = ExtResource(2)
style = "world"
text = "A hush falls over the common room as the door swings shut."

[sub_resource type="Resource" id=32]
# Patch payload to be applied by your JsonPatch.gd
patch = {"op": "replace", "path": "/entities/mug/props/liquid", "value": "none"}

[sub_resource type="Resource" id=33]
script = ExtResource(3)
verb = "talk"
target = "barkeep"
label = "Talk to the barkeep"

[sub_resource type="Resource" id=34]
script = ExtResource(3)
verb = "buy_drink"
target = "barkeep"
label = "Buy a drink"

[resource]
script = ExtResource(1)
narration = [ SubResource(31) ]
patches = [ SubResource(32) ]
ui_choices = [ SubResource(33), SubResource(34) ]
```

### 6.3 NPC Behavior Trigger
```ini
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://data/types/NPCBehavior.gd" id=1]
[ext_resource type="Script" path="res://data/types/BehaviorTrigger.gd" id=2]

[sub_resource type="Resource" id=41]
script = ExtResource(2)
when = "on_arrival"
action = {"verb": "blunder", "target": "mug"}
narration = "The fool stumbles, knocking a mug to the floor."

[resource]
script = ExtResource(1)
id = "fool"
assertiveness = 0.7
triggers = [ SubResource(41) ]
```

---

## 7) Godot Project Layout
```
res://
 ├─ llm/
 │   ├─ PromptEngine.gd          # builds prompts, parses JSON, hot‑reload
 │   ├─ Director.gd               # turn phases, arbitration, patches
 │   ├─ Narrator.gd               # text voice formatting, styles
 │   ├─ CompanionAI.gd            # state vectors, triggers, delegation
 │   └─ parsers/JsonPatch.gd      # apply patches to World DB
 ├─ data/
 │   ├─ scenes/tavern_common.json
 │   └─ world_state.json
 ├─ ui/
 │   ├─ ChatWindow.tscn           # RichTextLabel + input
 │   ├─ ChoicePanel.tscn          # auto‑verbs → buttons
 │   └─ LorePanel.tscn            # overlay with entity facts
 └─ main/Game.tscn                # bootstrap + run loop
```

---

## 8) Implementation Notes
- **Narration Tone:** keep one consistent prose voice; style with italics and subtle color.
- **Safety Rails:** Director discards any action not in the current scene’s verb set.
- **Persistence:** begin with in‑memory dict + JSON autosave; evolve to an embedded DB if needed.
- **Optical Memory (later):** render session summaries with `Viewport` → PNG; attach to VLMs for dense recall.
- **Telemetry:** log all Director envelopes and LLM outputs for offline tuning.

---

## 9) MVP Task Checklist
- [ ] Chat UI with entity tagging & styles
- [ ] Choice panel bound to scene verbs
- [ ] Lore overlay reading from World DB
- [ ] `PromptEngine.gd` hot‑reload path working
- [ ] Director phases & JSON patch application
- [ ] 1 assertive arrival event + 1 supportive command
- [ ] Autosave world_state.json
- [ ] Playtest script for a 5–10 minute loop

---

## 10) Success Criteria (Vision)
- Players feel like they’re **in a conversation**, not using a command parser.  
- Companions feel like **co‑players** with opinions and occasional initiative.  
- The world feels **coherent and persistent** across scenes.  
- Designers can **edit logic live** and immediately see narrative changes.

---

**Outcome:** A foundation that marries chat intimacy with authored clarity and just‑enough emergence — ready to scale into a full dynamic campaign with cinematic combat, party drama, and a living lore graph.

