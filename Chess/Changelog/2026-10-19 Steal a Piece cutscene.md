---
tags: [changelog, cutscenes, steal, vfx, sfx]
---
# Steal a Piece cutscene: a heist (2026-10-19)

**The user's brief:** "Do the Steal a Piece cutscene next, same treatment."

## The cutscene: `scenes.StealPiece` in `Cutscene.lua`, about 8 s, gold and red
**Length:** `Settings.CUTSCENES.StealPiece` is now **8.0 s** (it was 2.4), and the opponent's clock is
held that long. The piece stays on its square; the board redraws it in its new colour when the
cutscene ends.

| Scene | Time | What happens | Sound |
|---|---|---|---|
| The mark | 0–2.6 s | A low camera from the stealer's side, looking up at the target, pushing in. **A red sigil draws itself under it** (a ring and a gold star, spinning), with a red outline and a red charge. **It notices: a red pixel "!?"**. Then **three gold chains shoot in** from the stealer's side of the board, one after another, and bind it, with a star and sparks where each one hits. It strains against them. | `braam`; `riser`, timed to cut dead on the yank; `magic`; a low `dodge` for the "!?"; `chains`; `stomp` |
| The yank | 2.6 s | **Impact frames:** white-hot → white silhouettes on black → black on white. A gold shockwave and dust. **It's ripped into the air spinning**, with the chains still taut, and gold afterimages. | `trailerHit`, `chains` (faster), `rush` |
| The flip | | **Its old colour shatters off like glass** (shards in its old colour and red), and **underneath it's the stealer's colour**, with a gold outline. A white star, a gold glow, and red and gold rings standing in the air. The chains fall away. Black → white → black → red frames, a big shake. | `glassBreak`, `impactBoom` |
| The drop | | **It drops back onto its square, turned to face its new side.** A gold and white shockwave, gold sparks, a crack and dust. **A gold pixel "STOLEN!" with a red outline slams in** over it. | `stomp`, `lowBoom`, `kaching` |
| Settle | to the end | Gold motes drift down. A slow move round it, then a wide shot. The stamp floats up and fades. | `twinkle` |

- **The stealer's side** is worked out from the piece's file and the stealer's colour, so the camera
  and the chains always come from the stealer's back rank.
- **The new-colour piece** is a copy built with `Pieces.build` in the stealer's colour. The original
  is hidden locally until the board redraws.
- **The chains** are real links: 60 small gold metal parts per chain, every other one turned 90°.
  They're laid along the line each frame, so they shoot out and stay taut as the piece lifts.
- **Also changed:** the hand-coded 2.4-second Steal scene was replaced. The title was already gold.

## New sounds

| Key | Sound |
|---|---|
| `chains` | "Chain Movement 2" (Pro Sound Effects), with reverb |
| `glassBreak` | "Glass_Heavy_2", with reverb |
| `kaching` | "retro cash register ka-ching" |

All of them load. They haven't been heard by ear.

## Tested (Studio playtest)
**Position:** `4k3/8/8/3r4/8/8/8/4K3 w`. White steals the black rook on d5.

**How the steal was granted:** with the ChessDebug `wallet` verb (one steal), a session-only
sandbox wallet. The real wallet wasn't touched.

**Checked in stills:**
- the "!?" and the sigil;
- the three chains binding the rook;
- the yank frames;
- the white rook dropping back with the "STOLEN!" stamp;
- the motes.

No errors or warnings, and no leftover ColorCorrection or Bloom.

**Fixed during testing:**
- the chains were energy beams that read as wisps, so they're now gold links;
- the landing shot cut off the stamp, so it's pulled back and the stamp is lower.

**Not checked yet:**
- the glass-shatter frame in a still;
- by ear;
- on a phone;
- black stealing;
- a Classic game (Steal works there too);
- the Tournament place.

Back to [[Home]]
