---
tags: [design]
---
# Abilities mode

**The abilities come from the user.** This note describes the system they plug into, and holds a
table to fill in as the user describes each one. Don't implement an ability until its row is
complete and confirmed ([[Open Questions]] #3–5).

## The ability table (fill in from the user)

**Ownership (user, 2026-10-18):** everyone owns Any Passant; the others are bought in the **Shop**
with coins or their Robux gamepass and kept forever. Steal a Piece is a developer product, paid per
use from its in-game button ([[Changelog/2026-10-18 Gamepasses and Steal a Piece]]).
In an Abilities game a player only has the abilities they own; a bot gets its opponent's set.
Prices and the coin rules live in `Shared/Shop.lua` ([[Changelog/2026-10-18 Shop and coins]]).
**Prices and rarity (2026-10-20):**
- Any Passant: free, Common.
- Royal Escape: 50 Robux, Common.
- Battering Ram: 100 Robux, Uncommon.
- Double Jump: **150** Robux, Epic (it was 25, raised because players found it too strong).
- Snipe: 150 Robux, Epic.

Each Robux price is ×10 in coins. See [[Changelog/2026-10-20 Rarity tiers and Double Jump price]].

**Built:** Bishop Snipe, Double Jump, Battering Ram, Royal Escape (Swap was built, then **removed on 2026-10-20**; the queen's next ability is the planned [[Design/Domain Expansion]]) (see
[[Changelog/2026-10-18 Four piece abilities]]). Steal a Piece is built too (2026-10-18). Any Passant: see
[[Changelog/2026-10-18 Any Passant and ability panel]].
| Ability | Who has it | Use (instead of move / extra / passive) | Cost (cooldown / charges / once) | Targets | Effect | Can it give / escape check? | Visual + sound |
|---|---|---|---|---|---|---|---|
| **Bishop Snipe** (user, 2026-10-17) | Any of the player's bishops | Instead of a move (it uses the turn); the bishop stays where it is | **Once per game per player**, whichever bishop uses it | One of the bishop's 4 diagonal directions, from the bishop to the board edge | Removes every **enemy** piece on that line. **Your own piece blocks it**: the shot stops there. **The enemy king is skipped**: the shot passes over it and is never hit | Yes. It can give check (by opening lines) and can get out of check (by removing the checker). It may never leave your own king in check | A sniping cutscene: the camera goes behind the bishop, a scope view, then a tracer and a hit flash on each target in turn |

| **Any Passant** (was "En Passant Anything"; rules changed by the user, 2026-10-18) | A pawn on its **5th rank** (White rank 5, Black rank 4) | Instead of a move | **Once per game per player** | Any enemy piece that **just landed** on the square beside the pawn (left or right) | Captured en passant style: the pawn moves diagonally forward to the square behind that piece and removes it. *Agent rules:* only right after the piece lands (like en passant), never the king, the square the pawn moves to must be empty; a plain pawn double step beside it still uses normal en passant | Yes, it can give check or escape it; it may never leave your own king in check | A short hop and a pop |
| **Steal a Piece** (Robux **developer product** 3719153067, user, 2026-10-18; built) | Whoever paid (one purchase = one use), in **Classic and Abilities** (never in Tournament) | Instead of a move (uses the turn) | **Once per game** | Any enemy piece **except the king and the queen** | The piece becomes your colour, on the same square | *Agent:* yes, it can give check and mate, and stealing the checker escapes check; it may never leave your own king in check | "STEAL!" cutscene: gold beam, the piece lifts and spins |
| **Double Jump** (picked by the user from agent ideas, 2026-10-18) | Any of the player's knights | Instead of a move | **Once per game per player** | Two knight moves in a row by the same knight | It can capture on either landing; a capture on the first leg doesn't end the jump. It **may** land back on its starting square (user, 2026-10-18) | *Proposed:* yes to both, judged only after the second landing; it may never leave your own king in check | *Built:* two high leaps, a dust ring and a thud on each landing ([[Changelog/2026-10-18 Four piece abilities]]) |
| **Battering Ram** (picked by the user, 2026-10-18) | Any of the player's rooks | Instead of a move | **Once per game per player** | One of the rook's 4 straight directions | Charges along the line, removing every **enemy** piece until it reaches your own piece or the edge, and **ends on the last square** before it. It **stops in front of the enemy king** (user, 2026-10-18). A direction is only offered if it hits at least one piece | *Proposed:* yes to both; it may never leave your own king in check | *Built:* the rook rocks back and charges, with a burst, crash and shake on each smash ([[Changelog/2026-10-18 Four piece abilities]]) |
| ~~**Swap**~~ (picked by the user, 2026-10-18; **removed by the user 2026-10-20**, kept only so old saved games replay) | The player's queen | Instead of a move | **Once per game per player** | Any one of your own pieces, anywhere, **except the king** (user, 2026-10-18) | The queen and that piece trade squares | *Proposed:* yes to both; it may never leave your own king in check | *Built:* both pieces glow purple, rise and cross over each other ([[Changelog/2026-10-18 Four piece abilities]]) |
| **Domain Expansion** (user, 2026-10-20; **planned, not built, not in the Shop**) | The player's queen | Cast instead of a move | **Once per game per player** | Whole board | For your next 2 moves the queen may teleport to any square, capturing the enemy piece there (never the king). Capturing the queen ends it. Full rules and open questions: [[Design/Domain Expansion]] | Landing can give check or mate; it may never leave your own king in check (agent) | Planned: a black-purple dome, the board becomes her realm ([[Design/Domain Expansion]]) |
| **Royal Escape** (picked by the user, 2026-10-18) | The player's king | Instead of a move | **Once per game per player** | Any square up to 2 squares away (king distance), empty **or holding an enemy piece**, where the king isn't in check after landing (user, 2026-10-18) | The king teleports there, capturing anything on that square | Yes, it can get out of check (its main use). It removes castling rights, like any king move | *Built:* a gold column, the king fades out, then fades in on the new square with a gold ring ([[Changelog/2026-10-18 Four piece abilities]]) |

**Snipe details decided by the agent** (change them if the user disagrees):
- a direction is only offered if it hits at least one piece, so the charge can't be wasted;
- it counts as a capture, so the 50-move counter resets and castling rights go if a corner rook
  is hit;
- the opponent's clock is paused for the length of the cutscene.

## How abilities hook into the engine
Each ability is one module in `Shared/Abilities/<Name>` returning a definition:

```lua
return {
	id = "Example",
	owner = "piece", -- "piece" (by type or specific piece) or "player"
	pieces = { "knight" }, -- which piece types get it (owner = "piece")
	use = "action", -- "action" (takes the turn), "free" (plus a normal move), "passive"
	cost = { cooldown = 3 }, -- or { charges = 1 }
	-- for "action"/"free": the legal targets for this piece in this position
	targets = function(game, piece) return { --[[squares]] } end,
	-- apply it to the game state (must be undoable: record what changed)
	apply = function(game, piece, targets) end,
	-- optional hooks for passives and lasting effects:
	-- modifyMoves(game, piece, moves), onTurnStart(game, color), onCapture(game, attacker, victim)
}
```

- **Mode hooks:** `Modes/Abilities` gives pieces their abilities at setup and calls the hooks:
  - `modifyMoves` while generating moves;
  - `onTurnStart` and cooldown ticks at each turn change;
  - `onCapture` and `onMove` after an action is applied.
- **Legality stays central:** any action, ability or move, is checked with the same rule. Apply it
  on a copy (or apply then undo), and reject it if the actor's king is in check afterwards (unless
  the user rules otherwise).
- **State lives on the board:** per-piece `data` and per-player ability state are part of the game
  state. Serialise them alongside the FEN, so saves, replays, undo and networking all keep working.
- **Checkmate and stalemate must count abilities:** a side with no legal moves but a legal ability
  action isn't mated or stalemated.
- **Bots:** generate ability actions alongside moves. Even a 1-ply bot that understands abilities
  is useful for testing.

## UI
- An ability bar for the selected piece, or for the player, with cooldown and charge counters.
- Targeting mode highlights the legal targets; confirm or cancel with mouse, touch or controller.
- Every ability gets a distinct visual and sound, and an entry in the move list ("N♞ Ability d5").

Back to [[Home]]
