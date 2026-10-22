---
tags: [design]
---
# UI and controls

## Input (all three are required)
- **Mouse:** click a piece and click a square, or drag and drop. Right-click cancels.
- **Touch:** tap a piece, then tap a square. Make the hit areas a full square. No hover-only
  information.
- **Controller:** a cursor on the board moved with the stick or d-pad. A picks up and drops, B
  cancels, and a shoulder button opens the ability bar. Show button glyphs for the device in use;
  Descent Depths' `ReplicatedFirst/Input.lua` swaps glyphs per device and can be adapted.

## Board feedback
- Legal-move dots, with rings on capturable pieces.
- The last move highlighted; the king's square tinted when in check.
- Promotion picker; draw-offer and resign confirmation built into the UI. Roblox has no native
  confirm dialog.
- Move list (SAN), both clocks, captured pieces, the mode name and ability state.

## Building the board
- **No z-fighting:** squares are separate parts that don't overlap. Don't lay coplanar decals or
  highlights over them; raise highlights slightly or use SurfaceGuis/Highlights.
- Keep pieces anchored and move them by CFrame/tweens from the replicated state. Physics should
  never decide a position.

Back to [[Home]]
