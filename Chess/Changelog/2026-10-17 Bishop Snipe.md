---
tags: [changelog]
---
# Phase 6: abilities system + Bishop Snipe (2026-10-17)

The user's first ability is Bishop Snipe. Its rules were confirmed with the user and are in the
table in [[Design/Abilities Mode]]:
- any bishop; it uses the turn; once per game per player;
- one direction, to the board edge;
- it hits enemies only, your own piece blocks it, and the king is skipped.

## Built
- **Engine:**
  - `Shared/Abilities/BishopSnipe` has `hits`, `path`, `apply` (with an undo record), the legal
    `actions`, `describe` ("Bc1 snipe NE x3", + / # added) and `score`;
  - `Shared/Modes/Abilities` has setup (`game.abilityState`), `abilityActions`,
    `applyAbility(game, action, trusted)` and `stateKey`;
  - `Settings.MODES` now includes "Abilities", and there's `Settings.SNIPE_CUTSCENE` (3.4 s);
  - `Game.new` runs the mode's setup before the first position key. `Game:push` passes
    trusted = true. `Moves.KEEP` is exported.
- **Bot:** ability actions are ordered by the value they capture. The bot takes a big snipe (a
  test covers it).
- **Server:**
  - `cleanAction` accepts `{kind="ability", id, from, dir}`;
  - `Clock:hold` pauses the opponent's clock for the cutscene, and the snapshot includes
    `since`;
  - the bot waits out the cutscene;
  - quick play takes an `opts.mode`.
- **Client:**
  - the HUD has a red **Bishop Snipe (1)** / "Snipe used" / "Cancel snipe" button (F or X key);
  - targeting tints the bishops that can fire, with dots along each line and red on the hits.
    Click a bishop to narrow the choice, click a line square to fire, then confirm;
  - the table panel has a **Mode** button, and the Play vs Bot card has a mode choice;
  - `Cutscene.lua`: letterbox, a scope ring, the title, a camera push-in, the bishop turning,
    then a tracer, muzzle flash, hit flash, piece pop and shot sound per target. The sound is the
    built-in `impact_explosion_03`, pitched up;
  - `CameraRig.override` / `shake`. 2D mode hides itself during the cutscene.

## Verified
- **`Tests/AbilityTests`: 8/8 pass.** Hits, king skip and own-piece block; once per player;
  undo of board, charges and castling rights; legality in and out of check; no false stalemate;
  start-position perft unchanged; the bot snipes; client replay matches. The classic rules, bot
  tests and Kiwipete perft still pass.
- **In a playtest:**
  - the Snipe button and targeting marks show correctly;
  - the server applied the snipe ("Bc1 snipe NE x3");
  - the cutscene overlay played.

## Left to do (next session)
*Update: the camera, click-to-fire and the full cutscene were fixed and checked in [[Changelog/2026-10-17 Smooth moves and snipe camera]].*
- ✅ (done 2026-10-17, [[Changelog/2026-10-17 Smooth moves and snipe camera]]) **Cutscene camera: it's too close.** It ends right behind the bishop's head, which fills the
  scope. In `Cutscene.snipe`, move `endCf` higher and off to one side, e.g. raise it about 3.5
  and shift it sideways about 1.5, looking at the line's centre.
- ✅ (done 2026-10-17, [[Changelog/2026-10-17 Smooth moves and snipe camera]]) Confirm the whole cutscene by eye: the tracers, the pops, and the camera returning afterwards.
- ✅ (click-to-fire done 2026-10-17, [[Changelog/2026-10-17 Smooth moves and snipe camera]]; the cutscene in 2D mode is still not checked) Click-to-fire through the UI confirm (only the server-side fire was tested), and the cutscene
  in 2D mode.
- The bot as the sniper, in a real game. (Still not checked, per [[Changelog/2026-10-17 Smooth moves and snipe camera]].)
- ✅ (done 2026-10-18, [[Changelog/2026-10-18 Four piece abilities]]) Then ask the user for more abilities.

Back to [[Home]]
