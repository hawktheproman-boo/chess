---
tags: [design, abilities, queen, planned]
---
# Domain Expansion (queen): planned, not built

**The user (2026-10-20):** "scrap the swap ability, I want to make a queen domain expansion
ability, but make it not available yet in the shop." It replaces **Swap**, which is retired (see
[[Changelog/2026-10-20 Swap removed, Domain Expansion planned]]).

**Status:** the rules below are the user's answers. **Don't build it yet.** The user wants the lobby
done first. When it is built, it must **not appear in the Shop** until the user says so.

## Rules (user's answers, 2026-10-20)
| | |
|---|---|
| **Who has it** | The player's queen |
| **Effect** | **Queen's realm:** while the domain is up, the queen may **teleport to any square on the board**, capturing the enemy piece there |
| **Area** | **The whole board** |
| **Casting** | **Casting uses the turn.** Cast it, the opponent replies, and then the realm turns start |
| **Duration** | **Your next 2 moves** after casting. On each, the queen *may* teleport, or you can move something else instead |
| **King** | **Never the king.** She can't land on the enemy king, but landing can give check or checkmate |
| **Counterplay** | **Normal rules:** the enemy can capture the queen as usual, which ends the domain |
| **Uses** | Once per game per player, like the other abilities |
| **Shop** | **Not sold yet.** It stays out of `Shop.ABILITIES` and the ability bar until the user says to release it |

## Open: proposed by the agent, confirm with the user when building
1. **Do the 2 realm moves count down even if you move another piece?** Proposed: **yes**. The
   domain lasts your next two turns, whatever you play on them.
2. **Landing squares:** any **empty** square or **enemy** piece, never your own piece. Is that
   right?
3. **Legality:** a realm jump may never leave your own king in check (like every ability). It
   counts as a capture for the 50-move rule when it takes something.
4. **Two queens** (after promotion): the domain belongs to the queen that cast it. A promoted queen
   can't cast a second one, because it's still once per game.
5. **Can the enemy cast their own domain while yours is up?** Proposed: yes; the two run side by
   side.
6. **The position key** (repetition) includes the domain's state and turns left.
7. **The bot:** in quiet positions it considers realm jumps that capture or give check. All 63
   squares would blow up its search.
8. **Price** (coins and a Robux pass) once it's released: the user decides.
9. **How testers get it before release:** proposed, only through the ChessDebug loadout in Studio
   (as the `wallet` sandbox does for Steal), and never in live games.
10. **The ability bar card:** proposed, the queen card comes back, labelled "Domain", only for
    players who own it.

## Cutscenes (draft, follow [[Design/Cutscene Treatment]])
**Colour:** purple and black (the old Swap card accent `rgb(170, 100, 255)`), with white-hot
highlights.

**The cast (about 9 s):**
1. **Wind-up:** a low shot on the queen as the board darkens. She raises one hand (or her crown
   glows), and a `braam` plays with a riser timed to the expansion.
2. **The expansion:** impact frames, and a black-purple dome sweeps out from her to cover the
   whole board. A big "DOMAIN EXPANSION" title.
3. **The payoff:** the board turns into her realm: a starfield under the squares, purple light
   pillars on the board's edges, a choir. A wide top-down shot.
4. **Settle:** two purple pips over the queen show the 2 realm moves.

**Each realm jump (short, about 2.5 s):** she blinks out in a purple flash, appears on the target
square above the enemy piece, and slams down. The piece shatters, with impact frames.

**While it's up:** a lasting purple tint on the board and the pips over the queen, so both players
can see it's active.

**Collapse:** the dome cracks and falls away when the domain ends or the queen is captured.

Back to [[Home]] · [[Design/Abilities Mode]]
