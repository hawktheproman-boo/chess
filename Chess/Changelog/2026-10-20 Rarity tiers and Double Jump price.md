---
tags: [changelog, shop, abilities, pricing]
---
# Rarity tiers and the Double Jump price (2026-10-20)

**The user's brief:**
- Players say Double Jump is too strong, so it should cost more. The user set the gamepass to
  **150 Robux** in the Creator Dashboard (the agent had suggested 150, or 125 as the second choice).
- "Make rarity levels" like the user's sketch: Common (blue), Uncommon (green), Epic (lavender).

## Double Jump: 150 Robux / 1,500 coins
- `Shared/Shop.lua`: `KnightJump.robux` went from 25 to **150**, so the coin price follows at
  1,500 (10 coins per Robux, 30 wins). The gamepass itself was changed by the user.
- People who already own it keep it.

## Rarity tiers
**`Shop.RARITIES`** (`Shared/Shop.lua`), with `Shop.rarity(id)` to look one up. Tiers follow price.
The agent proposed them, and **the user confirmed them as they are** (2026-10-20):

| Tier | Colour | Abilities |
|---|---|---|
| **Common** | sky blue `rgb(56,172,236)` | Any Passant (free), Royal Escape (50) |
| **Uncommon** | green `rgb(70,200,90)` | Battering Ram (100) |
| **Epic** | lavender `rgb(196,168,255)` | Double Jump (150), Snipe (150) |

**Where it shows:**
- **Shop cards:** a dark pill in the tier's colour, outlined in that colour, at the card's top
  left. The ability name and "TAP FOR INFO" moved down a little to make room. (The first try put
  it top right, over the piece, but it covered long names like "Battering Ram".)
- **Detail view:** the kicker reads "EPIC · KNIGHT · ONCE A GAME", with the tier in its colour
  (rich text).

Steal a Piece isn't in the Shop, so it has no tier.

**Checked in Studio:** the Shop grid and the Double Jump detail view, with no overlaps and no errors.
**Not checked yet:** on a phone.

Back to [[Home]]
