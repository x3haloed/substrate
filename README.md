# Substrate MVP

An elevated group-chat RPG where the *world itself* speaks, companions truly act, and every scene is both a story and a searchable database.

## Quick Start

1. Open the project in Godot 4.5
2. Configure your LLM provider:
   - Click the "Settings" button in the bottom-right
   - Select your provider (OpenAI, OpenRouter, Ollama, or Custom)
   - Enter your API key (if required)
   - Enter the model name (e.g., `gpt-4o-mini` for OpenAI)
   - Click "Save"
3. Run the project (F5)

## LLM Provider Configuration

The project supports multiple LLM providers using the OpenAI v1 chat completions API:

- **OpenAI**: `https://api.openai.com/v1` (default)
- **OpenRouter**: `https://openrouter.ai/api/v1`
- **Ollama**: `http://localhost:11434/v1` (local)
- **Custom**: Enter your own API endpoint

Settings are saved to `res://llm/settings.tres` and persist between sessions.

## MVP Features

- **Chat Window**: Main narrative display with entity tags (`[barkeep]`, `[mug]`) that are clickable
- **Choice Panel**: Auto-generated action buttons from scene verbs
- **Lore Overlay**: Click entity tags to view their canonical information
- **Companion AI**: 
  - Assertive NPCs can act on arrival (e.g., Fool trips and knocks over a mug)
  - Supportive NPCs respond to commands (e.g., "cover me" triggers Archer)
- **World State**: Persistent world database tracking entities, history, and flags
- **Director System**: Arbitrates actions, validates verbs, applies patches

## Project Structure

```
res://
 ├─ llm/
 │   ├─ PromptEngine.gd      # Builds prompts, parses JSON responses
 │   ├─ Director.gd          # Turn phases, arbitration, patches
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
 │   ├─ LorePanel.tscn       # Entity information overlay
 │   └─ SettingsPanel.tscn   # LLM configuration UI
 └─ main/
     └─ Game.tscn            # Main game scene
```

## Hot Reload

The `PromptEngine.gd` script is designed to support hot-reload. To enable this feature in the future, you can modify the Director to reload the PromptEngine script dynamically using `ResourceLoader.load()` with `CACHE_MODE_IGNORE`.

## Development Notes

- World state persistence is currently in-memory with .tres resource files
- The Director validates all actions against scene verb lists for safety
- Entity tags in narration (`[entity_id]`) are automatically made clickable
- JSON Patch format is used for all world state updates

## Next Steps

See `substrate_vision_mvp.md` for the full roadmap including:
- Multiple linked scenes
- Persistent world memory with history
- Party autonomy and drama systems
- Cinematic combat
- Dynamic campaign generation

