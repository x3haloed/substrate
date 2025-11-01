# Substrate

Substrate is a Godot 4.5 narrative engine that fuses chat-first role‑play with a structured, inspectable world model. The world speaks in a narrator’s voice, companions act with believable autonomy, and every scene is both a story and a small database you can poke, search, and mutate—safely.

At its heart, Substrate treats each turn as a contract between three pillars:
- Narrator: expresses state and transitions in evocative text.
- Director: arbitrates actions, validates verbs, updates canonical state.
- WorldDB: a persistent resource graph (scenes, entities, characters, flags, history).

This separation keeps prose delightful without letting it corrupt state, and keeps state durable without forcing it to sound like a database.

## Quick Start

1. Open the project in Godot 4.5
2. Configure your LLM provider:
   - Click the "Settings" button in the bottom-right
   - Select your provider (OpenAI, OpenRouter, Ollama, or Custom)
   - Enter your API key (if required)
   - Enter the model name (e.g., `gpt-4o-mini` for OpenAI)
   - Click "Save"
3. Run the project (F5)

You should see: the narrator’s opening, scene entities represented as clickable tags in chat, on‑rails verbs as buttons, and a left/right inventory UI for the player and NPCs.

## LLM Provider Configuration

The project supports multiple LLM providers using the OpenAI v1 chat completions API:

- **OpenAI**: `https://api.openai.com/v1` (default)
- **OpenRouter**: `https://openrouter.ai/api/v1`
- **Ollama**: `http://localhost:11434/v1` (local)
- **Custom**: Enter your own API endpoint

Settings are saved to `res://llm/settings.tres` and persist between sessions.

## What it is (today)

- **Chat-first play**: Prose appears in a chat timeline; entities are auto‑tagged (`[barkeep]`, `[mug]`) and clickable.
- **On‑rails verbs**: Choice buttons come from authored scene verbs (e.g., `examine`, `take`, `move`).
- **Companion autonomy**: NPCs can interject via trigger rules; player can address NPCs directly.
- **Deterministic state**: The Director applies validated patches and engine commands to `WorldDB`.
- **Inventories**: Player has a typed `Inventory` resource; NPCs expose `contents` for trading and UI. Item weight/slots enforced; UI binds live and refreshes on change.
- **Freeform understanding**: The Director interprets unaddressed text and may emit engine‑handled commands like `transfer`.

## How it works

### Turn flow
1) Narrator frames the moment (atmospheric prose).
2) NPCs may interject (triggers) before the player acts.
3) Player selects a verb or types freeform.
4) Director resolves the action → updates `WorldDB` → Narrator describes results.
5) UI refreshes choices and inventories.

### State updates: Patches and Commands
- Patches: constrained JSON Patch into `entities/{id}/{props|state|lore}` and `characters/{id}/stats/...`.
- Commands: engine‑handled operations for structured changes the model should not author directly (e.g., `transfer` items):
  - `{ "type": "transfer", "from": "player|<entity_id>", "to": "<entity_id>", "item": "<entity_id>", "quantity": 1 }`

The model writes prose + small deltas; the engine enforces game rules.

## Project Structure

```
res://
 ├─ llm/
 │   ├─ PromptEngine.gd      # Builds prompts, parses JSON responses (schema with commands)
 │   ├─ Director.gd          # Turn phases, arbitration, patches, engine commands
 │   ├─ Narrator.gd          # Text formatting and styles
 │   ├─ CompanionAI.gd      # NPC behavior and triggers
 │   ├─ LLMClient.gd         # HTTP client for LLM API
 │   ├─ LLMSettings.gd       # Provider configuration resource
 │   └─ parsers/JsonPatch.gd # Apply JSON patches to world state
 ├─ data/
 │   ├─ scenes/              # Scene definitions (.tres)
 │   ├─ types/               # Core data types (Entity, SceneGraph, etc.)
 │   └─ world_state.tres     # Initial world database
 ├─ ui/
 │   ├─ ChatWindow.tscn      # Main chat interface
 │   ├─ ChoicePanel.tscn     # Action buttons
 │   ├─ PlayerInventoryPanel.tscn # Player inventory (binds to WorldDB.player_inventory)
 │   ├─ NPCPanel.tscn        # NPC tabs + inventory from scene entity contents
 │   ├─ LorePanel.tscn       # Entity information overlay
 │   └─ SettingsPanel.tscn   # LLM configuration UI
 └─ main/
     └─ Game.tscn            # Main game scene
```

## Development Notes

- Security: Keep API keys out of source; `res://llm/settings.tres` is treated as sensitive.
- Data: Character `.tres` may include large base64 portraits—avoid exposing in PRs.
- Serialization: Resources and `.tres` favored over ad‑hoc dictionaries to keep hot‑load stable.
- Editor UX: Prefer `@onready` bindings to avoid race conditions.

## Vision & Next Steps

Substrate aims to be the “narrative substrate” for party‑forward stories: companions with initiative, scenes that feel authored yet pliable, and a world you can interrogate without breaking immersion. See `substrate_vision_mvp.md` for the evolving roadmap:
- Linked scenes and travel affordances
- Expanded trigger language and drama systems
- Tactical encounters with cinematic narration
- Richer inventories (equipment, shops, crafting)
- Save/Load flows suitable for longer campaigns

