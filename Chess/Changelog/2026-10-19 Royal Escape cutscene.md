---
tags: [changelog, cutscenes, escape, vfx, sfx]
---
# Royal Escape cutscene: the Snipe treatment (2026-10-19)

**The user's brief:** "Then work on Royal Escape", the same treatment as
[[Changelog/2026-10-19 Double Jump cutscene]].

## The cutscene: `scenes.KingEscape` in `Cutscene.lua`, about 7.5 s, gold
**Length:** `Settings.CUTSCENES.KingEscape` is now **7.5 s** (it was 2.6), and the opponent's clock
is held that long.

| Scene | Time | What happens | Sound |
|---|---|---|---|
| Tension | 0–2.4 s | A close shot on the king from behind its escape line, so the landing square sits in the background, pushing in slowly. **If the king is in check, red danger lines run from every checking piece to it** and pulse, with a heartbeat. A gold outline, a gold charge at its base, and a gold column rising around it. The king trembles and lifts off its square. | `braam`; `riser`, timed to cut dead on the vanish; `choir` swelling in; `heartbeat` and a low `dodge` sting when in check |
| Vanish | 2.4 s | **Impact frames:** white-hot → white silhouettes on black → black on white. The red lines strike empty air and burst into red sparks. A white pillar of light collapses upward as **the king streaks up it** and fades out. Gold and white shockwaves, a star, and gold sparks thrown up. | `trailerHit`, `beamBlast` |
| Sigil | | A cut to above the landing square. **A gold ring sigil and a white star draw themselves**, spinning the opposite ways. A gold beam comes down from the sky onto the square. A piece standing there is marked with a red outline. | `magic`, then `warpIn` |
| Drop-in | about 5 s | The king slams down out of the sky with gold afterimages. A big gold and white shockwave, a star, gold sparks, a crack and dust. **A capture launches the piece** with splinters, and gets white → black → white → black → red frames; a plain landing gets white → black → white. | `lowBoom`, `stomp`; with a capture, `woodBreak`, `crateBreak` and `impactBoom` |
| Settle | to the end | The sigil burns out. **Gold motes drift down** over the king. A slow low move round the king, then a wide shot of both squares. | `twinkle`; the choir fades out |

- **The landing shots look in from the board's centre,** so a king that escapes to an edge square
  isn't filmed from off the board.
- **The checking pieces come from the board on the client** (`attackersOf`: pawn, knight, king, and
  sliding pieces with a clear line). A king that isn't in check skips the red lines and the
  heartbeat.
- **Also changed:** the hand-coded 2.6-second Royal Escape scene was replaced.

## New sounds

| Key | Sound |
|---|---|
| `choir` | "Harken Sing" (an angelic choir), with reverb |
| `beamBlast` | "energy beam blast 1" (yodguard), with bass and reverb |
| `warpIn` | "279-S_appear" |
| `twinkle` | "Twinkle08", with reverb |

All of them load. They haven't been heard by ear.

## Tested (Studio playtest)
- **In double check, with a capture:** `4r2k/8/8/8/1b6/8/6n1/4K3 w`. The king on e1 is checked by
  the rook and the bishop and escapes to g2, taking the knight. Stills show the red lines from both,
  the column, the vanish frames, the sigil under the marked knight, the red landing frame with the
  knight launched, the crack and the motes.
- **Plain escape:** `7k/p7/8/8/8/8/P7/4K3 w`, e1 to c3, no check and no capture. It ran with no
  errors.

No errors or warnings, and no leftover ColorCorrection or Bloom.

**Fixed during testing:**
- the column was too strong and washed out the king under the bloom;
- the red lines were too thin to read;
- the vanish shot stared into empty sky;
- the landing shot on an edge square came from off the board and cropped the king.

**Not checked yet:**
- by ear;
- on a phone;
- black's side;
- the bot using it;
- the Tournament place.

## Double Jump camera (same day)
**The user's note:** the Double Jump "looks cut off". The flight camera now rises with the knight
(80% of its height) and looks at the knight itself, so it stays centred all the way up both arcs.
Before, it looked between the knight and the ground and lost it at the top. Checked in stills of
both leaps.

Back to [[Home]]
