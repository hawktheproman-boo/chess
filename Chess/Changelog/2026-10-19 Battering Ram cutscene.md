---
tags: [changelog, cutscenes, ram, vfx, sfx]
---
# Battering Ram cutscene: the Snipe treatment (2026-10-19)

**The user's brief:** "Do the Battering Ram cutscene next, same treatment as Snipe (VFX, impact
frames, dramatic sound, readable pacing)." It follows
[[Changelog/2026-10-19 Snipe pacing, impact frames, sound]].

## The cutscene: `scenes.RookRam` in `Cutscene.lua`, about 8 s, orange
**Length:** `Settings.CUTSCENES.RookRam` is now **8.0 s** (it was 3.0), and the opponent's clock is
held that long.

| Scene | Time | What happens | Sound |
|---|---|---|---|
| Wind-up | 0–2.6 s | A low camera in front of the rook, looking back at it, pushes in slowly. An orange outline and an orange charge draw in at its base. **It snorts steam like a bull** from two puffs at the top. It rocks back twice: a small rock, then a big one. Each stomp sends an orange shockwave, and the big one also cracks the square and throws sparks. Then a held crouch. | `braam`; `riser`, started 1.4 s in so it **cuts dead on the launch**; `snort` twice; `stomp` |
| Launch | 2.6 s | **Impact frames:** white-hot → the rook as a white silhouette on black with speed lines → a black silhouette on white. A ring behind the rook, a white ring on the board, and a burst of sparks thrown back. | `trailerHit`, `rush` |
| Charge | about 1–2 s | A low chase camera behind and beside the rook. Orange speed lines stay on screen. The rook accelerates, leaving **orange afterimages** and a dust trail. **Each piece it reaches is launched spinning into the air** as a copy that fades, with splinters, a star, rings, sparks and a crack. A hitstop on each: the first and last hits get black → white → red frames, the others white → red. | `woodBreak`, `crateBreak`, then `impactBoom` on the first hit, `lowBoom` on the last, and `stomp` on the others |
| Skid | the last 20% of the charge | It brakes with sparks at its base, leans into the stop, and stomps down. **An enemy king right in front of where it stops flinches**, leaning back with a red pixel "!" over it. | `skid` (a wood scrape), `stomp`, and a high `dodge` for the "!" |
| Settle | to the end | A wide shot over the cracked line, with dust. | `rumble` |

**Also changed:** the hand-coded 3-second Ram scene was replaced, and the Ram's title colour is now
orange.

## Shared changes for every ability's cutscene
- The ability ScreenGui is edge to edge (`ScreenInsets = None`), so impact frames fill the screen.
- The title sits in the bottom bar, away from Roblox's top-left buttons.
- The gui is passed to the scene as `opts.gui`, which the impact frames need.
- `Sounds.play` takes `timePosition`, to start part-way into a sound (a riser cut to fit).
- **Studio only:** `workspace` attribute `ImpactFrameHold = <seconds>` holds every impact frame that
  long. It's set on the client, to inspect frames. Remove it after use.

## New sounds (Pro Sound Effects unless noted)

| Key | Sound |
|---|---|
| `snort` | "Bull Goblin Snorts 6", pitched down, with bass |
| `stomp` | "Deep Impacts 7", with bass |
| `rush` | "Cloth Whooshes Fast Whooshes Rumbling Pass Bys" |
| `skid` | "Table And Chair Movement 2" (a wood scrape) |
| `crateBreak` | "wood_crate_break3" (srth_h) |

All of them load. They haven't been heard by ear.

## Tested (Studio playtest)
**Position:** `K7/8/8/8/8/8/8/R1n1b1k1 w`. Ra1 rams right: it smashes the knight on c1 and the
bishop on e1, and stops on f1 in front of the king on g1.

**Checked in stills:**
- the wind-up with the steam and the charge;
- the launch frames (held for 1.5 s with the Studio attribute);
- a red hit frame with splinters and the launched piece;
- the orange afterimages and speed lines;
- the stop with the king's "!" and the cracks left on the squares.

No errors or warnings, and no leftover ColorCorrection or Bloom.

**Fixed during testing:** the afterimages were too strong (they washed out under the bloom). They're
now at 0.75 transparency.

**Not checked yet:**
- by ear;
- on a phone;
- a Ram with no king at the end, or one that runs to the edge;
- black's side;
- the bot using it;
- the Tournament place.

Back to [[Home]]
