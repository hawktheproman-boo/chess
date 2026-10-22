---
tags: [changelog, shop, store, art]
---
# Shop tier columns and the store art plan (2026-10-20)

**The user's brief:** "Make the shop have dividers tiering the common uncommon and epic seperately.
Then, we need to work on gamepass icons, and plan the icon of the game + thumbnails."

## Shop: one column per rarity
- The Abilities tab is now **three columns: Common | Uncommon | Epic**.
  - Each has its name in the tier colour, with a coloured rule under it.
  - Thin divider lines separate the columns.
  - Cards stack under their tier (Any Passant and Royal Escape; Battering Ram; Double Jump and Snipe).
- **Overflow:** a column with more than two cards scrolls on its own, so a new Epic fits.
  - An empty tier says "Coming soon".
- **Cards:**
  - they're 125 px tall now;
  - the per-card rarity tag is gone, since the column header says it;
  - the piece is a little smaller and higher.
  - The coin and Robux buttons still fit: checked by showing them on the Double Jump card, which
    read 1,500 coins and 135 Robux (Studio shows a regional price for the 150 pass).
- **Checked in Studio:** no overlaps, no errors.
  - The `passes` override (to hide owned passes) was put back afterwards.
- **Not checked yet:** on a phone.

## Store art
**The user's choices:**
- the name **CHESS??** ("??" is the blunder mark);
- the icon: the **bishop with a sniper**;
- **in-game 3D renders**;
- icons for all **4 ability passes, VIP and Steal a Piece**.

The full plan is [[Design/Store Art]]: the specs, a concept for each image, and the order of work
(icon first).

**Made the same day** (all scripted in `art/store/`, rendered in Blender, finished with Python/PIL in the
game's Fredoka One font; nothing uploaded by the agent):
- the experience icon: approved after draft 2;
- the hero thumbnail: approved;
- the 6 pass and product icons: draft 2, after the user's notes;
- thumbnails 2–5: draft 1.

The details and the upload targets are in [[Design/Store Art]].

Back to [[Home]]
