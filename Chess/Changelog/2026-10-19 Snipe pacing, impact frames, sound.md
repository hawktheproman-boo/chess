---
tags: [changelog, cutscenes, snipe, vfx, sfx]
---
# Bishop Snipe: slower, manga impact frames, cinematic sound (2026-10-19)

**The user's feedback** on [[Changelog/2026-10-19 Snipe VFX]]:
- it still lacks impact frames;
- it is too fast to read;
- the sounds aren't dramatic enough.

## Pacing
The cutscene is now **10.5 s** (it was 6.0 s). That's `Settings.CUTSCENES.BishopSnipe` and
`SNIPE_CUTSCENE`, and the opponent's clock is held for that long.

| Scene | Time | What it does |
|---|---|---|
| Load | 0–2.8 s | A beat on the title before the rifle drops. The camera **cuts to a close-up of the bolt** for the rack, then back out as the bishop leans into the aim. |
| Scope | 2.8–5.2 s | A longer, slower zoom. |
| Fire | 5.2–7.1 s | **A held breath** of 0.5 s before the trigger (`SHOT_AT` = 5.7 s), then the impact-frame burst as a hitstop, and a slower recoil. |
| Hit | 7.1 s–end | **Slow motion:** the bullet takes about 1.9 s down the line. Each hit holds on its impact frames, and the final wide shot glides in more slowly. |

## Impact frames (`VfxKit.impactFrames`)
- **Manga-style frames:** the pieces and the rifle are redrawn as flat silhouettes in a
  ViewportFrame from the current camera, over a solid screen, with speed lines.
- **Frame types:**
  - `invert`: a black screen with white silhouettes;
  - `manga`: a white screen with black silhouettes;
  - `white`: the world blown out white-hot;
  - `red`: the world in red and black.
- **Where they're used:**

  | Moment | Frames (0.06 s each unless noted) | Then |
  |---|---|---|
  | The shot | white → invert → manga → invert → red | a 0.5 s burst of speed lines |
  | First and last hits | invert → manga → invert → red | |
  | Other hits | manga → red | |
  | The king ricochet | invert → manga, at 0.05 s each | |

  The action freezes while they play, so they also work as the hitstop.
- They only show for the two seated players.

## Sound
`Sounds.play(name, pos, { volume, speed, fadeAfter, fadeTime })` now returns the Sound, and
`Sounds.fade` fades one out. A LIB entry's `fx` adds `bass` (an EQ low boost), `reverb` (a hall tail)
or `slow` (muffled).

| Moment | Sounds |
|---|---|
| Title | `braam`: "Scorched Earth Braam" (APM), faded out at 2.4 s |
| From 1.7 s | `riser`: "REVERSE HARD STOP-Noise Build 06" (APM). It lasts 4 s and **cuts dead on the trigger pull**, so the shot comes out of silence. |
| The rifle lands | `impactBoom`: "cinematic-impact-boom" (fcracky) |
| The scope | `heartbeat`: "Heartbeat (loop)" (Screaming_Monkeys), with a bass boost |
| The shot | `sniperShot`, now pitched down with bass and reverb, plus `trailerHit`: "Angry Heavy Hitter Hit" (APM) |
| The bullet leaves | `slowWhoosh`: "Searing Whoosh…" (Pro Sound Effects), slowed and with reverb |
| Each hit | `bulletHit` (with bass) and `woodBreak` ("Wood Break 1", PSE). Plus `impactBoom` on the first hit and `lowBoom` ("Fear Enhancer Low Boom", APM) on the last. |
| The king | `ricochet` (with reverb) and a short, high `impactBoom` |
| The end | `rumble`: "Artillery Distant 2" (PSE) |

All of these load in a playtest. They're still unheard by ear, so the volumes are guesses.

## Tested (Studio playtest, same position, Bc1 snipes NE)
- A full run with no errors or warnings, and no leftover ColorCorrection or Bloom.
- Checked in stills:
  - the bolt close-up;
  - the slower scope zoom;
  - the red frame on the shot;
  - the slow-motion bullet past the knight, king, rook and queen.
- The silhouette frames were held for 2.5 s each in a separate test to check how they look: the
  white page with black silhouettes and speed lines, and the red frame.

**Not checked yet:**
- by ear;
- on a phone (the flashing frames);
- the Tournament place: push `Cutscene`, `VfxKit`, `Sounds` and `Settings`, and run
  `builders/cutscene_props.lua`.

Back to [[Home]]

## Tweaks after the user's review (same day)
- **The scope's red circle was offset:** it was a world-space ring on the target, so the camera's
  sway pulled it off the crosshair. The seated players now get the ring drawn **inside the scope
  overlay** (`ui.lock`). It closes in on the crosshair, then pings white. Spectators keep the
  world ring.
- **The ricochet looked unnatural:** the bullet hopped over the king in a curved arc.
  - Now every leg is a **straight line**. The bullet strikes the top edge of the king's crown,
    then changes course sharply, straight down into the next target.
  - After the strike the bullet tumbles end over end. Gold sparks fan up and onwards, and a few fly
    back towards the shooter.
  - The king is knocked back harder (20°) and rocks to rest.
  - The energy trail is one straight piece per leg, so it doesn't cut through the king.
  - Each target is hit at its own mid-height.
- **The impact frames didn't fill the screen:** the overlay sat inside Roblox's safe-area
  insets. The snipe ScreenGui now uses `ScreenInsets = None`, and in the playtest the frames fill
  the game view edge to edge, over the letterbox bars.
  - Roblox's own top-left buttons still show on top. Hiding them would mean turning off the
    topbar during the cutscene.

## The king dodges instead (the user's idea: Sans's "MISS" from Undertale)
This replaces the ricochet. An enemy king in the line now **sidesteps the bullet**.

**What happens:**
1. When the bullet is about a square away, the king snaps off the line (0.1 s), away from the
   camera.
2. A **grey afterimage** stays on its square and fades over 0.6 s. The bullet flies straight through
   it.
3. **"MISS"** pops up by the king's head:
   - Roblox's pixel `Arcade` font, light grey with a black outline;
   - it pops in, drifts up, and fades after 1.3 s.
4. There's a 0.35 s beat as the bullet passes. Then the king slides back to its square, and the
   bullet goes on to the targets behind.

**Details:**
- **Sound:** `dodge`, "Fast Pass By Airy Whooshes Windy 2" (Pro Sound Effects). The ricochet sound
  is no longer used.
- **Bullet path:** all legs stay straight, and the bullet keeps its height through the king's
  square.
- **Splinters** from hits never fly towards the camera side any more (one hit the lens in a test).

**Rules are unchanged:** the king is still never captured by a snipe.

**Checked in a playtest still:** the king aside, the grey afterimage, "MISS" over it, and the bullet
in the ghost.
