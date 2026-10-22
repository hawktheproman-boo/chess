---
tags: [changelog, abilities]
---
# Four new piece abilities (2026-10-18)

The user asked for an ability for every piece and had no ideas of their own. The agent suggested
three per piece, the user picked one each and then set the rules (see the table in
[[Design/Abilities Mode]]):

| Piece | Ability | Rules |
|---|---|---|
| Knight | **Double Jump** | two knight moves in a row; can capture on either landing; may land back on its start square |
| Rook | **Battering Ram** | charges down a line removing every enemy piece; stops at your own piece, the edge, or **in front of the enemy king**; ends on the last square |
| Queen | **Swap** | trades squares with any of your own pieces **except the king** |
| King | **Royal Escape** | teleports up to 2 squares, **may capture**, never lands in check |

Every ability is **once per game per player** and uses the turn, like Bishop Snipe.

## Rules the agent added (tell the user if they ask)
- **Royal Escape** only offers squares **exactly 2** away. A one-square escape is just a normal
  king move, so the charge would be wasted.
- **Swap** can't send a pawn to the first or last rank.
- **Double Jump** never lands on the enemy king. Landing back on the start square without
  capturing is allowed, so it works as a "pass".

## Engine (`Shared/Abilities`)
- `Util.lua`: shared charges, an undo record that saves the touched squares, castling rights
  through `Moves.KEEP`, the 50-move counter, and a legality check (the mover's king isn't attacked).
- `KnightJump.lua`, `RookRam.lua`, `QueenSwap.lua`, `KingEscape.lua`: each provides `actions`,
  `apply`, `describe` (move-list text) and `score`.
- **`Modes/Abilities`:**
  - all 5 abilities, one charge each, in `abilityState` (part of the position key);
  - `byPiece` maps each piece type to its ability, and `chargesLeft` totals what a player has left;
  - action matching compares `id / from / dir / mid / to`.
- **Bot:** the search only looks at ability actions that **capture**, plus Royal Escape while in
  check. Quiet double jumps and swaps are left to people; they would triple the branching. When
  nothing else is legal it sees every ability, so mate detection stays right.
  - Generating all ability actions takes ~0.3 ms per position.
- **Server:** `ChessTable.cleanAction` accepts `dir` (diagonal or straight), `mid` and `to`. The
  clock hold and the bot's wait use `Settings.cutscene(id)`:
  - Snipe 3.4 s;
  - Jump 2.8 s;
  - Ram 3.0 s;
  - Swap 2.6 s;
  - Escape 2.6 s.

## Client
- The HUD's **Snipe** button is now a purple **Ability** button, with a red badge counting the
  charges left.
- **Aiming:** press Ability, and every piece that can use its ability glows. Tap one to see its
  targets:
  - a snipe or ram line (enemy pieces it hits get rings);
  - the knight's first landings, then its second landings;
  - purple rings on the queen's swap partners;
  - the king's escape squares.
  Tapping a target opens "Use Battering Ram (takes 3 pieces)? Once per game."
- **Cutscenes** (`Cutscene.ability`): letterbox bars and a big coloured Fredoka title, a camera
  move, and the pieces animated:
  - **Double Jump:** two high leaps with a dust ring and a thud on each landing;
  - **Battering Ram:** the rook rocks back, then charges, with a burst, crash and shake on each
    smash;
  - **Swap:** both pieces glow purple, rise and cross over each other;
  - **Royal Escape:** a gold column, the king fades out, then fades in on the new square with a
    gold ring.
- New sounds:
  - jump and land (Roblox's built-in character sounds);
  - crash;
  - magic and teleport (pitched library dings).
- Roblox's player list stays hidden during a cutscene on compact screens.
- **Review:**
  - each ability's move is labelled (Ram ×3, Jump c3 xd5, Swap Bf1, Escape g3);
  - the line or landings are shown, and the pieces it took are worked out generically;
  - "It took N pieces (+points)" only appears when it captured;
  - each ability plays its own sound while stepping.
- **Play-screen tip:** "In Abilities, every piece has a power you can use once per game."

## Tested
- **AbilityTests:** 19/19. New cases:
  - captures on both landings, landing back home, no king or own-piece landings;
  - stopping in front of the king and at an own piece;
  - swap rules, including the pawn rank;
  - escaping a back-rank mate, escape captures, not escaping into check;
  - once per game, undo for each ability;
  - the bot using the Ram to win material.
- BotTests all pass.
- **Studio playtest** (test position `r3k3/8/p7/3p4/n7/8/5PPP/RN1QKB2 w`):
  - aimed and fired through the real UI: glow, line, two-step jump, confirm;
  - Ram, Double Jump, Swap and Escape all applied on the server;
  - the bot answered a check with its own Royal Escape;
  - Ram and Jump cutscenes checked in screenshots; Swap and Escape movement and fade checked by
    script;
  - the review of that game shows all the labels and saved to Stats;
  - no errors in the console.
- **Gotcha:** after the phone emulator was switched off, Studio's 3D view captured black until
  the playtest was restarted. The GUI was fine.

## Still open
- ✅ (done 2026-10-18, [[Changelog/2026-10-18 Any Passant and ability panel]]) **Forced Passant (pawn)** needed the user's answers (knights / king / check); it was built as Any Passant.
- ✅ (done 2026-10-18, [[Changelog/2026-10-18 Gamepasses and Steal a Piece]]) **Steal a Piece** (gamepass): built as a developer product.

Back to [[Home]]
