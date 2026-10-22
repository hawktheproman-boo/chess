---
tags: [changelog, cutscenes, passant, vfx, sfx, blender]
---
# Any Passant cutscene: a katana iaido (2026-10-19)

**The user's brief:** "Do the Any Passant cutscene next, same treatment." Mid-build, after seeing the
first version: "The scene could be better, make a katana model and do a katana slash sequence with a
flash step."

## The katana prop
- **Source:** `art/props/make_katana.py` (Blender) → `Katana.fbx` → Studio 3D Importer, uploaded to
  The Depths Studio. The preview render is `art/props/Katana_preview.png`.
- **What's in it:** a curved blade (it narrows to a point, with a ridge line), a gold collar, guard
  and pommel cap, a ridged dark-blue grip, and a black lacquered scabbard.
- **Built into the place** by `builders/cutscene_props.lua`, which now builds three props in
  `ReplicatedStorage.CutsceneProps`:
  - `Sniper`;
  - `Katana` (Blade, Guard, Grip);
  - `Saya` (the scabbard, as its own Model so it moves separately).
- **Pivot:** both share their pivot at the centre of the guard, with the blade towards -Z and the
  edge down.
- **Where it's built:** Chess?? only so far. The Tournament place still needs the builder run.
- **Fallback:** without the props, `makeKatana` builds part stand-ins.

## The cutscene: `scenes.PawnPassant` in `Cutscene.lua`, about 7.5 s, teal
**Length:** `Settings.CUTSCENES.PawnPassant` is now **7.5 s** (it was 2.2), and the opponent's clock
is held that long.

| Scene | Time | What happens | Sound |
|---|---|---|---|
| Lock-on | 0–2.6 s | A low camera behind the pawn, with the target beside it. **The sheathed katana drops in** at the pawn's hip, with a teal shockwave and sparks. **The unaware target gets a white pixel "?"**. A close-up on the guard: **the thumb pushes the blade an inch out** and a glint runs along the scabbard. The pawn sinks into its stance. | `braam`; `riser`, timed to cut dead on the flash step; `unsheath` |
| Flash step | 2.6 s | **The pawn vanishes**, leaving teal ghosts and a white-hot line where it went. Teal speed lines and impact frames: white-hot → white silhouettes on black → black on white. | `trailerHit`, `bladeRing` |
| The slashes | about 1 s | The frozen target from the front. **The pawn flickers in at four points around it** (left, front, right, back), and each time **the katana swings through it** with teal afterimages. **Each cut leaves a teal slash with a white-hot line hanging in the air**, at a different angle. A star, sparks and a small shake on each. | `bladeRing` four times, rising in pitch |
| Follow-through | | **The pawn stands behind the target, its back to it**, blade held out low to the side, the scabbard at its hip. A slow push-in with the cuts still hanging. | `slowWhoosh`, then a quiet `heartbeat` |
| Sheathe | | **The blade comes round to the scabbard's mouth and slides home slowly.** | — |
| Click | | **On the click, every cut flashes white and bursts, and the target splits in two**: the halves slide apart along the cut, topple and fade, with shards. A teal and white shockwave, a star, a crack. Black → white → black → red frames, a big shake. | `sheath`, then `cut`, `woodBreak`, `impactBoom` |
| Settle | to the end | A wide shot of all three squares. The katana fades out in teal sparks. | `rumble` |

## New sounds

| Key | Sound |
|---|---|
| `unsheath` | a sword draw (Roblok_studio), with reverb |
| `bladeRing` | "sword_swing_fast_whoosh_blade_ring_001", with reverb |
| `sheath` | "Katana Sheathe" (bluslip), with reverb |
| `cut` | "Black Slashes", with bass |

All of them load. They haven't been heard by ear.

## Tested (Studio playtest)
**Position:** `4k3/2n5/8/4P3/8/8/8/4K3 b`. A fake black player plays Nc7–d5, landing beside the
white pawn on e5. The pawn takes it with Any Passant, e5 to d6.

**Checked in stills:**
- the sheathed katana at the hip;
- the guard close-up;
- the flash-step frames;
- the four-cut flurry on the knight;
- the follow-through behind it;
- the sheathe;
- the red click frame with the knight split in two.

No errors or warnings, and no leftover ColorCorrection or Bloom. `ImpactFrameHold` was set on the
client only and is gone.

**Fixed during testing:**
- the first version (a plain dash-through) was replaced at the user's request;
- the guard close-up was too tight;
- the cut was hidden inside the target, so the marks are now longer and have a white-hot line;
- the target's halves used to fly off-screen, so they now slide apart in view.

**Not checked yet:**
- by ear;
- on a phone;
- black's side;
- the bot using it;
- the Tournament place: it needs the push and the props builder.

Back to [[Home]]
