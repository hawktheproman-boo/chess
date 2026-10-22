---
tags: [changelog]
---
# 2D piece art, the Abilities review, readable bot levels (2026-10-17)

The user's feedback had three points:
- the bot-level names didn't read well (gold on green);
- the review called opening moves blunders;
- the 2D chess pieces hadn't changed.

## Bot level names
In the Play Bot card, the level names are now white Fredoka with an ink outline (they were gold
`T.greenDeep`).

## "Starting moves are blunders" (Abilities review)
The user's game was an **Abilities** game, and under the Bishop Snipe rules the grades are
**correct**:
- After 1.d4, the c1 bishop's long diagonal is open.
- After 1.d4 b6?? 2.Bg5, the snipe runs g5–f6–e7–d8 and takes the e7 pawn **and the queen**.
- The queen on d8 has no free square, and Black can't block, because a snipe passes through enemy
  pieces and only the shooter's own pieces stop it.
- So b6 loses the queen, and 2.Bd2 (instead of Bg5) misses winning it.

That makes the Abilities opening extremely sharp. Whether that's wanted is a **rules question for
the user** (abilities come from the user); see Open questions below.

Found and fixed while checking:
- **Quiescence ignored snipes.** The end-of-search capture pass only looked at normal captures,
  so a snipe just past the search depth was invisible, and the evals swung by several pawns from
  ply to ply.
  - `Search.lua` `quiesce` now also tries ability actions that remove material.
  - After 1.d4 b6 2.Bd2 the eval went from −4.6 to +0.25.
  - BotTests and AbilityTests pass (run on the play server against the new source).
- **`sameAction` in Search ignored a snipe's direction**, so two snipes from one bishop looked
  alike in move ordering. It now compares `dir` too.

## 2D piece art (Illustrator)
- `art/ui/make_pieces.py`: 12 pieces in the house style (ink outline, gradient, shine).
  - White pieces are cream, black are charcoal with grey detail lines.
  - All six types share one base line; the knight faces left.
  - Exported through Illustrator with the icons: `ai/` masters plus `png/chess_piece_<w|b><K..P>.png`.
- Preview: `art/ui/pieces_preview.png`, on the board colours.

## Getting them into the game without uploads
- Roblox fonts have no chess glyphs (tested: ♔–♙ show as empty boxes), so text pieces are out.
- **EditableImage:**
  - `art/ui/make_piece_data.py` packs the PNGs (128 px, run-length encoded, base64, about
    235 KB) into the generated `src/.../Chess/PieceArt.lua`.
  - `PieceIcons.new` decodes a piece into an `EditableImage` and returns an `ImageLabel`
    (`ImageContent = Content.fromObject(img)`).
  - That covers the 2D board, the review board and the promotion picker.
  - If EditableImage isn't allowed, it warns once and falls back to the old 3D-render icons.
- **Published games:** EditableImage only works when the experience owner is 13+ and
  **ID-verified**, and **File → Game Settings → Security → Allow Mesh & Image APIs** is on.
  Otherwise players see the fallback. Studio is fine.
- **Tested** in a Studio playtest after Studio reconnected:
  - all 32 board pieces came up as `ImageLabel`s (EditableImage worked, no fallback);
  - moves animate and the last-move highlight works;
  - the console showed no errors.
  - Still: `stills/2026-10-17j-2d-piece-art.jpg`.
- **Script size limit:** Roblox caps a script's Source at 200,000 characters, and the first
  `PieceArt.lua` (235,752) failed to push. So the data is split per colour: `PieceArtW` / `PieceArtB`
  (about 118 KB each), and `PieceArt.lua` is a small index that joins them.

## Decisions and open questions
- The user decided to **keep the snipe rules as they are** (the early queen trap is accepted).
- Open: can the game's owner (The Depths Studio group) meet the EditableImage requirements? If not, the
  2D art needs the normal image upload.

Back to [[Home]]
