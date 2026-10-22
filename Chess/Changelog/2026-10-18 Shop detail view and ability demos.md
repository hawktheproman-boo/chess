---
tags: [changelog, shop, ui, mobile]
---
# Shop detail view and ability demos (2026-10-18)

Follow-up to [[Changelog/2026-10-18 Gamepasses and Steal a Piece]]. The user sent a phone
screenshot of the Shop: the cards were cramped and the descriptions unreadable. They asked to:
- remove the description from the cards;
- show it only when the player taps an ability, with a little demonstration of what it does.

## Cards (`ShopPanel.lua`)
- Each card shows the name, a **TAP FOR INFO** pill, the piece, and the coin + Robux buttons (or
  OWNED).
- The blurb, the piece kicker and "Need N more coins" are gone from the cards. The kicker and the
  "Need" line were too small or covered the piece on a phone.
- The whole card is a button that opens the detail view. The buy buttons on it still work on
  their own.
- **Names fit on one line:** they're measured with `TextService:GetTextBoundsAsync` (`fitLine`).
  `TextScaled` doesn't shrink unwrapped text to its width, and wrapped text clipped "Double Jump"
  to "Double" on a phone. A `UITextSizeConstraint` minimum is in screen pixels, so it also stopped
  the shrink.

## Detail view (tap a card)
It takes the grid's place, and **Back** replaces the tabs along the bottom. Closing the Shop or
switching tabs also leaves it.
- **Left:** a looping demo on a 5x5 board, with a caption under it.
- **Right:**
  - the name, and "PIECE · ONCE A GAME";
  - the rules (`Shop.ABILITIES[].info`, which replaced `blurb`; auto-sized up to 24);
  - "Need N more coins";
  - the coin and Robux buttons, or OWNED / FREE · OWNED.
- The card's colour becomes the panel's gradient.
- Buying works from here too (two taps for coins), and the card behind updates. Live gamepass
  prices are cached in `passPrices`, so they're fetched once per pass.

## Ability demos (`AbilityDemo.lua`, new)
`AbilityDemo.new(parent, side, pos)`, `demo:play(id)` (loops), `demo:stop()`.
- **Steps:**
  - `put` / `setup` pieces;
  - `say` the caption;
  - `mark` squares: dot, hit, own, sel, check;
  - `tap` (a white ring closing in);
  - `move` (slide / hop; captures what's on the landing square);
  - `charge`, `capture` (pop and a burst), `beam`, `teleport`, `swap`, `shake`.
- Pieces only ever scale, never fade, so both PieceIcons kinds work (EditableImage or viewport).
- **The six scripts:**
  - **Any Passant:** a knight lands beside the pawn; the pawn hops behind it and takes it.
  - **Double Jump:** two jumps, a capture on each.
  - **Snipe:** a beam down the diagonal; two pieces pop and the king shakes (skipped).
  - **Battering Ram:** the rook charges, smashing two pieces, and stops before its own pawn.
  - **Swap:** the queen and a rook trade squares.
  - **Royal Escape:** the king is in check, teleports two squares and takes a pawn.
- Steal a Piece has no demo; it isn't in the Shop.

## UiKit fix (all phones)
- **Bug:** `placeIcon` read `TextBounds`, which is in screen pixels after UIScales, and used it as
  an unscaled offset. On a scaled-down screen the icon sat on the text: "✓REE · OWNED" in the
  user's screenshot.
- **Fix:** it now divides by the UIScales above the label (`scaleOf`). This fixes every centred
  icon label on phones, not only the Shop.

## Tested (Studio, phone emulation 750x381, sandbox wallet, passes hidden)
- **Cards:** the names fit, FREE · OWNED reads right, and TAP FOR INFO is readable.
- **Detail view:** Double Jump, Any Passant and Swap opened; all six demos ran side by side and
  played correctly.
  - The first Double Jump demo popped the knight instead of the pawn. Fixed: `move` now captures
    whatever is on the landing square.
- **Buying:** Swap bought from its detail view (600 → 350 coins, OWNED, toast). Back returned to the
  grid with Swap OWNED.
- No errors on the client or the server (only Roblox's UIBlox warnings).

Stills: `stills/2026-10-18s-shop-phone-cards.jpg`, `t-shop-phone-detail`, `u-shop-phone-bought`,
`v-ability-demos`.

Back to [[Home]]
