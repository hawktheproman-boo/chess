---
tags: [design, store, icons, thumbnails, art]
---
# Store art: the game icon, thumbnails and gamepass icons (plan, 2026-10-20)

**The user's choices (2026-10-20):**
- **Name:** **CHESS??**, in capitals. "??" is the chess mark for a blunder.
- **Icon:** the **bishop with a sniper**.
- **Style:** **in-game 3D renders**: our real pieces, props and VFX, with chunky text on top.
- **Gamepass icons:** all of them: the 4 ability passes, VIP, and Steal a Piece (a developer product).

## Specs (Roblox)
| Asset | Upload size | Shown as | Keep in mind |
|---|---|---|---|
| **Experience icon** | 512×512 PNG | A rounded square, often tiny (about 150 px on phones) | One subject, big. Little or no text. Keep it inside the central 80% |
| **Thumbnails** | 1920×1080 PNG (16:9), up to 10 | Big on the game page, and the first one in sorts and ads | The **first one matters most**. 3–4 words of text at most, readable on a phone |
| **Gamepass icons** | 512×512 PNG | **A circle** (the corners are cut off) | Keep everything inside the circle. They show at about 100 px in the purchase prompt |
| **Developer product icon** (Steal) | 512×512 PNG | A circle in the purchase prompt | Same as the passes |

## Look (all of it)
- **Renders:** made in **Blender**.
  - The pieces come from `art/pieces/make_sets.py` (the Classic set, ivory and ebony).
  - The props come from `art/props` (rifle, katana).
  - VFX use the `art/vfx` textures (glow, star, ring, slash, speedlines) as emissive planes.
- **Bright and punchy,** like the HUD:
  - saturated backgrounds, a rim light, a soft bloom;
  - one accent colour per ability (its card colour), with the **rarity colour** as the gamepass
    ring.
- **Text:** Fredoka One (the game's title font): white with a thick dark outline, "??" in red.
- **The "??" blunder mark:** our own red rounded tag with a white "??". Never chess.com's badge.
- **Composite and text:** in Photoshop through COM scripting (see the Adobe memory), so they're
  rebuilt from a script.
- **Files:**
  - sources in `art/store/` (`make_store.py` for Blender, a `.jsx` for Photoshop);
  - exports in `art/store/out/`.
- **The user uploads them:**
  - the experience icon and thumbnails: Creator Dashboard → the experience → Places / Icon /
    Thumbnails;
  - the pass icons: each pass's settings;
  - the Steal icon: the developer product's settings.

## The experience icon (512×512): **draft 1 made 2026-10-20**
**Source:** `art/store/make_store.py` (Blender: `make_icon()`, `render_icon()`) → `art/store/finish_icon.py`
(Python/PIL adds the "??" tag in Fredoka One, read from Roblox's own font folder) →
`art/store/out/icon_512.png`. Also written: `icon_1024.png` and `icon_sizes_preview.png` (the icon at 512, 150
and 64 px, with rounded corners).

**Scene file:** `art/store/store.blend`.

**The draft:**
- the Classic bishop, the Snipe rifle from the game in front of it aimed left, and a glowing red
  scope with a star glint;
- the laser off the left edge;
- dark red board squares, and a red glow fading to black;
- the "??" tag top left, over the dark corner. It was first top right, but it covered the
  bishop's head.

**Draft 2 (the same day, at the user's request):**
- a **tighter crop**: lens 62 → 75 mm, retargeted, so the bishop and rifle fill the icon;
- the tag is a little smaller (23% of the width), so it clears the scope glint.

It holds up at 150 px. **Approved by the user (2026-10-20).** Upload `art/store/out/icon_512.png`.

The original plan:
**The white bishop, three-quarter view, aiming the sniper rifle out at the viewer**, slightly tilted
up:
- a red scope glint, and a thin red laser line crossing the frame;
- a deep red-to-black radial background with soft speed lines;
- a small **red "??" tag** in the top-right corner (the only text).

**Fallback** (if the store crops it or moderation objects to it): the same bishop with the scope
crosshair over it, without the laser.

## Hero thumbnail: **draft 1 made 2026-10-20**
**Source:** `make_store.py` (`make_hero()`, `render_hero()`) → `art/store/finish_hero.py` (the title) →
`art/store/out/thumb_hero.png` (1920×1080), plus `thumb_hero_small.png` (480×270, to check it reads small).

**The draft:**
- **The board and the line:** a red-and-black 8×8 board. The white bishop on f2 is in the right
  foreground, with the rifle aimed up the long diagonal.
- **The shot:** a white-hot trail with a red halo. The black knight on c5 bursts into about 70
  shards, with a soft shockwave ring and an impact star. The pawn on b6 behind it is knocked over and
  chipped. The rook on a7 stands next in line.
- **The rest:** the black king watches from e7, and a red glow fills the background.
- **The title:** "**CHESS??**" big in the top left, "CHESS" white and "??" red, in Fredoka One with a
  dark outline and a shadow over a soft dark wash.
- **Camera:** behind the shooter's left shoulder, 30 mm.

It renders in about 3 s at 96 samples in EEVEE. **Approved by the user (2026-10-20).** Upload
`art/store/out/thumb_hero.png` as the first thumbnail.

## Thumbnails 2–5: **draft 1 made 2026-10-20**
**How they're made:**
- `art/store/make_thumbs.py` (Blender: `render_thumbs()`) renders them.
- `art/store/finish_thumbs.py` adds the titles in the hero's style.
- **Outputs:** `out/thumb_<name>.png`, plus `out/thumbs_preview.png` (all 5 small, in upload order).

| # | File | Picture |
|---|---|---|
| 2 | `thumb_abilities.png` | **2×2 panels**: Any Passant (a new render: the pawn with the katana mid-cut, two teal slashes), Double Jump, Battering Ram and Royal Escape (the pass renders). Each sits on its colour with rays, its name and its rarity tag. **"CHESS... WITH ABILITIES!"** sits on a gold-edged pill in the middle |
| 3 | `thumb_dodge.png` | The black king leaning out of the bullet's path, a see-through afterimage where it stood with the trail through its head, the white bishop shooter far back. **"THE KING DODGED?!"** and a red **MISS** stamp |
| 4 | `thumb_trophy.png` | **Draft 2 (the user's note: "a crowd of people cheering on the winner"):** a blocky Roblox-style champion on a navy and gold podium, waving and holding the gold king trophy up in one hand, with two rows of cheering avatars in front (their backs to us, arms up), confetti and spotlights on purple. **"TOURNAMENTS"** in gold and **"WIN THE CROWN!"** at the top left |
| 5 | `thumb_versus.png` | **Draft 2 (the user's note: "two roblox characters playing chess"):** two avatars seated at a park table like the lobby's (wooden top, green board, mid-game pieces), seen side-on. One reaches for a piece, the other has a hand at the chin, thinking. A little robot head floats by and trees stand behind. **"PLAY FRIENDS / OR BOTS!"** centred across the top |

**The avatars:**
- `character()` in `make_thumbs.py` builds classic R6 proportions in studs, as in the game: legs 2,
  torso 2×2×1, arms 1×1×2, and a rounded-cylinder head with two eyes and a smile.
- Each has pivoted limbs for poses, a skin, shirt and pants colour, and an optional cap.
- They're our own blocky figures, with no Roblox logos or trademarked faces.

**Upload order:** hero, abilities, dodge, tournaments, versus. **Waiting on the user's verdict.**

## Thumbnails (1920×1080): the original plan
1. **The hero (first slot):**
   - "**CHESS??**" huge at the top left;
   - the bishop sniping down a diagonal of a board;
   - the bullet's trail, and black pieces bursting into splinters;
   - one impact-frame flash.
2. **"CHESS... WITH ABILITIES":** four panels, each a beat from its cutscene:
   - Double Jump: the knight mid-leap;
   - Battering Ram: the rook launching pieces;
   - Any Passant: the katana cuts hanging in the air;
   - Royal Escape: the king slamming down.
3. **"THE KING DODGED?!":**
   - the king sidestepping the bullet, with a grey afterimage and a "MISS" stamp;
   - the funny moment from the Snipe cutscene.
4. **"TOURNAMENTS":** the lobby from above:
   - the stage with its LIVE screen;
   - the giant king fountain;
   - the tables;
   - the gold Champions board.
5. **"PLAY FRIENDS OR BOTS":** a close-up of a park table, with the bot-level cards and the board
   mid-game.

## Gamepass and product icons: **draft 1 made 2026-10-20**
**How they're made:**
- `art/store/make_passes.py` (Blender: `render_all()`) renders each subject on a transparent
  background, as `out/pass_<kind>_render.png`.
- `art/store/finish_passes.py` puts it on its disc:
  - the ability's colour as a radial gradient, plus a soft shadow;
  - the subject **auto-fitted inside the circle**, so every visible pixel is within 40% of the
    width from the centre;
  - the rarity ring with a dark outline;
  - the 2D extras.
- It writes `out/pass_<kind>.png` (512×512) and `out/passes_preview.png` (the set at 250 and 100 px).

| File | Upload to | Disc / ring | Picture |
|---|---|---|---|
| `pass_jump.png` | Double Jump pass 2040261216 | blue / Epic lavender | the knight mid-leap, with two glowing blue leap arcs |
| `pass_snipe.png` | Snipe pass 2037519702 | red / Epic lavender | the bishop with the rifle, a red scope glint, a faint red crosshair |
| `pass_ram.png` | Battering Ram pass 2036577735 | orange / Uncommon green | the rook leaning into a charge, black debris, a dust ring, speed lines |
| `pass_escape.png` | Royal Escape pass 2040423129 | navy / Common blue | the king in a glowing pillar on a gold sigil. The navy was chosen because a gold disc hid the pillar |
| `pass_vip.png` | VIP pass 2037495121 | purple / gold | the king wearing a gold crown with red jewels, sparkles, a "VIP" ribbon |
| `pass_steal.png` | Steal a Piece product 3719153067 | red / gold | a knight half turned white (ivory base, black head) in gold chains, a red sigil, a red "!?" tag |

**Fixed along the way:**
- subjects poking out of the circle, now fitted to the circle rather than a square;
- the Double Jump dust ring, which made the knight small;
- the Royal Escape pillar, which was too tall;
- a stray light card that cut through Royal Escape;
- the Steal disc, which was too dark.

**Draft 2 (the same day, from the user's notes):**
- **VIP is centred.** The 3D sparkles were pulling the auto-fit off-centre; six even sparkles are now
  drawn in the finish.
- **Royal Escape is angelic:**
  - white feathered wings (two rows) spread behind the king;
  - a glowing gold halo floating above the cross;
  - golden light rays from above, on a sky-blue disc.
  - The old gold pillar is gone.
- **Double Jump is more "epic":**
  - the knight rears at the top of its leap, seen from slightly below;
  - two glowing see-through afterimages trail it back along the arc;
  - a thick blue energy trail with a white-hot core;
  - a light burst and anime rays on a deep-blue disc.

**Waiting on the user's verdict.**

The original plan:
Each icon has a **circle ring in the rarity colour**, the ability's colour behind it, and the piece
mid-ability:

| Pass | Rarity ring | Picture |
|---|---|---|
| Double Jump (2040261216) | Epic (lavender) | The white knight mid-leap, with two blue arc trails and a dust ring under it |
| Snipe (2037519702) | Epic (lavender) | The bishop with the rifle, through a red scope crosshair |
| Battering Ram (2036577735) | Uncommon (green) | The rook charging out of the frame, with orange speed lines and flying debris |
| Royal Escape (2040423129) | Common (blue) | The king in a gold pillar of light over a gold sigil |
| VIP (2037495121) | Gold | The king wearing a gold crown, with sparkles and a "VIP" ribbon |
| Steal a Piece (product 3719153067) | Red and gold | A black piece in gold chains turning white, a red sigil, a small "!?" |

The **Swap pass (2036241682)** is retired: take it off sale, and it needs no icon.

## Order of work
1. **The experience icon,** sent to the user to approve.
2. **Thumbnail 1** (the hero).
3. **The 6 pass and product icons,** as one consistent set.
4. **Thumbnails 2–5.**

At each step: render in Blender, composite and add text in Photoshop, then send to the user to look
at. Nothing is uploaded by the agent.

## Open
- Should the hero thumbnail show a tagline under "CHESS??", such as "...but every piece has a
  power"? Ask when building it.
- Weapons in store images: the rifle is a cartoon prop with no gore, which Roblox's guidelines
  allow. Keep it stylised.

Back to [[Home]]
