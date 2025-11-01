# Fantasy Theme Documentation

## Overview

A medieval fantasy theme inspired by classic RPG aesthetics, featuring warm earth tones, ornate borders, and texture-inspired backgrounds. The theme transforms the Substrate UI into an immersive fantasy experience.

## Color Palette

### Primary Colors
- **Background**: Slate gray gradient (`#48506B` → darker slate)
- **Text Primary**: Warm yellow (`#FCFCDC`)
- **Text Secondary**: Golden yellow (`#FCFCD8`)
- **Accent**: Bright gold (`#D29D15`)

### Material Colors
- **Stone**: Dark brown (`#5D4E37`) with sienna accents (`#8B7355`)
- **Wood**: Saddle brown (`#8B4513`) with sandy brown (`#D2691E`)
- **Metal**: Dark slate (`#2F4F4F`) with slate gray (`#708090`)
- **Scroll/Parchment**: Wheat (`#F5DEB3`) with burlywood (`#DEB887`)

### Border Colors
- Primary border: Saddle brown (`#8B4513`)
- Accent border: Sandy brown / golden (`#D2A11E`)

## Component Styling

### Panel Backgrounds

1. **Stone Background** (Inventory Panel, Choice Panel)
   - Base color: `#5D4E37`
   - 3px borders in saddle brown
   - 2px corner radius

2. **Wood Background** (Headers, Footers)
   - Base color: `#8B4513`
   - 3px bottom border in golden brown
   - Used for panel headers and toolbars

3. **Metal Background** (Stats Sidebar, Tab Bars)
   - Base color: `#2F4F4F`
   - 3px borders with slate gray accent
   - Gives a metallic, armor-like appearance

4. **Scroll Background** (Chat windows, NPC panels)
   - Base color: `#F5DEB3` (parchment)
   - 3px borders in brown
   - Evokes ancient scrolls and manuscripts

### Interactive Elements

**Buttons**
- Normal: Wood background with 2px border
- Hover: Lighter wood tone (`#B85E2E`)
- Pressed: Darker wood (`#6B2B08`)
- Text: Warm yellow (`#FCFCDC`)

**Input Fields**
- Background: Light parchment (`#F5F0C8`)
- Border: Dark brown (2px)
- Focus: Golden border (`#D2A11E`)
- Text color: Black for readability

**Progress Bars**
- Background: Black with brown border
- Fill: Green gradient (health/progress indicator)

### Typography

- Default font size: 14px
- Headers: 16-20px
- All text uses warm yellow tones for fantasy atmosphere
- Terminal-style green text (`#32CD32`) for chat logs

## File Structure

```
res://ui/
  ├── fantasy_theme.tres       # Main theme resource
  ├── ChatWindow.tscn          # Scroll/parchment style
  ├── InventoryPanel.tscn      # Stone panel with metal sidebar
  ├── ChoicePanel.tscn         # Stone panel for actions
  ├── NPCInventoryPanel.tscn   # Scroll/parchment style
  ├── WhisperChatPanel.tscn    # Scroll/parchment style
  ├── SettingsPanel.tscn       # Modal with theme
  └── CardEditor.tscn          # Modal with theme
```

## UI Layout

### Main Game Window
```
┌─────────────────────────────────────────┐
│ ⚔ SUBSTRATE [Card Editor] [Settings]   │  ← Wood header
├─────────┬───────────────┬───────────────┤
│         │               │               │
│ Player  │ Chat Window   │ NPC           │
│ Inv.    │ (Chronicle)   │ Inventory     │
│         │               │               │
│ (Stone) │ (Scroll)      │ (Scroll)      │
│         ├───────────────┤               │
│         │ Action Panel  │               │
│         │ (Stone)       │ Whisper Chat  │
│         │               │ (Scroll)      │
└─────────┴───────────────┴───────────────┘
```

### Panel Hierarchy

1. **Left Panel** - Player Inventory
   - Stone background
   - Metal stats sidebar
   - Wood header and footer
   - Grid layout for items

2. **Center Panel** - Main game area
   - Chat window with scroll background
   - Black terminal-style log area
   - Action choice panel with stone background

3. **Right Panel** - NPC interactions
   - NPC Inventory with scroll background
   - Whisper chat with scroll background
   - Tab navigation for multiple NPCs

## Design Principles

1. **Visual Hierarchy**: Wood for headers, stone for containers, scroll for content areas
2. **Consistency**: All borders use warm brown/gold tones
3. **Readability**: Light text on dark backgrounds, dark text on light backgrounds
4. **Fantasy Immersion**: Material-inspired textures evoke medieval settings
5. **Accessibility**: Sufficient contrast ratios for all text elements

## Customization Notes

To modify the theme:
1. Edit `res://ui/fantasy_theme.tres` for global changes
2. Individual panels have local StyleBox resources for specific styling
3. Colors follow RGB values specified in the HTML reference
4. All measurements in pixels for precise control

## Credits

Theme design based on classic fantasy RPG aesthetics, with inspiration from medieval manuscripts, armor smithing, and tavern aesthetics.

