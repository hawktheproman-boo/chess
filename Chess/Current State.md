---
tags: [core]
---
# Current state (2026-10-17)

- **Place:** the new experience under The Depths Studio, start place ID **93046632926618** (shows in
  Studio as "Chess??"). `push.py` targets whichever Studio is open.
- **Built: phase 1 of the [[Build Plan]], the Classic rules engine.** It passes every perft
  position and the rules tests. Files are in `src/ReplicatedStorage/Shared/`:
  - `Chess/Board`: the 0x88 board, pieces `{type, color, id, moved, data}`, and king tracking;
  - `Chess/Moves`: generation, attacks, make/unmake, the legality filter, perft/divide. Attack
    checks live here; there's no separate `Attacks` module;
  - `Chess/Notation`: FEN in/out, SAN, and SAN/UCI parsing;
  - `Chess/Game`: actions, apply (validates), undo, the result (mate, stalemate, threefold, 50-move,
    insufficient material, resign, agreement, timeout with bare-material draw), and the move list.
    It has the mode hooks ready for abilities;
  - `Modes/Classic`: no hooks;
  - `Tests/Perft`: the perft suite (CPW positions 1–6) plus 13 rules tests.
- **Built: phase 2, the server tables** (`src/ServerScriptService/Tables/`, `Shared/Settings`):
  - `TableService.server`: 6 tables (T1–T6), the remotes, a rate limit, the clock/disconnect
    tick, and `ServerStorage.ChessDebug` (Studio only);
  - `ChessTable`: seats, settings, ready/rematch (colours swap), the authoritative Game,
    action sanitising, clocks, resign/abort, draw offers, a 60 s disconnect grace, and seq'd
    broadcasts;
  - `Clock`: Fischer increment. No clock runs before White's first move;
  - `Results`: per-mode W/L/D in DataStore `ChessStats_v1`. Bot games go in a `<Mode>_bot` bucket.
- **Remote protocol:** see the header of `TableService.server.lua`, plus the payload list at the
  top of `ChessTable.lua`. Squares are 0x88 indices (e2 = 20, e4 = 52), not 0–63.
- **DataStore in Studio:** saving is blocked until the user turns on *Game Settings → Security →
  Enable Studio Access to API Services*. The code handles this and only warns.
- **Built: phase 3, the bot.** `Shared/Bot/Search` has 4 levels, Beginner to Strong. Bots seat at
  tables through the Lobby verbs `addBot`/`removeBot`. See [[Changelog/2026-10-17 Bot]].
- **Built: phase 4, the room, board, input and HUD.** `builders/build_room.lua` builds
  `workspace.Lobby`. The client is in `StarterPlayer/StarterPlayerScripts/Chess/` and seating in
  `Tables/Seating`. Playable with the mouse against a bot. See
  [[Changelog/2026-10-17 Board room input]].
- **Restyled 2026-10-17:** a bright outdoor chess park, green/cream boards, a green/white HUD and
  a **2D board mode** (V / RB / HUD button). See [[Changelog/2026-10-17 Bright restyle and 2D board]].
- **Built: phase 5, lobby polish.** `LobbyHud` (Play vs Bot / Play vs Player / Tables / Stats),
  quick play on the server, ready marks and a rematch prompt. See [[Changelog/2026-10-17 Lobby polish]].
- **Phase 6:** the abilities system and **Bishop Snipe** work (8/8 tests, server, bot, targeting
  UI, cutscene, all checked by clicks in a playtest). Moves are predicted on the client, so they
  show instantly. See [[Changelog/2026-10-17 Smooth moves and snipe camera]].
- **Sounds, 6 board themes and a Settings panel** (saved per player in DataStore `ChessPrefs_v1`): see [[Changelog/2026-10-17 Sounds and themes]]. DataStore works in Studio now.
- **PGN export + game review** (Review on the game-over card): see [[Changelog/2026-10-17 PGN and game review]]. Studio-only client test hook: `PlayerScripts.ChessClientDebug`.
- **Shop and coins (2026-10-18):** abilities are bought in the Shop with coins (`Shared/Shop`,
  `Tables/Wallet`, DataStore `ChessWallet_v1`); +50 coins per win against a person (10+ plies),
  nothing for bots; Abilities games only give each player the abilities they own (a bot copies
  its opponent's). Stats count PvP games only. See [[Changelog/2026-10-18 Shop and coins]].
- **Gamepasses + Steal a Piece (2026-10-18):** Any Passant is free; the other five cost coins (10 per
  Robux) or their gamepass (`Tables/Passes`). Steal a Piece is built (Classic + Abilities), paid per
  use with developer product 3719153067 from a Steal button in the game; receipts in
  `TableService`. See [[Changelog/2026-10-18 Gamepasses and Steal a Piece]].
- **Shop detail view (2026-10-18):** the cards show just the name, TAP FOR INFO and the prices; a tap
  opens the rules with a looping demo on a 5x5 board (`AbilityDemo.lua`). Checked in Studio's phone
  emulation. See [[Changelog/2026-10-18 Shop detail view and ability demos]].
- **Tournaments (2026-10-18):** VIP starts, anyone joins (8–16), 5-minute global banner, knockout
  (draw → rematch → Armageddon) in a place made from a template place, spectating with Watch, and
  the day's top games logged. Built and tested in Studio with bots; **live use waits on the user's
  template place** (`Settings.TOURNAMENT_TEMPLATE_ID`). The room has 8 tables now. See
  [[Design/Tournament]] and [[Changelog/2026-10-18 Tournaments]].
- **Piece sets (2026-10-19):** Classic (default) and Toon Blender meshes plus the old Simple set, picked in
  Settings ([[Changelog/2026-10-19 Piece sets]]). Meshes in `ReplicatedStorage.PieceSets` (builders/piece_sets.lua).
- **2026-10-19:** the Bishop Snipe cutscene is rebuilt as 4 scenes (load, scope, fire, hit) with a Blender rifle and Creator Store SFX; its clock hold is now 10.5 s (slowed, with manga impact frames and cinematic sound: [[Changelog/2026-10-19 Snipe pacing, impact frames, sound]]). See [[Changelog/2026-10-19 Snipe cutscene rebuild]]. Anime VFX added through the new `VfxKit` ([[Changelog/2026-10-19 Snipe VFX]]). The Battering Ram got the same treatment ([[Changelog/2026-10-19 Battering Ram cutscene]], 8.0 s). So did the Double Jump ([[Changelog/2026-10-19 Double Jump cutscene]], 8.5 s). So did Royal Escape ([[Changelog/2026-10-19 Royal Escape cutscene]], 7.5 s). So did Any Passant ([[Changelog/2026-10-19 Any Passant cutscene]], 7.5 s, with a Blender katana prop). So did Steal a Piece ([[Changelog/2026-10-19 Steal a Piece cutscene]], 8.0 s). **2026-10-20:** the lobby makeover is built in Chess?? ([[Changelog/2026-10-20 Lobby makeover]]): a 190×150 park, a fountain with a giant Classic king between the table rows, a tournament stage with a live screen, Most wins / Champions boards by the spawn (the leaderboard code is now pushed), lamps, flags, birds and ambience. Not yet in the Tournament place. Then the user's feedback round ([[Changelog/2026-10-20 Lobby feedback, panel QOL, music]]): two-sided boards, topiary instead of candy flowers, the 2D phone-notch tap fix, full-width button shine/stripes, a "Play vs bot" tick box with a separate bot-level button, no hover sounds, and a classical music playlist with a Settings tick box. Swap was removed (the user scrapped it); the queen has no ability until the planned [[Design/Domain Expansion]] is built, after the lobby. The cutscene recipe is in [[Design/Cutscene Treatment]] ([[Changelog/2026-10-20 Swap removed, Domain Expansion planned]]).
- **Next (2026-10-18 plan):** Phase 1 piece sets (Blender meshes, Classic + Toon), Phase 2 Blender-baked cutscenes, Phase 3 leaderboards (Most wins, Champions), Phase 4 lobby makeover (centrepiece, tournament stage, leaderboard wall, ambience).
- **Not built yet:** more abilities (ask the user), sounds and animations polish (phase 7). Controller and touch are written but
  not device-tested.
- **To run the tests:** engine tests in Edit mode. Table tests run in a playtest through
  `ServerStorage.ChessDebug` (Server datamodel); the driver used is in the changelog.
  See see [[Tooling and Studio Gotchas]] for the require-cache trap.

Back to [[Home]]
