# Director: Runtime Orchestrator and LLM “Director” Prompt

This document describes the responsibilities, lifecycle, and decision boundaries of the runtime `Director` class and the conceptual “Director” prompt used by the LLM. It also proposes how companion/NPC actions should be integrated into the turn loop so NPCs can proactively affect the world.


## High-level goals

- Maintain authorial intent and world coherence while allowing emergent play.
- Keep core systems deterministic: turn order, validation, triggers, patch routing, inventory, and UI updates.
- Use the LLM selectively where it adds value: scene framing, dialog, outcome shaping, and on-demand content generation.
- Constrain the LLM via a clear prompt contract: what it can change, how it changes it, and how those changes are applied.


## Responsibilities of the runtime Director (class)

- Scene orchestration
  - Enter scenes, inject required entities (party/world), initialize action queue.
  - Frame initial narration (LLM-assisted) and emit UI state (choices, image path).
  - Evaluate scene enter triggers (deferred) to avoid racing initial narration.
- Turn/flow control
  - Maintain an action queue with player and NPCs.
  - Allow NPC interjections via triggers (opportunistic “tick.turn” checks).
  - Advance turns after actions; emit status for UI.
- Action resolution
  - Validate verbs and target entities before invoking the LLM.
  - Route navigation (exits/portals) deterministically.
  - For standard actions and “talk,” call LLM to generate narration and world changes.
- Patch and command application
  - Apply JSON patches within allowed roots (`props`, `state`, `lore`), with guardrails.
  - Handle engine-owned commands (e.g., `transfer`) deterministically.
  - Provide deterministic fallbacks (e.g., `take`) so gameplay remains responsive if the LLM omits changes.
- Optical Memory (optional)
  - Build vision context (chat transcript pages, lore mosaics) subject to configured budgets.
- Open areas (optional)
  - Generate ad hoc scenes via LLM, track completion conditions, and return to authored scenes.


## Responsibilities of the LLM “Director” prompt (concept)

- Provide diegetic narration that fits authored tone, rules, and current scene state.
- Shape outcomes of actions and conversations while respecting:
  - Allowed verbs and available targets.
  - Author-provided scene rules, tags, and world flags.
  - Visibility constraints (player-known information only where required).
- Propose state transitions via structured outputs:
  - Narration events (one or more lines; for “talk,” set speaker correctly).
  - JSON patches limited to permitted paths.
  - Engine commands (e.g., `transfer`) when inventory ownership moves are intended.
- Avoid structural mutations that break deterministic systems unless explicitly allowed.


## Where LLM is used vs. algorithmic systems

- LLM-directed
  - Scene entry framing (`process_narrator_request`) with optional vision context.
  - Player/NPC action outcomes (`process_action`) and dialog.
  - Freeform text interpretation (`process_freeform_input`).
  - Open area scene generation (generator service).
- Algorithmic
  - Turn order and interjections (action queue + triggers).
  - Verb/target validation, navigation (exits/portals), and UI choice generation.
  - Patch routing/guardrails, engine commands (e.g., `transfer`), inventory updates.
  - Open area completion checks and scene transitions based on history/flags.


## Pseudocode: runtime Director lifecycle

```pseudo
function enter_scene(scene_id):
  current_scene_id = scene_id
  world.flags["current_scene"] = scene_id
  world.history.append({ event: "scene_enter", scene: scene_id })

  scene = world.get_scene(scene_id)
  inject_party_entities(scene)
  inject_world_entities(scene)

  initialize_action_queue(scene)  // player + NPCs (with initiative, interjection flags)

  narrator_images = maybe_build_scene_vision(scene.image_path)
  narration_text = LLM.process_narrator_request(context(scene), narrator_images)
  emit_envelope({ narration: [world-style narration_text], ui_choices: build_choices(scene), scene_image_path })

  defer evaluate_scene_enter_triggers(scene)  // fires post-initial narration
```

```pseudo
function process_player_action(action):
  action.scene = current_scene_id

  // NPC interjections before player action
  for each interjection in check_interjections():
    execute_trigger_action(interjection.trigger, interjection.character_id)

  validate(verb in target.verbs)

  // Deterministic navigation
  if verb == "move" and target.type == "exit":
    return enter_scene(target.props["leads"])

  // Open area
  if verb == "enter" and target.type == "portal" and target.props["kind"] == "open_area":
    gen_scene = open_area_generator.generate(...)
    set_active_open_area(..., gen_scene)
    return enter_scene(gen_scene)

  character_context = (actor != "player") ? companion_ai.get_character_influence(actor) : {}

  images = maybe_build_optical_memory_images(history, lore, budgets)
  envelope = LLM.process_action(action, character_context, images)

  ensure_talk_speaker(envelope, action)  // first line style/speaker correctness

  apply_patches_with_guardrails(envelope.patches)   // props/state/lore only; record history
  process_engine_commands(envelope.commands)        // e.g., transfer
  deterministic_fallbacks_if_needed(action, envelope) // e.g., take

  world.history.append({ event: "action", actor, verb, target })
  action_queue.advance_turn()
  trigger_registry.advance_turn()
  emit_queue_update()

  envelope.ui_choices = build_choices(scene)
  emit_envelope(envelope)

  if maybe_complete_open_area(): return transition_envelope
  return envelope
```

```pseudo
function process_freeform_player_input(text):
  images = maybe_build_optical_memory_images(history, ...)
  envelope = LLM.process_freeform_input(scene, text, images)

  apply_patches_with_guardrails(envelope.patches)
  process_engine_commands(envelope.commands)

  world.history.append({ event: "freeform_input", text })
  action_queue.advance_turn()
  trigger_registry.advance_turn()
  emit_queue_update()

  envelope.ui_choices = build_choices(scene)
  emit_envelope(envelope)

  if maybe_complete_open_area(): return transition_envelope
  return envelope
```


## Companion/NPC actions: current state and proposed integration

- Current state
  - `process_companion_action(npc_id, verb, target, narration_override)` exists and ultimately routes through `process_player_action`, but it is not currently called by the turn loop; thus companions do not proactively act.
  - NPC interjections do occur via trigger checks (`tick.turn`) before player actions.

- Desired behavior
  - During the turn loop, non-interjection NPCs should consume their turns by proposing actions (verb/target), which the Director then resolves through the same LLM/patch pipeline.

- Proposed additions
  1) Add a “take NPC turns until player” step after each resolved envelope (player or freeform):

```pseudo
function take_queued_npc_turns_until_player():
  while action_queue.next_actor() != "player":
    npc_id = action_queue.get_next_actor()

    // Let CompanionAI decide whether to act and how
    maybe_trigger = companion_ai.should_act(npc_id, "tick.actor", "global", director_context())
    if maybe_trigger:
      await execute_trigger_action(maybe_trigger, npc_id)
      continue  // turn advanced by execute path

    // If no trigger, request an explicit action proposal (verb/target) from CompanionAI
    proposal = companion_ai.propose_action(npc_id, scene_snapshot())
    if proposal:  // { verb, target, narration_override? }
      await process_companion_action(npc_id, proposal.verb, proposal.target, proposal.narration_override or "")
    else:
      action_queue.advance_turn()  // idle / skip if no action

    emit_queue_update()
```

  2) Invoke `take_queued_npc_turns_until_player()` in:
     - The tail of `process_player_action` and `process_freeform_player_input`, right after emitting the envelope and before `_maybe_complete_open_area()`.
     - Optionally after scene enter, to allow immediate scene-driven NPC setup lines (if not already covered by scene.enter triggers).

  3) Extend `CompanionAI` with a lightweight `propose_action(...)` that returns either a deterministic action (based on initiative/relationships/state) or defers to an LLM-assisted decision when configured.

This preserves existing interjection semantics while enabling companions to proactively affect the world during their normal turns.


## LLM “Director” prompt contract

- Inputs
  - Scene snapshot: id, description, tags, image (optional), entity summaries.
  - Action request: actor, verb, target, scene, optional params/context.
  - World signals: relevant flags, recent history (truncated), optical memory images (optional).
  - Persona/context: speaker identity for “talk,” style rules, cartridge constraints.

- Outputs
  - Narration: one or more lines; first line’s `style`/`speaker` must be consistent with action type.
  - Patches: JSON Patch operations restricted to:
    - `/entities/<id>/props/...`
    - `/entities/<id>/state/...`
    - `/entities/<id>/lore/...`
    - `/characters/<id>/stats/...` (only where explicitly allowed)
  - Commands: engine-handled directives, e.g. `{ type: "transfer", from, to, item, quantity }`.

- Constraints
  - Do not add/remove entities unless explicitly requested by a specialized flow (e.g., open area generation).
  - Respect available verbs on the target entity; request engine navigation for exits/portals instead of patching location directly.
  - Avoid leaking information not available in-player context unless narratively required and permitted.
  - Keep patches minimal and targeted; prefer `replace` or `add` with correct path semantics.


## Determinism and guardrails

- All LLM effects must be expressed as patches/commands that the Director applies deterministically.
- The Director logs changes to history for traceability and Optical Memory production.
- The Director enforces path allowlists and converts `replace`→`add` when keys do not exist for a smoother UX.
- Inventory and ownership changes should go through commands where possible to keep invariants intact.


## Open areas

- Generation: invoked on entering a special portal; produces a temporary scene id.
- Completion: tracked by simple conditions (e.g., discover/interact) checked after each action.
- Return: upon meeting conditions, Director transitions back to the target authored scene.


## Implementation notes and next steps

- Integrate NPC turns
  - Implement `take_queued_npc_turns_until_player()` and wire it into the tail of action handlers.
  - Add `CompanionAI.propose_action(...)`; fall back to idle if none.
  - Keep interjections unchanged for opportunistic reactions.
- Expand the Director prompt in `PromptEngine`
  - Ensure `build_director_prompt(...)` includes explicit constraints and examples for patches/commands.
  - Consider small deltas: structured hints about allowed targets, verb meaning, and style rules.
- Telemetry
  - Log rejected patches/commands (by guardrails) and surface warnings for author tuning.
  - Track envelope sizes and image budgets for performance.


## Glossary

- Envelope: structured response containing narration, patches, commands, and UI deltas.
- Interjection: NPC action triggered opportunistically outside normal turn order.
- Optical Memory: on-demand visual context generated from transcript/lore for vision-enabled LLMs.


