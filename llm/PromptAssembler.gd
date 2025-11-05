extends RefCounted
class_name PromptAssembler

## Shared builder for NPC prompts using CharacterProfile fields
## Produces an OpenAI-style messages array [{role, content}]

const TOKENS_PER_CHAR: float = 0.25  # rough heuristic ~4 chars per token

static func _merge_system_prompt(card_system_prompt: String, base_system_prompt: String) -> String:
    var card_prompt := str(card_system_prompt)
    if card_prompt.strip_edges() == "":
        return base_system_prompt
    return card_prompt.replace("{{original}}", base_system_prompt)

static func _estimate_tokens(s: String) -> int:
    if typeof(s) != TYPE_STRING or s == "":
        return 0
    return int(ceil(float(s.length()) * TOKENS_PER_CHAR))

static func _select_lore_entries(character: CharacterProfile, player_text: String) -> Array[String]:
    return []
    # var selections: Array[String] = []
    # if character == null or character.character_book == null:
    #     return selections
    # var book := character.character_book
    # var budget_tokens: int = max(0, int(book.token_budget))
    # var depth: int = max(1, int(book.scan_depth))
    # var recursive := bool(book.recursive_scanning)

    # # Derive naive keywords from player utterance; fall back to character tags
    # var text := str(player_text)
    # var words: Array[String] = []
    # if text != "":
    #     for w in text.split(" "):
    #         var ww := w.strip_edges().to_lower()
    #         if ww != "" and ww not in words:
    #             words.append(ww)
    # if words.is_empty() and character.tags is Array:
    #     for t in character.tags:
    #         var tt := str(t).strip_edges().to_lower()
    #         if tt != "" and tt not in words:
    #             words.append(tt)
    # # Limit by scan depth
    # if words.size() > depth:
    #     words = words.slice(0, depth)

    # var matched_entries = book.find_entries_by_keys(words)
    # # If recursive and nothing matched, try progressively shorter key sets
    # if matched_entries.is_empty() and recursive and words.size() > 1:
    #     for k in range(words.size() - 1, 0, -1):
    #         matched_entries = book.find_entries_by_keys(words.slice(0, k))
    #         if not matched_entries.is_empty():
    #             break

    # # Respect insertion order from CharacterBook.get_enabled_entries via find_entries_by_keys
    # var used_tokens := 0
    # for entry in matched_entries:
    #     if not entry or typeof(entry.content) != TYPE_STRING:
    #         continue
    #     var content: String = entry.content
    #     var add_tokens := _estimate_tokens(content)
    #     if budget_tokens <= 0 or used_tokens + add_tokens <= budget_tokens:
    #         selections.append(content)
    #         used_tokens += add_tokens
    #     else:
    #         break
    # return selections

static func _build_character_context(character: CharacterProfile) -> Dictionary:
    var ctx := {}
    if character == null:
        return ctx
    ctx["name"] = character.name
    ctx["description"] = character.description
    ctx["personality"] = character.personality
    ctx["traits"] = character.traits
    ctx["style"] = character.style
    ctx["stats"] = character.stats
    ctx["tags"] = character.tags
    return ctx

static func build_npc_messages(character: CharacterProfile, player_text: String, scene_info: Dictionary, chat_snapshot: Dictionary, base_system_prompt: String, macro_ctx: Dictionary = {}) -> Array[Dictionary]:
    # 1) System prompt (merge card.system_prompt if provided)
    var sys_content := _merge_system_prompt(character.system_prompt, base_system_prompt) if character else base_system_prompt
    sys_content = MacroExpander.expand(sys_content, macro_ctx)
    var messages: Array[Dictionary] = [
        {"role": "system", "content": sys_content}
    ]

    # 2) Inject example dialogues if present (as an additional system hint)
    if character and typeof(character.mes_example) == TYPE_STRING and character.mes_example.strip_edges() != "":
        var mesx := MacroExpander.expand(character.mes_example.strip_edges(), macro_ctx)
        messages.append({
            "role": "system",
            "content": "Example dialogues (character and user):\n" + mesx
        })

    # 3) Build lorebook injections using keys/budget/depth
    var lore_injections := _select_lore_entries(character, player_text)

    # 4) Compose user payload
    var user_payload := {
        "player_message": str(player_text),
        "character": _build_character_context(character),
        "scene": scene_info,
        "chat_snapshot": chat_snapshot
    }
    if lore_injections.size() > 0:
        user_payload["lorebook"] = lore_injections

    messages.append({"role": "user", "content": JSON.stringify(user_payload, "\t")})
    return messages


