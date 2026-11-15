# TileWise

An offline Scrabble-like word game (Flutter, Android-first).

**Working title:** TileWise (checked — no Play Store collision) · package `com.rocky.tilewise`

## What's inside (M1 + M2 combined)

- Full 15×15 board rules: 100-tile bag, DL/TL/DW/TW premium squares,
  center-star first move, dictionary validation, blanks, exchange, pass,
  50-point bingo, proper end-game tally.
- **Pass & Play:** 2–4 players on one phone (selectable in setup, with names).
- **Vs Computer:** Easy / Medium / Hard AI. Real move generation
  (anchor-based trie search with cross-checks) running in a background
  isolate so animations never stutter.
- Animated UI everywhere: flipping title tiles, drifting tile background,
  springy tile landings, drag-and-drop with highlight, floating score
  popups, count-up score chips, turn banners, shake-on-error, bouncing
  "thinking" dots, confetti + count-up game-over screen.
- Synthesized sound effects (zero licensing): place, click, error, win,
  turn, shuffle.
- 359k-word bundled dictionary — fully offline, no permissions needed.

## Project layout

```
lib/
  main.dart            app entry + boot/loading screen
  game/
    tiles.dart         tile model + 100-tile distribution
    board.dart         15×15 board + standard premium layout
    dictionary.dart    word set + trie
    rules.dart         move validation + scoring (shared by UI and AI)
    ai.dart            anchor-based move generator (isolate-safe)
    ai_engine.dart     persistent AI isolate wrapper
    game_state.dart    turn engine (ChangeNotifier) + UI events
  ui/
    menu_screen.dart, setup_screen.dart, board_screen.dart,
    game_over_screen.dart, widgets.dart, animated_background.dart
  util/sound.dart
assets/words.txt       dictionary (generated, see below)
assets/sounds/         synthesized WAVs
tooling/make_sounds.py regenerates the sounds
test/engine_test.dart  14 engine tests
```

## Regenerating the dictionary

`assets/words.txt` was filtered from the public-domain `words_alpha` list
(2–15 letters, A–Z, deduped, sorted). To rebuild: download the list and run
the same filter; any A–Z word list works as a drop-in replacement.

## Not included (M3, parked)

Ads / remove-ads, online multiplayer, daily challenges — say the word and
they become the next milestone.
