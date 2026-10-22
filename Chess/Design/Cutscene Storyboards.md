---
tags: [design, cutscenes, vfx, sfx]
---
# Cutscene storyboards (Phase 2 plan, 2026-10-19)

**User's brief (2026-10-19):**
- The ability cutscenes get proper **VFX and SFX**.
- They're planned as storyboards first; building waits (the user is short on usage).

**Style references (user):**
- "Roblox VFX: Chromatic Opus" (Plebarae): https://www.youtube.com/watch?v=V-zNBHnx1kY
- "Enkidu: Enuma Elish | Roblox Studio VFX Showcase" (Ako Shiba): https://www.youtube.com/watch?v=vgYRw8hRj0g
- "How to ACTUALLY Use VFX in Roblox" (Develuper): https://www.youtube.com/watch?v=TkNZETIu0CM

**What that style means here:** anime-style ability VFX:
- a short **charge-up**, then a **hitstop + impact frame** (1–2 frames of flash or inverted colour);
- **shockwave rings**, **beams and slashes** made from meshes and Beams;
- **sparks, debris and smoke** particles, with glow (Neon + Bloom);
- **camera shake** and a fast cut back.

Readable on a chessboard, never long: the opponent's clock is held for the whole scene
(`Settings.CUTSCENES`, `ChessTable:requestAction`).

## How they'll be built
> **As built:** the scenes ended up hand-coded in `Cutscene.lua` (no bakes, no `CutscenePlayer`). Use [[Design/Cutscene Treatment]] for new scenes; the plan below is history.

- **Motion:** Blender, baked to Lua.
  - The camera path, FOV, and every moving piece are baked per frame (30 fps) into
    `Shared/CutsceneBakes/<Ability>.lua`, in **square space** (the acting piece at the origin facing
    −Z, 1.4-stud squares).
  - The format and the conversion copy Descent Depths' `bake_v2.py`.
  - Distance-dependent travel (the snipe line, the ram charge, jump legs) is stretched to the real
    squares by the player.
- **VFX and SFX:** played by the game at the bake's **markers** (`fx:shockwave`, `sfx:impact`,
  `hit` …), through a new `VfxKit` module (below). `hit` calls `onHit(sq)`, which removes the
  captured piece as today.
- **Player:** `CutscenePlayer.lua` replaces the hand-coded scenes in `Cutscene.lua`, keeping them
  as the fallback.
  - Everyone near the table sees it. Only the two seated players get the camera.
  - 2D mode hides as today.
- **Colour identity:** each ability uses its card's accent (AbilityBar):

| Ability | Colour |
|---|---|
| Pawn | teal |
| Knight | blue |
| Bishop | red |
| Rook | orange |
| Queen | purple |
| King | gold |
| Steal | gold + red |

- **Length:** each storyboard says its total. The total becomes `Settings.CUTSCENES[id]`, the
  clock hold.

## VfxKit (made once, reused by every scene)
**Built 2026-10-19** as `StarterPlayerScripts/Chess/VfxKit.lua` with procedural textures (`art/vfx/make_textures.py`); see [[Changelog/2026-10-19 Snipe VFX]]. Built so far: shockwave, decal (crack), flare (star/glow/slash), sparks, charge, beam, aura, impactFrame, speedLines, bloom. Not yet: hitstop as a helper (done inline), afterimage, smoke flipbook (uses Roblox's built-in smoke).
**Effects:**

| Effect | What it is | Built from |
|---|---|---|
| `impactFrame(style)` | 2 frames: white flash, or black/white invert, plus speed lines | ScreenGui frames + a speed-line image |
| `hitstop(t)` | 0.05–0.1 s freeze of the scene (pieces and particles pause) | the player's clock pauses |
| `shockwave(pos, color, size)` | a flat ring that expands and fades, plus a second thinner ring | a ring mesh (Blender) + Neon + transparency tween |
| `crack(pos)` | a ground-crack decal on the square that fades over 1 s | a crack texture (Illustrator pipeline) |
| `debris(pos, n, color)` | small chunks of the hit piece flying out and bouncing | unanchored mini-parts, client-only, cleaned up |
| `sparks(pos, color)` | bright streak sparks | ParticleEmitter (spark texture, Drag, light emission) |
| `smoke(pos)` | a soft dust puff | ParticleEmitter (smoke flipbook) |
| `beam(a, b, color, width)` | an energy line with scrolling texture and glow | Beam + two Attachments + PointLight |
| `charge(pos, color)` | particles converging inwards, plus a growing glow orb | ParticleEmitter (negative speed / Attractor) + Neon sphere |
| `aura(model, color)` | a glowing outline and light on a piece | Highlight + PointLight |
| `afterimage(model, n)` | fading ghost copies along a fast move | clones at 0.6 → 1 transparency |
| `slash(cf, color)` | a crescent slash mesh that sweeps and fades | a crescent mesh (Blender) |
| `shake(power, t)` | camera shake | existing `CameraRig.shake` |
| `letterbox` | the cinematic bars | existing `Cutscene` overlay |
| `title(text, color)` | the ability name slammed in | existing banner, with a punch-in |

**Art to make** (Blender meshes, and Illustrator/Photoshop textures through the art pipeline):
- a ring mesh and a crescent mesh;
- textures: spark, smoke flipbook (4×4), impact star, crack, speed lines, scrolling energy.

## SFX palette
All sounds come from the Creator Store (free, Roblox-licensed), searched with the Studio MCP when
building. Their ids go in `Sounds.lua`. Kept short and punchy, with a little pitch randomisation.

| Key | Sound |
|---|---|
| `charge` | a rising energy whoosh, 0.6–0.8 s |
| `whoosh` | a fast air pass |
| `impact_heavy` | a deep boom with crunch (the Ram, the king's landing) |
| `impact_light` | a sharp hit / snap (a capture) |
| `shatter` | stone breaking (a captured piece breaking apart) |
| `shot` | a sniper crack with a tail echo |
| `ricochet` | a zing (shots passing the king) |
| `magic` | a sparkle / shimmer (Royal Escape, Steal) |
| `teleport` | a vwoop, in and out (Royal Escape) |
| `magnet` | a metallic hum plus a clank (Steal) |
| `stomp` | a dull thud and a dust puff (knight landings) |
| `sting` | a 1-second musical hit under the ability title (one per ability colour, or one shared) |

## Storyboards
Times are seconds from the start. "Cam" is the camera (only for the seated players).

### 1. Snipe (bishop): 10.5 s (was 6.0; slowed per the user, see [[Changelog/2026-10-19 Snipe pacing, impact frames, sound]]), red. **Built 2026-10-19** (the user's 4-scene version)
**Built 2026-10-19:** see [[Changelog/2026-10-19 Snipe cutscene rebuild]]. VFX added the same day: [[Changelog/2026-10-19 Snipe VFX]]. It is coded in
`Cutscene.snipe` for now, not baked; the rifle is a Blender prop.

| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0–1.8 **Load** | low at the bishop's left, pushing in | the bishop turns down the line; a sniper rifle drops into its hold; the bolt racks back, a shell spins out and bounces, the bolt goes forward; the bishop leans in | red burst as the rifle lands; a brass shell; letterbox, with the title in the bottom bar | bolt close, bolt open, shell drop, bolt close |
| 1.8–3.2 **Scope** | through the scope, from the eyepiece | zoom in on the first piece in the line; the sway settles | a scope overlay (vignette, crosshair, mil-dots, red dot, zoom readout) | scope zoom |
| 3.2–4.0 **Fire** | side-on to the rifle | the shot: the rifle kicks back with its muzzle climbing; the bishop rocks back | muzzle flash (core, spike, brake side blasts, light), smoke, a white impact frame, a strong shake | sniper shot |
| 4.0–6.0 **Hit** | rides beside the bullet (bullet-time), then a wide look down the line | each target bursts; **a king in the line** sidesteps it like Sans (a grey afterimage, "MISS" in a pixel font) and slides back | bullet trail, air ripples; per hit: a burst, splinters, dust, a short flash, a hitstop; at the king: afterimage + MISS | bullet hit per target; a dodge whoosh at the king |

### 2. Double Jump (knight): **built 2026-10-19, 8.5 s**, blue. See [[Changelog/2026-10-19 Double Jump cutscene]] (adds a horse rear-up and neigh, captured pieces launched, a spinning second leap). The plan below was the starting point.
| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0 | side, low | the knight crouches (squash) | `aura` blue; `title("DOUBLE JUMP")` | `sting` |
| 0.3 | follows it up | leap 1, a high arc | `afterimage` ×3; a blue trail | `whoosh` |
| 0.9 | at landing height | land 1 (a capture if any) | `impactFrame(flash)` if a capture; a `shockwave` blue; `smoke`; `debris` on a capture | `stomp` (+ `impact_light`, `shatter`) |
| 1.2 | whip-pan to the second target | the knight springs again at once | a blue speed-line overlay | `whoosh` |
| 1.8 | slow-mo dip (0.5× for 0.3 s) at the top of leap 2 | — | a sparkle trail | — |
| 2.2 | — | land 2 | a bigger `shockwave`, `crack`, `shake` 0.3 | `stomp` + `impact_heavy` |
| 2.4–3.0 | settle wide | dust settles | `smoke` | — |

### 3. Battering Ram (rook): **built 2026-10-19, 8.0 s**, orange. See [[Changelog/2026-10-19 Battering Ram cutscene]] (the built version adds a bull snort, pieces launched into the air and the king's flinch). The plan below was the starting point.
| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0 | low, in front of the rook, looking back at it | the rook rocks back twice (a wind-up) | `aura` orange; `charge` orange at its base; `title("BATTERING RAM")` | `sting`, `charge` |
| 0.9 | snap to behind the rook, low, along the charge line | **charge**: the rook accelerates | `afterimage` ×4; a dust trail under it; orange speed lines | a rising `whoosh` |
| 1.2–2.4 | tracks behind the rook | each enemy on the line: smashed and launched | per hit: `impactFrame(invert)` on the **first** hit only, `hitstop 0.08`, `shockwave` orange, `debris` big, `crack`, `shake` 0.4 | per hit `impact_heavy` + `shatter` |
| 2.4 | — | the rook skids to a stop in front of its own piece, the edge, or the enemy king | a skid dust spray; sparks at the base | a skid scrape |
| 2.6–3.4 | wide over the line | debris settles; the cracks stay a moment | `smoke`; the cracks fade | a low rumble tail |

### 4. ~~Swap (queen)~~: **removed 2026-10-20** (the ability was scrapped). The queen's next scene is the [[Design/Domain Expansion]] draft. The old plan is kept below for reference.
| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0 | between the two pieces, both in shot | both pieces glow | `aura` purple on both; `title("SWAP")` | `sting`, `magic` |
| 0.4 | slow orbit around the midpoint | both rise 1 stud and spin | a purple `beam` linking them, with a rune circle under each | a shimmer rising |
| 1.2 | — | **they swap**: each streaks to the other's square | `impactFrame(flash)` (soft); the pieces become light streaks (`afterimage`); `sparks` purple | `whoosh` ×2 crossing |
| 1.6 | — | both drop onto their new squares | `shockwave` purple at both; the runes fade | `impact_light` ×2 |
| 2.0–2.8 | settle | the glow fades | — | a shimmer tail |

### 5. Royal Escape (king): **built 2026-10-19, 7.5 s**, gold. See [[Changelog/2026-10-19 Royal Escape cutscene]] (adds red check lines, a pillar of light, a sigil with a beam from the sky, the king slamming down). The plan below was the starting point.
| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0 | close on the king (a "check" tension shot) | the king glows | `aura` gold; red danger lines from the checking piece (if in check); `title("ROYAL ESCAPE")` | `sting` |
| 0.4 | — | a gold column rises around the king | a column (a cylinder mesh with a scrolling texture) plus `charge` gold | `charge` |
| 1.0 | — | **vanish**: the king shrinks into light | `impactFrame(flash)`; a gold particle burst upwards | `teleport` (out) |
| 1.3 | quick cut to the target square, from above | a gold ring forms on the landing square | a ring and sigil on the floor | — |
| 1.7 | — | the king drops in (and takes the piece there, if any) | `shockwave` gold, `sparks`; on a capture `debris`, `shatter` | `teleport` (in) + `impact_light` / `impact_heavy` on a capture |
| 2.0–2.8 | settle, pull out | the gold motes fall | gold motes drifting down | a chime tail |

### 6. Any Passant (pawn): **built 2026-10-19, 7.5 s**, teal. See [[Changelog/2026-10-19 Any Passant cutscene]]. The user changed it to a **katana iaido**: a Blender katana and scabbard, a flash step, four cuts hanging round the frozen target, a slow sheathe, and the target splitting on the click. The plan below was the starting point.
| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0 | low, beside the pawn, looking at the piece that just landed | the pawn's eyes "lock on" (a glint) | `aura` teal; a glint sparkle on the pawn; `title("ANY PASSANT")` | `sting` |
| 0.5 | — | the pawn hops diagonally behind the target | a teal arc trail; `afterimage` ×2 | `whoosh` |
| 0.9 | — | as it passes, the target is struck from behind | `impactFrame(flash)`, `hitstop 0.06`, a teal `slash` across the target, `debris`, `sparks` | `impact_light` + `shatter` |
| 1.2 | — | the pawn lands | a small `shockwave`, `smoke` | `stomp` (light) |
| 1.5–2.4 | settle | — | the teal glow fades | — |

### 7. Steal a Piece (paid): **built 2026-10-19, 8.0 s**, gold + red. See [[Changelog/2026-10-19 Steal a Piece cutscene]]. Built as a heist: a red sigil, gold chains from the stealer's side, the yank, the old colour shattering off like glass, and a "STOLEN!" stamp. The plan below was the starting point.
| t | Cam | Action | VFX | SFX |
|---|---|---|---|---|
| 0.0 | low, looking up at the target piece | a giant red-and-gold magnet sigil appears above it | `title("STEAL!")`; the sigil fades in with a pulse | `sting`, `magnet` hum |
| 0.4 | slow push in | the piece lifts and spins, pulled by the sigil | a gold `beam` from the stealer's side; `charge` at the piece; sparks | the `magnet` hum rising |
| 1.3 | — | **the colour flips**: the piece flashes white | `impactFrame(invert)`; a `shockwave` gold+red ring; the old colour **shatters off** as shell `debris` (the piece stays) | `impact_heavy` + `magic` |
| 1.6 | — | the piece, in the stealer's colour, drops back onto its square | `shockwave` small; `smoke` | a clank |
| 2.0–2.8 | settle | — | gold motes; the sigil fades | a shimmer tail |

## Clock holds after the rebuild (proposed)
`Settings.CUTSCENES`:

| Ability | Hold |
|---|---|
| Snipe | 10.5 (built) |
| Double Jump | 8.5 (built) |
| Battering Ram | 8.0 (built) |
| ~~Swap~~ | removed |
| Domain Expansion | planned, about 9 s for the cast + about 2.5 s per jump |
| Royal Escape | 7.5 (built) |
| Any Passant | 7.5 (built) |
| Steal | 8.0 (built) |

These are 0.2–0.4 s longer than now, for the impact frames and settles.

## Order of work (when resumed)
1. **VfxKit**, with the meshes, textures and SFX ids. Test each effect alone on a table (a ChessDebug
   verb `vfx <name>`).
2. **The bake tool** (from `bake_v2.py`) and `CutscenePlayer`. Prove it with the shortest scene,
   Any Passant.
3. **The other six scenes,** one at a time in Blender, each with stills and a check:
   - both colours;
   - on any square or edge;
   - the bot using the ability;
   - the clock hold matching.
4. Phone check: the impact frames and screen effects must stay subtle and short.
5. Optional: open a bake in Eclipse through its Blender link to fine-tune by hand.

Back to [[Home]]
