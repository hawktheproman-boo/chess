---
tags: [design, ui]
---
# UI Style

This is the look of every chess screen. It's reverse-engineered from two popular Roblox games the
user shared on 2026-10-17 and fitted to chess in a bright park, for all ages. The code is in
`UiKit.lua`, and every screen builds through it.

## The two references
**A. "Charge Your Egg!" (simulator style).** We use it for panels, buttons, the HUD and the lobby.
- A dark panel with a thick black outline and a faint pattern.
- Themed ornaments (sakura) that break over the corners.
- A huge white title in a very heavy rounded font, with a thick black outline and a drop shadow.
  The subtitle shows one keyword in the theme colour.
- The close button is a red square with a white X and a black outline. It sits over the corner,
  slightly tilted.
- Buttons:
  - saturated, with diagonal stripes, a black outline and an icon on the left;
  - white text with a black outline.
- Locked buttons are dull, with a padlock and an "(Unlocks at …)" line.
- Shop and Index sit on the left, each with an icon, text and a colour of its own. Square icon
  buttons carry red number badges.

**B. "Matchmaking" (premium style).** We use it for the Play screen.
- The world is blurred and darkened behind. A tiny letter-spaced kicker ("BETA") sits over a huge
  bold title.
- Square cards:
  - a two-colour vertical gradient and a dashed inner border;
  - art faded behind;
  - an icon over a letter-spaced name ("DUEL") and a huge centre label ("1v1");
  - a corner tag ("🔥 MOST POPULAR").
- The picked card grows and gets a white back plate. A soft shine sweeps across it, and a green
  PLAY pill appears.
- Other parts:
  - a scroll indicator bar;
  - an outlined-circle X;
  - small muted letter-spaced footer text.

## Our version
| Reference | Chess |
|---|---|
| Purple panel + diamond pattern | Deep forest green (`T.panel` 30,59,34 → `T.panelDeep` 18,38,21) + faint **checkerboard**, 4 px ink outline |
| Sakura corner clusters | Chess-piece corner stickers (knight + pawn + laurel); gold crown + laurel for Tournament (Part B art) |
| Pink keyword | **Gold** `T.gold` (255,200,61) |
| Striped green button | `button()` styles: primary green, blue, gold, red, abilities (purple-red), secondary (dark green), locked (slate) |
| Matchmaking cards | **Play screen**: VS BOT, CLASSIC 1v1, ABILITIES 1v1, TOURNAMENT CUP (VIP, locked) |
| Purple→gold gradient | Bot teal→green, Classic gold→green, Abilities red→purple, Tournament gold→navy |
| Soldier art | Our own 3D pieces, rendered and faded (Part B). For now, a giant faded emoji |

**Fonts** (all Roblox built-ins, nothing to upload):
- **Fredoka One** (`Ui.TITLE`) for titles, buttons and tags, always with an ink outline
  (`Ui.chunky`);
- **Montserrat Heavy** (`Ui.DISPLAY`) for the Play screen title and card labels;
- **Builder Sans** for small body text.

**Rules:**
- No text inside images, so text stays sharp and editable.
- On dark panels, text is white or cream with an ink outline.
- Minimum about 16 px at 1280×720.
- Never use colour alone to carry meaning: grades keep their symbols and locked keeps its padlock.

### Gotchas
- **A `UIGradient` on a TextLabel or TextButton tints its text too.** So button faces and title
  bars use a flat colour plus a `Sheen` overlay (`Ui.highlight`). Gradients only go on plain
  Frames (panel backgrounds, cards).
- `card()` returns a **transparent body**. The background (gradient, checker, outline) is a sibling
  `Bg` frame, so list layouts inside the body don't pick the background up.
- `ViewportFrame` pieces don't show in Studio MCP `screen_capture`. Check them by script.

## Part B: the Adobe art (made 2026-10-17; waiting on uploads)
Everything is in `art/ui/` in the repo, made by scripts so it can be remade or tweaked in one edit.
Illustrator and Photoshop are driven from PowerShell through their COM interface, e.g.
`(New-Object -ComObject Illustrator.Application).DoJavaScriptFile("...jsx")`.

| Step | File | Output |
|---|---|---|
| Icon vectors | `make_icons.py` | `svg/chess_ui_<name>.svg` (45 icons, 512 artboard) |
| Illustrator | `illustrator_export.jsx` | `ai/*.ai` editable masters + `png/chess_ui_<name>.png` at 256 px |
| Illustrator | `illustrator_cardart.jsx` | `png/chess_ui_card_<mode>_512.png` (bot, Classic, Abilities, Tournament) |
| Photoshop | `photoshop_textures.jsx` | `png/chess_ui_checker_64.png`, `stripes_64`, `shine_256`, `rays_512` (white on transparent) |
| Preview | `contact_sheet.py` | `contact_sheet.png`, plus `card_preview.png` / `texture_preview.png` |

**Icon style:**
- the chunky ink outline is drawn as a 40 px ink copy of the silhouette under the fills;
- flat fills with a top-to-bottom gradient (lighter at the top);
- ink detail lines and a white shine at 45%.

To add or change an icon, edit `ICONS` in `make_icons.py`, then run it, the Illustrator export
and `contact_sheet.py`.

The textures are pure white. The game tints them with `ImageColor3` and fades them with
`ImageTransparency`:
- the checker tiles behind panels at 64 px;
- the stripes go over buttons;
- the shine sweeps the picked card;
- the rays spin slowly behind it.

**Card art:** the pieces are built from parts in-game, and a test render of the knight looked
crude next to the vector icons. So the cards use the Illustrator art, which is consistent with the
icons.

**Hooking it up (after the first upload):**
1. Upload the PNGs under the group.
2. Add `UiAssets.lua` (`name -> rbxassetid`).
3. In UiKit:
   - `setText` and `tile` show an `ImageLabel` icon when the name has an id (the emoji stays as
     the fallback);
   - `checker()` and `stripes()` use the tiles;
   - PlayScreen uses the card art and shine, plus the rays behind the picked card.

**Chess pieces (2D):** `make_pieces.py` makes 12 pieces, exported with the icons. In the game
they're drawn **without uploads** through `EditableImage`, from pixel data packed by
`make_piece_data.py` into `PieceArt.lua` (see `PieceIcons.lua`). The 3D-render icons are the
fallback. Rerun `make_piece_data.py` after any change to the piece art.

**Still to make:** 9-slice frames, corner stickers (knight / pawn / laurel and crown / laurel),
and the picked-card plate. Only make them if the code versions look plain once the images are in.

**Firefly:** not used so far. It stays optional, for mood boards and background ambience only.

Stills:
- `stills/2026-10-17f-play-screen.jpg`
- `stills/2026-10-17g-settings-dark.jpg`
- `stills/2026-10-17h-lobby-dark.jpg`
- `stills/2026-10-17i-table-signs.jpg`

Back to [[Home]]
