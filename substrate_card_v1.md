# Substrate Character Card v1 (substrate_card_v1)

This document defines the Substrate Character Card v1 specification for portable, reusable NPCs and companions across worlds and scenarios. It is inspired by and interoperable with the Tavern Character Card specifications.

- See Character Card V1: [spec_v1.md](https://github.com/malfoyslastname/character-card-spec-v2/blob/main/spec_v1.md)
- See Character Card V2: [spec_v2.md](https://github.com/malfoyslastname/character-card-spec-v2/blob/main/spec_v2.md)

Substrate uses Godot `.tres` Resources as the storage and runtime format. This spec describes fields and structures as they appear in `.tres` files, and how to import CC V1/V2 JSON-based cards into this format.

## Goals
- Portable characters that behave consistently across worlds and scenarios.
- Extensible stats and triggers without hardcoded model-specific fields.
- Clear, minimal inputs for prompting, narration, and direction engines.
- Backwards-compatible import from Tavern CC V1/V2.

## Spec identity
- `spec`: `"substrate_card_v1"`
- `spec_version`: `"1.0"`

These fields are stored as top-level properties on the character resource.

## Resource layout (.tres)
The canonical character file is a Godot Resource with a `CharacterProfile` script. Subresources hold triggers and the character book.

Example layout (abbreviated):

```ini
[gd_resource type="Resource" load_steps=5 format=3]

[ext_resource type="Script" path="res://data/types/CharacterProfile.gd" id="1"]
[ext_resource type="Script" path="res://data/types/TriggerDef.gd" id="2"]
[ext_resource type="Script" path="res://data/types/CharacterBook.gd" id="3"]
[ext_resource type="Script" path="res://data/types/CharacterBookEntry.gd" id="4"]

[sub_resource type="Resource" id="Book1"]
script = ExtResource(3)
name = "Archer Lore"
description = "Character-specific knowledge."
scan_depth = 32
token_budget = 1024
recursive_scanning = false
extensions = {}
entries = [SubResource(1001)]

[sub_resource type="Resource" id="1001"]
script = ExtResource(4)
keys = ["ambush", "threat", "cover"]
content = "The Archer prioritizes protecting the player and eliminating threats."
extensions = {}
enabled = true
insertion_order = 0

[sub_resource type="Resource" id="T1"]
script = ExtResource(2)
id = "cover_me"
namespace = "global"
when = "player.command.cover_me"
conditions = [{"left":"stats.bond_with_player","op":">=","right":0.5}]
action = {"verb":"cover","target":"player"}
narration = "The archer steps back, bow drawn, eyes scanning for threats."
priority = 50
cooldown = 1

[resource]
script = ExtResource(1)
spec = "substrate_card_v1"
spec_version = "1.0"
name = "Archer"
description = "A vigilant archer who watches over allies."
personality = "Alert, pragmatic, terse."
first_mes = "I’ll take the flank. Keep your head down."
mes_example = "Threat ahead. I’ll cover."
creator_notes = "Protective companion archetype."
system_prompt = "{{original}}"
alternate_greetings = []
tags = ["companion", "ranger"]
creator = "Substrate"
character_version = "1.0"
character_book = SubResource(Book1)
stats = {"mood":"alert","bond_with_player":0.6}
traits = ["protective","disciplined"]
style = {"voice":"terse","diction":"concise military"}
triggers = [SubResource(T1)]
extensions = {}
```

## Field definitions
All fields below are on the `CharacterProfile` resource unless specified.

- name: String (required)
- description: String (required)
- personality: String (required)
- first_mes: String (required)
- mes_example: String (required)
- creator_notes: String (optional; MUST NOT be used in prompts directly)
- system_prompt: String (optional; supports `{{original}}` placeholder)
- alternate_greetings: Array[String] (optional)
- tags: Array[String] (optional)
- creator: String (optional)
- character_version: String (optional)
- portrait_base64: String (optional; PNG image bytes encoded in base64)
  - Editor convenience: an inspector-only `portrait_image: Texture2D` proxy is exposed on `CharacterProfile` to preview and set the portrait without manual encoding. Changes are stored back into `portrait_base64` and the proxy itself is not serialized.
- character_book: Resource `CharacterBook` (optional; see below)
- stats: Dictionary<String, Variant> (optional; arbitrary keys like `mood`, `bond_with_player`, `favor_guildA`)
- traits: Array[String] (optional; stable descriptors that inform behavior)
- style: Dictionary<String, Variant> (optional; e.g., `voice`, `diction`, `pacing`, `register`)
- triggers: Array[Resource `TriggerDef`] (optional; portable and scenario-scoped triggers)
- extensions: Dictionary<String, Variant> (required; defaults to `{}`, MUST preserve unknown keys)
- spec: String (required) — must equal `substrate_card_v1`
- spec_version: String (required) — must equal `1.0`

Notes:
- Excluded from this spec: `scenario` and `post_history_instructions` from CC_v2. Scenario context is provided by the game world, and we do not use jailbreak fields.

## CharacterBook resource
A character-specific lorebook that stacks above the world book.

Minimal fields:
- name?: String
- description?: String
- scan_depth?: int
- token_budget?: int
- recursive_scanning?: bool
- extensions: Dictionary (required, default `{}`)
- entries: Array[Resource `CharacterBookEntry`]

`CharacterBookEntry` minimal fields:
- keys: Array[String]
- content: String
- extensions: Dictionary (required, default `{}`)
- enabled: bool
- insertion_order: int
- Optional: `case_sensitive`, `priority`, `id`, `comment`, `selective`, `secondary_keys`, `constant`, `position`

These mirror CC_v2 semantics where applicable, stored as `.tres`.

## TriggerDef resource
Triggers define when a character should propose an intent.

Fields:
- id: String (unique within the character)
- namespace: String (`"global"` for portable triggers; `"scenario.<id>"` for scenario-scoped)
- when: String (event selector; e.g., `scene.enter`, `player.command.cover_me`, `tick.turn`)
- conditions: Array[Dictionary] (optional; simple predicates, see below)
- action: Dictionary — `{ verb: String, target: String, params?: Dictionary }`
- narration: String (optional; suggested line or narrator text)
- priority: int (higher runs earlier; typical range 0–100)
- cooldown: float (optional; turns or seconds as defined by the engine)

Condition triplets use:
- left: String (dotted path; e.g., `stats.mood`, `world.flags.danger`, `scene.tags.includes.bandit`)
- op: One of `==`, `!=`, `>`, `>=`, `<`, `<=`, `includes`, `not_in`, `exists`, `true`, `false`
- right: Variant (optional for unary ops like `exists/true/false`)

## Namespacing and portability
- Global triggers MUST reference only global events and generic verbs/targets.
- Scenario triggers MUST set `namespace = "scenario.<id>"` and may reference scenario-specific events/verbs.
- Engines evaluate triggers by priority, then by recency/cooldown, then by tie-break rules.

## Prompting integration (informative)
The direction/prompting stack composes:
1. World system prompt → Character `system_prompt` (with `{{original}}` merge)
2. Active scene summary (entities, verbs, constraints)
3. Character core: `description`, `personality`, `traits`, `style`
4. Character/world books (within `token_budget`)
5. Recent dialogue/history
6. Current `stats` snapshot and matched triggers (as rationale)

## Import compatibility
Substrate supports importing Tavern-style CC V1 and CC V2 cards, converting to `.tres`.

Mapping (V1):
- `name`, `description`, `personality`, `first_mes`, `mes_example` → direct
- No `system_prompt`, `creator_notes`, `tags` in V1 → default empty
- `extensions` → `{}` by default; preserve unknown keys if provided
- No `scenario` or `post_history_instructions` → ignored

Mapping (V2):
- `spec/spec_version` are recognized but replaced with Substrate `spec/spec_version`
- `data.name`, `description`, `personality`, `first_mes`, `mes_example` → direct
- `data.creator_notes`, `system_prompt`, `alternate_greetings`, `tags`, `creator`, `character_version` → direct
- `data.character_book` → `CharacterBook` + `CharacterBookEntry` resources
- `data.extensions` → copied into `extensions`
- Exclude `scenario` and `post_history_instructions`

Triggers/stats:
- CC V1/V2 have no native `stats`/`triggers`; importer MAY infer defaults (e.g., empty dict/array). Users can extend after import.

## Validation rules
- `spec` MUST equal `substrate_card_v1` and `spec_version` MUST equal `1.0`.
- `extensions` MUST exist and default to `{}`; unknown keys MUST be preserved round-trip.
- All arrays/dicts SHOULD be serializable as Godot Variants.

## Versioning
- Backwards-compatible changes will bump `spec_version` minor (e.g., `1.1`).
- Breaking changes will bump major (e.g., `2.0`).

## Appendix A: Minimal Archer example (.tres)

```ini
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://data/types/CharacterProfile.gd" id="1"]

[resource]
script = ExtResource(1)
spec = "substrate_card_v1"
spec_version = "1.0"
name = "Archer"
description = "A vigilant archer who watches over allies."
personality = "Alert, pragmatic, terse."
first_mes = "I’ll take the flank. Keep your head down."
mes_example = "Threat ahead. I’ll cover."
creator_notes = ""
system_prompt = "{{original}}"
alternate_greetings = []
tags = []
creator = ""
character_version = "1.0"
character_book = null
stats = {"mood":"alert","bond_with_player":0.6}
traits = ["protective","disciplined"]
style = {"voice":"terse"}
triggers = []
extensions = {}
```

---

This document is normative for Substrate character resources. Engine integrations (Director, PromptEngine, TriggerRegistry) must treat unspecified fields as optional and preserve unknown `extensions` data.
