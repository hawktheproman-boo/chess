---
tags: [changelog, cutscenes, snipe, sfx, blender]
---
# Bishop Snipe cutscene, rebuilt in four scenes (2026-10-19)

**The user's brief:** Snipe is the rarest and most expensive ability, so its cutscene comes first, with
sound effects taken from the web:
1. The bishop loads a sniper rifle and aims at the target.
2. The scope view zooms in to the target.
3. The bullet fires and the sniper recoils.
4. The target is shot. If there's a king in the line, the bullet ricochets off it and hits the
   target behind.

The user gave two references: a soldier aiming a bolt-action sniper on a bipod, and a Barrett firing
with a muzzle flash. The rules are unchanged: the enemy king is still skipped, and the ricochet is
only visual.

## The rifle (Blender)
- **Source:** `art/props/make_rifle.py`, which reuses the helpers from `make_sets.py`.
  - A bolt-action sniper: a wooden stock with a pistol grip and cheek rest, a heavy barrel with a
    muzzle brake, a scope with turrets and rings, a magazine, a trigger guard, and a bipod.
  - It has 4 meshes, about 1.9k triangles in total: Stock, Metal, Bolt (moves for the reload), and
    Lens.
  - Outputs: `Sniper.fbx` and `Sniper_preview.png`.
- **Import:** through the 3D Importer, uploaded to The Depths Studio.
  - `builders/cutscene_props.lua` builds `ReplicatedStorage.CutsceneProps.Sniper` from the asset
    ids. It is a Model with an invisible Root at the rifle's origin (the bore axis, above the
    trigger), with the muzzle facing -Z.
  - **Built in Chess?? only.** The builder still has to be run in the Tournament place. Without the
    prop, the cutscene uses a plain stand-in rifle made of Parts.

## The cutscene (`Cutscene.snipe`, `Cutscene.lua`)
**Length:** `Settings.CUTSCENES.BishopSnipe` and `SNIPE_CUTSCENE` are now **6.0 s** (were 3.4 s). The
server holds the opponent's clock for that long.

| Scene | Time | What happens | Sound |
|---|---|---|---|
| 1 Load | 0–1.8 s | Letterbox, with the "BISHOP SNIPE" title in the bottom bar. A low camera at the bishop's left pushes in. The bishop turns down the line, and the rifle drops into its hold with a red burst. The bolt racks back, a brass shell spins out and bounces on the board, then the bolt goes forward. The bishop leans into the aim. | `boltClose`, `boltOpen`, `shellDrop`, `boltClose` |
| 2 Scope | 1.8–3.2 s | Through the scope (a round view, crosshair with mil-dots, red centre dot, a live zoom readout). The view zooms in on the first piece in the line while the sway settles. The rifle and the bishop are hidden for this shot. | `scopeZoom` |
| 3 Fire | 3.2–4.0 s | Side-on to the rifle. Muzzle flash (a hot core, a flash spike, side blasts from the brake, a PointLight, smoke), a white impact frame, and a strong shake. The rifle kicks back with its muzzle climbing, and the bishop rocks back. | `sniperShot` |
| 4 Hit | 4.0–6.0 s | The camera rides beside the bullet in bullet-time, with a glowing trail and air ripples. Each target bursts into splinters of its own colour and pops off the board, with a short flash and a hitstop. **A king in the line:** the bullet strikes it, sparks fly, the king wobbles, and the bullet arcs over it to the targets behind. It ends on a wide look down the line, then the rifle fades out and the bishop turns back. | `bulletHit` for each target, `ricochet` at the king |

- **Seated players** get the camera and the screen overlay; their own avatar is hidden for the
  close shots. **Spectators** nearby see the rifle, the shot, the bullet and the hits.

## Sounds (free Creator Store audio, in `Sounds.lua`)

| Key | Asset | Creator |
|---|---|---|
| `sniperShot` | 98063753863205 "Sniper Rifle Single Shot 1" | CBE_Simon |
| `boltOpen` | 122612995190489 "SPX-80 Bolt Open" | Jilusions |
| `boltClose` | 99816337580692 "Intervention BoltFowardAndDown" | Jilusions |
| `shellDrop` | 9113631067 "Bullet Drops 4" | Pro Sound Effects |
| `scopeZoom` | 18772934574 "Sniper scope zoom in" | Gonee_e |
| `ricochet` | 7842386350 "Bullet Ricochet 2" | DuncanDunclub |
| `bulletHit` | 100725736694571 "wood_solid_impact_bullet3" | daon2000 |

All 7 load in a playtest. They haven't been heard by ear yet, so the volumes are guesses.

## Tested (Studio playtest, ChessDebug, a bot opponent)
- **Position** `8/8/7q/6r1/5k2/4n3/8/K1B5 w`, then Bc1 snipes NE:
  - the knight on e3 is hit;
  - the bullet ricochets over the king on f4;
  - the rook on g5 and the queen on h6 are hit.
- All 4 scenes play in order. The three pieces are removed, the board syncs afterwards, and there are
  no script errors.
- Fixes made during testing:
  - the bishop's head blocked the scope view;
  - the player's own avatar filled the low shots;
  - the scope zoomed out on a target next to the bishop.
- The move to the bottom bar (the title was half-hidden behind Roblox's top-left buttons) wasn't
  re-checked by eye.

**Not checked yet:**
- the sound by ear;
- a phone-sized screen;
- the Toon and Simple piece sets;
- a black bishop (the camera maths uses the line's direction, so it should hold);
- the bot sniping live;
- the Tournament place: push `Cutscene`, `Sounds` and `Settings` there and run
  `builders/cutscene_props.lua`.

The storyboard is in [[Design/Cutscene Storyboards]] (Snipe section). Back to [[Home]]
