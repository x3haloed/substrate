# Editor: Canon, Continuity, and Constraint Enforcement

This document defines the “Editor” system: a separate LLM-powered oversight agent that audits and optionally corrects outputs from other generative steps to preserve canon, prevent game-breaking actions, and maintain campaign tone and setting. It complements the `Director` (runtime orchestrator + LLM “Director” prompt) by acting as a compliance gate.


## Why a separate Editor agent?

- Separation of concerns: avoids contaminating the “in-character” or “narrator” generation with out-of-band omniscient knowledge (locked lore). The Editor can see everything; actors only see what they should.
- Deterministic guardrails: centralizes acceptance criteria and redlines into one service with clear policies and structured return types.
- Safer feedback loop: the Editor can issue non-leaking “editor notes” that instruct the originating model to self-correct without revealing locked facts.


## Scope of review

The Editor audits four output classes before they reach the UI or mutate state:

1. Player freeform actions (requests + proposed effects)
2. NPC action requests/proposals (trigger or CompanionAI-proposed)
3. NPC dialog (LLM-generated lines)
4. Narrator dialog (scene framing, transitions)

Additionally, the Editor reviews open-area generation requests to prevent immersion/canon breaks (e.g., medieval vs. space setting mismatch).

Self-continuity is enforced for all four classes: each proposed line/action is checked against prior statements and actions (from the transcript and history) to catch contradictions or unjustified reversals. When conflicts are detected, the Editor issues a non-leaking editor note requesting corrected output that preserves the character’s own established knowledge and behavior.


## Inputs and data access

- Full-context access (omniscient):
  - All lore DBs, including locked entries
  - All character profiles
  - Full chat transcript (or summarized windows), with per-actor retrieval to check self-continuity
  - World flags and history (summarized or scoped by policy)
- Proposed output (to review):
  - The envelope or partial product: narration lines, patches, commands, or scene-gen request
  - The originating “channel” (NPC, narrator, player freeform) and actor identity when relevant

Optical Memory (OM) mode:

- When OM is ON (per `LLMSettings`), the Editor uses maximal context by default: stuff ALL chat history, ALL lore DBs (locked and unlocked), and ALL world flags/history into OM pages when prompting the LLM for review.
- Summarization/RAG/truncation is only applied when absolutely necessary (e.g., hard context window limits). Until performance work later, prefer completeness over latency/cost.


## Editor decisions (return type)

```gdscript
# Conceptual shape; actual implementation in GDScript Resources
class_name EditorDecision
var status: String    # "approve" | "revise" | "block"
var reasons: Array[String]   # machine-readable reason codes (e.g., "CANON_VIOLATION", "SELF_CONTRADICTION", "GAME_BREAKING", "TONE_MISMATCH")
var notes: String     # short human-readable explanation for logs
var editor_note: String  # instruction for self-correction sent back to the originating LLM (must not leak locked info)
var redlines: Dictionary   # optional surgical edits (e.g., replacing a line) if revision is trivial/safe
```

Policies decide which status to emit:

- approve: product flows as-is
- revise: send `editor_note` back to the same generator to re-run once (or apply `redlines` when trivial)
- block: reject; return a safe alternative (neutral line, refusal, or suggested options)


## Editor policies

Policies are composable checks; each can emit a violation with a reason code.

- CanonPolicy: checks claims against locked and unlocked lore
- ContinuityPolicy: checks self-consistency against the actor’s prior statements and actions (and, for narrator, prior established facts). Uses per-actor transcript windows and history lookups; flags contradictions with `SELF_CONTRADICTION`. Provides editor notes that instruct a corrected response without leaking hidden facts.
- TonePolicy: checks style/tone constraints per cartridge
- MechanicsPolicy: prevents illegal verbs/overpowered effects (e.g., “grant god powers”)
- ArcPolicy: prevents premature removal of key characters or derailing critical beats
- SettingPolicy: prevents mismatched scene generation (e.g., medieval artifacts in a space opera unless justified)

Each policy can be implemented as a heuristic pass, a retrieval-augmented LLM pass, or both. Keep passes cheap by default; escalate to LLM only when heuristics detect risk.

Heuristic approval rule:

- Heuristics may BLOCK output (when they confidently detect violations), but they may NOT APPROVE output as final.
- Any item that passes heuristics without being blocked must be escalated to an LLM review before it is emitted or applied.


## Integration points in the runtime

The Editor sits between generation and application/emit:

```pseudo
// NPC/Player action
envelope = PromptEngine.process_action(...)
decision = EditorEngine.review_envelope(envelope, context=omniscient_context, channel="npc|player")
if decision.status == "approve":
  apply_patches_and_commands(envelope)
  emit_to_ui(envelope)
elif decision.status == "revise":
  revised = PromptEngine.process_action_with_editor_note(..., decision.editor_note)
  // single retry limit
  apply_or_block_based_on_second_review(revised)
else: // block
  emit_safe_denial_or_alternative(decision)

// Narrator framing
text = PromptEngine.process_narrator_request(...)
decision = EditorEngine.review_narration(text, context, channel="narrator")
apply_redlines_or_retry_then_emit(text, decision)

// Freeform input
pre = EditorEngine.precheck_player_request(text, context) // cheap heuristics (e.g., "grant omnipotence" denial)
if pre.block: emit_denial(pre); return
envelope = PromptEngine.process_freeform_input(...)
post = EditorEngine.review_envelope(envelope, context, channel="player_freeform")
apply_or_retry_or_block(post)

// Open area generation
req = OpenAreaRequest(def, ...)
guard = EditorEngine.review_open_area_request(req, context)
if guard.block: emit_denial(guard); return
scene_id = OpenAreaGenerator.generate(def, ...)
```

Retry policy: at most one Editor-guided regeneration (to avoid loops and latency spikes). If the second attempt still violates, block.


## “Editor note” contract (non-leaking)

- Must reference constraints without revealing hidden facts.
- Example (Luke’s father case): “You do not know who your father is. Respond without asserting knowledge of your parentage.”
- Example (overpowered request): “The game rules prohibit omnipotence. Offer grounded alternatives consistent with your abilities.”


## Interfaces

Proposed new classes:

- `llm/EditorEngine.gd`:
  - `review_envelope(envelope, context, channel) -> EditorDecision`
  - `review_narration(text, context, channel) -> EditorDecision`
  - `precheck_player_request(text, context) -> EditorDecision`
  - `review_open_area_request(req, context) -> EditorDecision`
- `llm/EditorPolicy.gd` (+ concrete subclasses): policy composition and execution

Configuration:

- `LLMSettings.tres` or a dedicated `EditorSettings.tres`:
  - enable flags per channel (npc, narrator, player, open_area)
  - retry limits, latency budgets
  - which policies are active


## Story guidance vs. compliance

- Editor = compliance (stop bad, request fixes)
- Director (plus a new ArcPlanner) = guidance (nudge toward beats)

Introduce `llm/ArcPlanner.gd` for forward pressure:

- Data: `StoryArc` resource with beats (milestones, gating conditions, suggested triggers)
- Signals: “beat due”, “beat completed”
- Hooks:
  - Augment PromptEngine system messages (soft guidance)
  - Schedule NPC triggers (hard guidance) via `TriggerRegistry`
  - Suggest scene modifiers (environmental cues) via deterministic patches

The Editor ensures nothing violates canon/mechanics, while the ArcPlanner suggests next plausible steps. The Director arbitrates both.


## Performance considerations

- With OM ON: prefer maximal context (ALL transcript, lore, flags/history) for review; only summarize/truncate/RAG when the context window is exceeded or absolutely necessary.
- Cache lore retrieval by topic/ID; include reason codes for telemetry.
- Apply one-pass approval for non-risk content only after LLM review; heuristics alone cannot approve.


## Telemetry and tooling

- Log reason codes and notes for rejected content.
- Surface warnings in a dev-only panel (e.g., `ui/SettingsPanel` advanced tab) with counts and latest examples.
- Provide test fixtures with locked/unlocked lore to regression-test policies.


## Rollout plan

1) Implement `EditorEngine` with CanonPolicy + MechanicsPolicy minimal heuristics.
2) Wire Editor post-generation in `Director.process_action` and `process_freeform_player_input` (single retry).
3) Add narrator and open-area checks.
4) Add TonePolicy and SettingPolicy.
5) Introduce `ArcPlanner` and data resources for beats, then add soft guidance to prompts.


