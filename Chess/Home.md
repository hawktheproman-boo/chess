---
tags: [index]
---
# Chess project vault

Handoff for agents and people working on the **chess game** (project folder
`C:\Users\liter\Documents\CLAUDE\chess`). Started 2026-10-17. Nothing is built yet: this vault is
the brief.

## Start here
1. [[Goal]]: what the game is, the two modes, the standing rules.
2. [[Open Questions]]: things to confirm with the user **before** building. Abilities come from
   the user directly.
3. [[Build Plan]]: the approved phase-by-phase plan (2026-10-17). [[Next Steps]]: the short build order.
4. [[Current State]]: what exists right now.
5. Design notes:
   - [[Design/Architecture]]: how the code should be split (rules engine, abilities, server, UI)
   - [[Design/Classic Mode]]: full chess rules checklist and how to prove the move generator right
   - [[Design/Abilities Mode]]: the ability system the user's abilities will plug into
   - [[Design/UI and Controls]]: board, input on PC / phone / controller, feedback
   - [[Design/UI Style]]: the simulator-style look, Play screen cards, and the Adobe art plan
   - [[Design/Cutscene Storyboards]]: the Phase 2 storyboards (VFX/SFX per ability, VfxKit, the bake plan)
   - [[Design/Cutscene Treatment]]: **how to build an ability cutscene** (the recipe behind the six rebuilt scenes)
   - [[Design/Store Art]]: the CHESS?? icon, thumbnails and gamepass icons (plan, specs, concepts)
   - [[Design/Domain Expansion]]: the queen's planned Domain Expansion (rules from the user; not built, not in the Shop)
   - [[Design/Tournament]]: tournaments (rules, the template place, how a tournament runs, testing)
6. [[Tooling and Studio Gotchas]]: the scripts in this folder and what bit us on Descent Depths.

## Rules for agents updating this vault
- New work: add `Changelog/YYYY-MM-DD Short title.md` (tag `changelog`) and link it at the top
  of the list below. Update [[Current State]] and [[Next Steps]] when they change.
- When the user gives the abilities, write each one into [[Design/Abilities Mode]] (the table
  there) before implementing it, and confirm any ambiguous rule with them.
- Plain Markdown, `[[wikilinks]]`, one subject per note.

## Changelog (newest first)
- [[Changelog/2026-10-20 Shop tier columns and store art plan|Shop split into Common / Uncommon / Epic columns; store art plan (CHESS?? icon, thumbnails, pass icons) (2026-10-20)]]
- [[Changelog/2026-10-20 Rarity tiers and Double Jump price|Rarity tiers (Common / Uncommon / Epic) in the Shop; Double Jump now 150 Robux / 1,500 coins (2026-10-20)]]
- [[Changelog/2026-10-20 Lobby feedback, panel QOL, music|Lobby feedback: two-sided boards, topiary, 2D notch fix, full-width button overlays, bot tick box + level, no hover sounds, classical music (2026-10-20)]]
- [[Changelog/2026-10-20 Lobby makeover|Lobby makeover: wider park, giant-king fountain, tournament stage + screen, leaderboard boards, lamps, flags, birds, ambience (2026-10-20)]]
- [[Changelog/2026-10-20 Swap removed, Domain Expansion planned|Swap removed; queen Domain Expansion rules recorded; the cutscene treatment written down (2026-10-20)]]
- [[Changelog/2026-10-18 Leaderboards|Leaderboards: Most wins + Champions (pushed and shown on the lobby boards 2026-10-20) (2026-10-18)]]
- [[Changelog/2026-10-19 Piece sets|Piece sets: Classic (Staunton) + Toon Blender meshes, set picker in Settings (2026-10-19)]]
- [[Changelog/2026-10-19 Snipe cutscene rebuild|Bishop Snipe cutscene in 4 scenes: Blender rifle, scope, recoil, bullet-cam with king ricochet, Creator Store SFX (2026-10-19)]]
- [[Changelog/2026-10-19 Snipe VFX|Snipe anime VFX: VfxKit (shockwaves, sparks, impact frames, speed lines, beams, cracks) + 8 textures (2026-10-19)]]
- [[Changelog/2026-10-19 Snipe pacing, impact frames, sound|Snipe: 10.5 s pacing, manga impact frames, cinematic sound layers (2026-10-19)]]
- [[Changelog/2026-10-19 Battering Ram cutscene|Battering Ram cutscene: bull wind-up, launch impact frames, afterimage charge, pieces launched, king flinch (2026-10-19)]]
- [[Changelog/2026-10-19 Double Jump cutscene|Double Jump cutscene: horse rear-up, high leaps with hang time, spinning second leap, landing impact frames (2026-10-19)]]
- [[Changelog/2026-10-19 Royal Escape cutscene|Royal Escape cutscene: check lines, a pillar of light, a gold sigil, the king slams down; plus the Double Jump camera fix (2026-10-19)]]
- [[Changelog/2026-10-19 Any Passant cutscene|Any Passant cutscene: a Blender katana, a flash step, four hanging cuts, the sheathe click that splits the target (2026-10-19)]]
- [[Changelog/2026-10-19 Steal a Piece cutscene|Steal a Piece cutscene: a red sigil, gold chains, the yank, the old colour shatters off, STOLEN! (2026-10-19)]]
- [[Changelog/2026-10-18 Tournaments|Tournaments: VIP-hosted knockout, global banner, own place, spectating, daily top games (2026-10-18)]]
- [[Changelog/2026-10-18 Shop detail view and ability demos|Shop: slim cards, tap for rules + an animated demo; phone fixes (2026-10-18)]]
- [[Changelog/2026-10-18 Gamepasses and Steal a Piece|Ability gamepasses, free Any Passant, 10 coins/Robux, Steal a Piece (dev product) (2026-10-18)]]
- [[Changelog/2026-10-18 Shop and coins|Shop (abilities bought with coins), +50 coins per 1v1 win, PvP-only stats (2026-10-18)]]
- [[Changelog/2026-10-18 Any Passant and ability panel|Any Passant (pawn) + bottom ability panel with cards (2026-10-18)]]
- [[Changelog/2026-10-18 Four piece abilities|Double Jump, Battering Ram, Swap, Royal Escape: every piece has an ability (2026-10-18)]]
- [[Changelog/2026-10-18 Phone layout and VIP offer|Phone layout, bigger 2D board, VIP offer with Robux price (2026-10-18)]]
- [[Changelog/2026-10-18 Drawn icons, VIP stats, ground lights|Drawn icons (no emoji), VIP stats + saved reviews, table ground lights (2026-10-18)]]
- [[Changelog/2026-10-18 Live freeze fix|Fix: runaway table panel froze the live game (2026-10-18)]]
- [[Changelog/2026-10-18 Lag, review UI and sounds|Server/review lag fix, decluttered review with skeleton loaders, review + button sounds (2026-10-18)]]
- [[Changelog/2026-10-17 Piece art and Abilities review|2D piece art (EditableImage), Abilities review findings, readable bot levels (2026-10-17)]]
- [[Changelog/2026-10-17 Table signs and Adobe art|Simulator-style table signs + Adobe icon set and textures (2026-10-17)]]
- [[Changelog/2026-10-17 Simulator style and Play screen|Simulator-style dark UI + Play screen cards (2026-10-17)]]
- [[Changelog/2026-10-17 Icons and less text|Icons beside text, less clutter, PGN Copy (2026-10-17)]]
- [[Changelog/2026-10-17 PGN and game review|PGN export + game review (2026-10-17)]]
- [[Changelog/2026-10-17 Sounds and themes|Sound effects, board themes, Settings panel (2026-10-17)]]
- [[Changelog/2026-10-17 Smooth moves and snipe camera|Instant moves, snipe camera fixed, new backlog (2026-10-17)]]
- [[Changelog/2026-10-17 Bishop Snipe|Phase 6 abilities + Bishop Snipe (2026-10-17)]]
- [[Changelog/2026-10-17 Lobby polish|Phase 5 lobby polish (2026-10-17)]]
- [[Changelog/2026-10-17 Bright restyle and 2D board|Bright park, 2D board, green/white HUD (2026-10-17)]]
- [[Changelog/2026-10-17 Board room input|Phase 4 room, board, input, HUD (2026-10-17)]]
- [[Changelog/2026-10-17 Bot|Phase 3 bot (2026-10-17)]]
- [[Changelog/2026-10-17 Server tables|Phase 2 server tables (2026-10-17)]]
- [[Changelog/2026-10-17 Rules engine|Phase 1 rules engine, perft passes (2026-10-17)]]
- [[Changelog/2026-10-17 Build plan|Build plan approved (2026-10-17)]]
- [[Changelog/2026-10-17 Project start|Project start (2026-10-17)]]
