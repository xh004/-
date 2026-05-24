# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Balatro clone built with Godot 4.6 (GDScript, Mobile renderer, D3D12 on Windows, Jolt physics). Resolution 1280×720. UI, comments, and some filenames use Chinese.

Full project documentation is in [AGENTS.md](AGENTS.md).

## Running

Open the project root in Godot 4.6+ editor and press F5. The main scene is `scence/main.tscn`. No build steps — GDScript is interpreted.

## Architecture

Five AutoLoad singletons (registered in `project.godot`) drive all game state:

| Singleton | File | Responsibility |
|---|---|---|
| `DeckManager` | [Manager/DeckManager.gd](Manager/DeckManager.gd) | Deck init (52 cards + test mode with random seals/enhancements), draw, shuffle |
| `HandManager` | [Manager/HandManager.gd](Manager/HandManager.gd) | Hand management: select, play, discard, draw replacement, drag-to-reorder |
| `ScoreManager` | [Manager/ScoreManager.gd](Manager/ScoreManager.gd) | Hand evaluation (12 hand types), scoring with level progression, round settlement |
| `MoneyManager` | [Manager/MoneyManager.gd](Manager/MoneyManager.gd) | Money add/spend with signals |
| `JokerManager` | [Manager/JokerManager.gd](Manager/JokerManager.gd) | Joker ownership (max 5), unified trigger dispatch, drag-to-reorder |

**Key patterns:**
- **Signal-driven communication**: Managers emit signals (e.g. `ScoreManager.score_changed`, `ScoreManager.round_cleared`) consumed by `scence/main.gd` to update UI labels.
- **Panel-slot layout**: Hand and joker areas use `HBoxContainer` with transparent `Panel` slots. Each card/joker lives inside a Panel; ordering is controlled by Panel index.
- **State machine**: `PlayingCard` uses a `CardState` enum (NORMAL → HOVER → SELECTED → DRAGGING → PLAYED → DISCARDED).
- **ID-driven jokers**: `JokerCard` uses a single class with all effects in `on_trigger()` dispatched by `joker_id` — no subclasses.

## Data flow (play hand)

1. Player selects cards → clicks "出牌" → `HandManager.play_selected_cards()`
2. `JokerManager.trigger_all(INDEPENDENT)` then `trigger_all(ON_HAND_PLAYED)` then per-card `trigger_all(ON_CARD_SCORED)`
3. `ScoreManager.evaluate_hand()` determines hand type; only scoring cards contribute chips/mult
4. Seal effects (gold seal +money, red seal re-scores) and enhancement bonuses (+30 chips, +4 mult) applied
5. `ScoreManager.recalculate()` → `chips × mult` added to game total
6. Cards destroyed, replacements drawn, `check_round_end()` compares `game_total_score >= target_score`

## Key files

- [card/Playingcard.gd](card/Playingcard.gd) — `class_name PlayingCard extends Control` with suit/rank/value/seal/enhancement, card states, drag-and-drop, atlas-texture rendering from `8BitDeck.png`
- [joker/JokerCard.gd](joker/JokerCard.gd) — `class_name JokerCard extends Control`, id-driven effects, tooltip, drag-to-reorder
- [scence/main.gd](scence/main.gd) — Main scene script: wires UI labels to manager signals, test joker button, game-over flow
- [Manager/ScoreManager.gd](Manager/ScoreManager.gd) — `HAND_DATA` table with base chips/mult and per-level growth for all 12 hand types; `evaluate_hand()`, `get_scoring_cards()`
- [resources/textures/2x/](resources/textures/2x/) — Sprite sheets: `8BitDeck.png` (cards, 142×190 per cell, 14 cols), `Enhancers.png` (seals/enhancements), `Jokers.png` (jokers)

## Testing

No automated test framework. Logic is verified via `print()` output in the editor console. If adding tests, use [GUT](https://github.com/bitwes/Gut) and prioritize: `ScoreManager.evaluate_hand()` edge cases, `get_scoring_cards()`, `JokerCard.on_trigger()` per-id correctness, `PlayingCard._calculate_value()`.

## Notable quirks

- Directory is named `scence/` (not `scene/`) — paths in `project.godot` and scripts depend on this
- Two AutoLoad singletons use UID references, two use `res://` paths (see `project.godot` `[autoload]`)
- Only joker IDs 0–9 have real effects; IDs 10–159 default to "未知小丑" with no effect. `add_random_joker()` uses `randi() % 10`
- Some seals (purple, blue) and enhancements (stone, gold, wild, glass, lucky, steel) have textures configured but no gameplay logic
- Audio files exist in `resources/sounds/` and `Balatro OST/` but aren't played by any code
- Settings and Stats buttons on the main menu are stubs (`print("S")` / `print("A")`)
- Root-level `joker.gd` is a dead empty stub (`extends Control`)
