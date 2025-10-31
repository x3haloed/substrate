# Repository Guidelines

## Project Structure & Module Organization
Substrate is a Godot 4.5 workspace. Core gameplay lives in `res://main/Game.tscn` with neighboring `Game.gd`. Systems under `res://llm` coordinate prompt building, narration, companions, and JSON patch parsers; keep cross-module calls flowing through the Director or PromptEngine to preserve turn order. UI scenes and scripts live in `res://ui`, while narrative assets sit in `res://data` (`scenes/`, `types/`, `world_state.tres`). Shared utilities belong in `res://tools`, and new resources should follow the existing `.tres` naming so they hot-load cleanly in the editor.

## Coding Style & Naming Conventions
Scripts are GDScript with 4-space indentation. Use `class_name` for globally accessible types (`CharacterCardLoader`, `WorldDB`), PascalCase for classes/scenes, snake_case for members and functions, and SCREAMING_SNAKE_CASE for constants. Keep exported resource properties grouped at the top of a script, followed by signal declarations. Favor composable Godot resources (`.tres`, `.tscn`) instead of ad-hoc dictionaries, and prefer explicit `@onready var` bindings to avoid race conditions.

## Commit & Pull Request Guidelines
Commit history favors concise, imperative titles (`add rule to avoid base64 fields in tres files`). Keep commits scoped to one concern and include context in the body when modifying serialized resources. Pull requests should state the player-facing change, affected Godot scenes/resources, and any new external configuration (LLM provider, API keys). Link roadmap issues when relevant and attach screenshots or short clips for UI work so reviewers can validate without rebuilding. Avoid committing provider credentials; confirm `res://llm/settings.tres` stays out of source control.

## Security & Configuration Tips
API credentials reside in local Godot editor settings and `res://llm/settings.tres`. Treat that file as sensitive—do not check in real keys, and scrub them before sharing logs. When testing against local models (Ollama or custom endpoints), prefer `.env` or editor overrides rather than hardcoding URLs in scripts.

## Data Handling
CharacterProfile `.tres` files can include massive base64 blobs that are unsafe to move around in reviews or prompts.

- Skip any `*_base64` properties (for example, `portrait_base64`) when opening these resources.
- If you need to detect them programmatically, look for `^(\\s*[A-Za-z0-9_]+_base64\\s*=).*$` or `^(\\s*[A-Za-z0-9_]+_base64\\s*=\\s*)(?:\\[\\s*$[\\s\\S]*?^\\s*\\]\\s*$|"[\\s\\S]*?")`.
