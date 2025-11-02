# Lore Authoring Workflow

This guide walks through creating and packaging lore entries with the new Lore system.

## Create & Edit Lore
- Open **Campaign Studio** from the main game UI and switch to the **Lore** tab.
- Click **Add** to create a new entry. Give it a unique `Entry ID` (used in manifests) and a title.
- Fill out the fields:
  - **Category**: short label such as `npc`, `item`, `faction`, etc.
  - **Summary**: a paragraph shown above the full article in the Lore panel.
  - **Article**: full BBCode-capable prose (your “wiki” text).
  - **Visibility**: choose when the entry is visible (`Always Visible`, `Unlock on Discovery`, or `Hidden`).
  - **Unlock Conditions**: optional one-per-line triggers like `discover:barkeep` or `flag:quest.start`.
  - **Tags** and **Notes**: comma-separated search tags and internal author notes.
- Use the **Related Entities** list to associate campaign entities:
  - Select an entity from the dropdown and press **Add**.
  - Press **Link as Global** to store the entry on the world’s global entity map so UI lookups resolve instantly.
- Press **Save Changes** to commit edits; the list updates immediately.

## Linking From Content
- In narration or UI strings, wrap a lore id with `[url=lore:entry_id]Label[/url]` to create clickable links.
- When entities share IDs with lore entries, the Lore panel opens automatically on click.

## Exporting in Cartridges
- When you export a campaign (`Export` button in Campaign Studio), the exporter writes:
  - `lore/<entry_id>.tres` for every entry.
  - `lore/lore_db.tres` with the lookup map used at runtime.
  - The cartridge manifest gains a `contents.lore` list for downstream tooling.
- Importing a `.scrt` cartridge rebuilds the Lore DB automatically, so lore entries travel with your campaign.

## Tips
- Keep entry IDs stable; they appear in manifests and unlock history.
- Use unlock conditions sparingly—`discover:entity_id` works well for gating entries behind in-scene discoveries.
- Tags improve future search and filtering; choose short, lowercase words.
- Notes stay hidden from players and can track revision history or TODO items.
