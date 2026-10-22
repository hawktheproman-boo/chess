---
tags: [changelog, cutscenes, jump, vfx, sfx]
---
# Double Jump cutscene: the Snipe treatment (2026-10-19)

**The user's brief:** "Do the Double Jump cutscene next, same treatment" (as
[[Changelog/2026-10-19 Battering Ram cutscene]]).

## The cutscene: `scenes.KnightJump` in `Cutscene.lua`, about 8.5 s, blue
**Length:** `Settings.CUTSCENES.KnightJump` is now **8.5 s** (it was 2.8), and the opponent's clock
is held that long.

| Scene | Time | What happens | Sound |
|---|---|---|---|
| Wind-up | 0–2.0 s | A low side camera pushes in. A blue outline and a blue charge draw in at its base. **The knight rears up like a horse** and stamps down, with a blue shockwave, a crack and dust, then crouches. | `braam`; `riser`, timed to cut dead on take-off; `neigh`; `stomp` |
| Leap 1 | 2.0 s | **Impact frames on take-off:** white-hot → white silhouettes on black → black on white. A shockwave and dust on the take-off square. A **high arc** (3 squares high) with **hang time at the top**. Blue afterimages and blue speed lines. The camera tracks it from the side, keeping the board in frame. | `trailerHit`, `leap`, `rush` |
| Landing 1 | | A blue and a white shockwave, a star, sparks, a crack and dust. **A capture launches the piece spinning into the air**, with splinters and black → white → red frames. A landing with no capture gets one quick frame. | `stomp`; with a capture, `woodBreak`, `crateBreak` and `impactBoom` |
| Leap 2 | | A **whip-pan** to the next leg, a short crouch, and it springs again **even higher (3.6 squares), spinning a full turn** in the air. | `leap`, `slowWhoosh` |
| Landing 2 | | **The biggest hit:** white → black → white → black → red frames, a bigger double shockwave and crack, and a big shake. A capture launches the piece. | `lowBoom`, `trailerHit`, `stomp` and the capture sounds |
| Settle | to the end | A wide shot over all three squares. | `rumble` |

- **The leap height is on purpose:** I lowered it during testing, and the user asked to keep it high
  ("adds to the dramatic effect"). Only the camera framing was kept from that change.
- **Also changed:** the hand-coded Double Jump scene was replaced, and the title is now blue.
- **Rules unchanged:**
  - captures happen on either landing;
  - landing back on the starting square works, since the second leg simply points back.

## New sounds

| Key | Sound |
|---|---|
| `neigh` | "Horse Neigh" (sd3ric), with reverb |
| `leap` | "Whoosh By Fast Airy Swooshing Whipping Thuds 3" (Pro Sound Effects) |

Both load. They haven't been heard by ear.

## Tested (Studio playtest)
**Position:** `7k/8/8/8/4b3/2p5/8/KN6 w`. The knight on b1 jumps to c3, taking the pawn, then to e4,
taking the bishop.

**Checked in stills:**
- the rear-up;
- both leaps with the blue speed lines;
- the hang time;
- the landing frames: a red frame with the launched piece, and the final white-on-black silhouettes.

No errors or warnings, and no leftover ColorCorrection or Bloom.

**Not checked yet:**
- by ear;
- on a phone;
- a jump with no captures, or one that lands back on its own square;
- black's side;
- the bot using it;
- the Tournament place.

**Later the same day:** the flight camera was changed to keep the knight centred all the way up
(the user said it looked cut off). See [[Changelog/2026-10-19 Royal Escape cutscene]].

Back to [[Home]]
