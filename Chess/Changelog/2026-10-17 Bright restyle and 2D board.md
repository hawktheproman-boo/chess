---
tags: [changelog]
---
# Bright restyle and the 2D board (2026-10-17)

The user's feedback on the phase 4 look:
- the room was too dark; they want the mood of today's popular Roblox games;
- the pieces were hard to see;
- they want a 2D board option like a classic online board (green and cream);
- the GUI should be **green and white**, "kinda cartoony but not too far" (not a brainrot look).

## Changes
- **`builders/build_room.lua` is now an outdoor chess park.**
  - The ground: a warm stone plaza (Slate) on a grass lawn with a small curb. Hedges surround
    it, with an entrance on the +Z side, plus 13 round trees and 4 flower planters.
  - Lighting: early afternoon, soft shadows, light atmosphere, gentle sun rays. The indoor
    lamps and walls are gone.
  - Tables: a light wood top, **green and cream squares** (238,238,210 / 118,150,86), a deep
    green frame, and white chairs with green seats.
  - The layout contract is unchanged (Tables/T1–T6, Board/<0x88>, White/BlackSeat +
    SitPrompt). The z-fighting check finds 0 overlaps in 526 block parts.
- **`Pieces`:**
  - bright white (250,250,247) and soft charcoal (74,72,70), with subtle trim instead of brass;
  - 8% bigger.
  - Highlights now use the classic yellow (246,246,105). The selection is yellow, the controller
    cursor white.
- **`CameraRig`:** with the ceiling gone, the cap is 26 studs before the view widens.
- **New `PieceIcons`:** flat piece pictures with no uploads.
  - Each is a ViewportFrame looking at the 3D piece from the side through a 9° lens (nearly
    orthographic), with flat light. A dark copy behind it, scaled to make up for the distance,
    gives the outline.
  - Roblox can't render the Unicode chess glyphs (they show as boxes, and the pawn becomes an
    emoji), so glyphs were tested and dropped.
- **New `Board2D`:** a GUI board over a soft green backdrop, with the same API as `BoardView`
  (`sync`, `setMarks`, `dragTo`, `squareAt`).
  - The look: coordinates in the corners, yellow last-move and selection tints, dark dots for
    moves, rings for captures, a red glow on a king in check, and a white cursor for controllers.
  - It's oriented to your colour and sized to stay clear of the HUD.
  - Input comes from one invisible button: click-click, drag and tap. Controller uses the same
    cursor as 3D.
  - Toggle with the HUD button "2D board" / "3D board", **V** on the keyboard, or **RB**.
- **`Hud` rewritten in the new style:**
  - white cards with a soft drop shadow;
  - green "primary" buttons and white "secondary" buttons with a chunky 4 px darker bottom edge
    that presses down; Builder Sans (Bold / ExtraBold);
  - player cards with the **Roblox headshot** (bots get a green BOT badge), material +N, and a
    clock box that turns green on your turn and red under 20 s;
  - a green-headed move list with zebra rows;
  - the table panel auto-sizes, which fixes the earlier empty space;
  - the result card ("You win!" green / "You lost" red / "Draw");
  - the promotion picker now shows piece pictures;
  - a green pill toast and a white hint pill.

## Verified in a playtest
- The park look, in Edit-mode stills: bright, clear, and the pieces read well on both square
  colours.
- The new HUD renders. The panel buttons "Play the bot" and "Ready" and the 2D toggle work with
  real mouse clicks.
- **2D board input:** clicking d2 then d4 played d4, and a drag from g1 to f3 played Nf3. The bot
  replied to both. Selection, dots, last-move tint, coordinates and clocks all show.
- **Bug fixed:** `GuiButton.MouseButton1Down` x/y include the 58 px top-bar inset, but
  `AbsolutePosition` doesn't, so Board2D subtracts the inset.

## Verified with Studio focused (follow-up)
- **2D piece icons render.** The first outline (one scaled copy) barely showed, so it's now
  four dark copies nudged up/down/left/right behind the piece. That gives an even rim, like the
  reference.
- **Piece shapes:** the king's cross bar was turned so it faces the side view. The queen now has
  a big spiky coronet; it used to read as a rook.
- **The 2D board** fits between the player cards. The sizing now subtracts Roblox's 58 px top
  bar, since the HUD lives below it.
- **The seated 3D view:** the tilted view is now the **default**. Top-down made white pieces wash
  out on cream squares, because you only see their round tops. The camera gets more vertical
  margin (needV 1.48) so the cards never cover the back rank.
- The check glow shows in both 3D (red slab) and 2D (red radial).
- Stills: `chess/stills/2026-10-17c-*.jpg` (3D tilted, 2D board, piece set).

## Still open
- Controller and touch haven't been tested on real devices.
- The 3D knight model is the weakest shape. Replace the pieces with group-owned meshes later.

Back to [[Home]]
