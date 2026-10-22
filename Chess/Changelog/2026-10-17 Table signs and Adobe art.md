---
tags: [changelog]
---
# Table signs and the Adobe art (2026-10-17)

## 3D table signs
The floating signs over each table now use the simulator style:
- a dark green pill with an ink outline and chunky Fredoka text;
- a tilted "♟️ TABLE 1" tab on top. The mode icon shows in the tab (✨ for Abilities).

States:
- "Free table";
- "👤 Alex · Join!", with the tab turning **gold** when someone is waiting for an opponent;
- "⚔️ A vs B" for a game in progress;
- "A vs B" when both seats are filled.

Bots are shortened: "Bot (Beginner)" shows as "🤖Beginner".

The signs are now **sized in studs** (`BillboardGui.Size` in scale, 15×4.3), so far-away signs
shrink and no longer pile up over each other. Text uses `TextScaled`. Code is in
`ChessClient.client.lua`, where the sign is created and in the function that sets its text.

Still: `stills/2026-10-17i-table-signs.jpg`.

## Adobe art (first pass)
The user granted access to Illustrator, Photoshop and File Explorer. Both apps were driven by
script over COM, from PowerShell, rather than by clicking. Everything is in `art/ui/`; see
[[Design/UI Style]] for the pipeline.
- **45 icons**, drawn as vector code in one style: chunky ink outline, gradient fills, shine.
  - Illustrator saved an editable `.ai` master for each and exported 256 px PNGs.
  - They cover every emoji in `UiKit.ICONS`, including the 4 bot-level faces, pawns, crossed
    swords, trophy, gear, door, chessboard, crown and dice.
- **Card art:** 512 px exports for the four Play cards: robot, pawn, sparkle and crown.
- **Photoshop textures:** checker tile, rising "/" stripe tile, soft shine streak and a sunburst
  "rays" texture. They're white on transparent so the game can tint them.
- Previews in `art/ui/`:
  - `contact_sheet.png` (all icons on the panel green);
  - `card_preview.png` (mock Play cards plus textures).

**Not hooked into the game yet.** It needs the user to upload the PNGs (blocked for now). Then
add `UiAssets.lua` and teach UiKit/PlayScreen to use the images.

Fixed along the way:
- the first stripe tile came out solid, because a band fully off the canvas selected nothing and
  Photoshop filled the whole layer;
- the pawn and sword icons were too small and thin, so I enlarged them.

A Studio render of the in-game knight looked crude next to the vector icons, so the card art uses
the Illustrator art instead. The temporary render setup was removed from the place.

Back to [[Home]]
