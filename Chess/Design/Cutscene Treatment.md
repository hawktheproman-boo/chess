---
tags: [design, cutscenes, vfx, sfx, howto]
---
# The cutscene treatment: how to build an ability cutscene

This is the recipe behind the six rebuilt cutscenes (Snipe, Battering Ram, Double Jump, Royal
Escape, Any Passant, Steal a Piece, 2026-10-19). The user calls it **"the Snipe treatment"**: anime
VFX, impact frames, dramatic sound, readable pacing. Follow it for any new ability (next up: the
queen's [[Design/Domain Expansion]]).

> **What we really did vs the plan.** [[Design/Cutscene Storyboards]] planned Blender bakes and a
> `CutscenePlayer`. That was **not** used. Every scene is **hand-coded Luau** in
> `src/StarterPlayer/StarterPlayerScripts/Chess/Cutscene.lua`, built on `VfxKit.lua` and
> `Sounds.lua`. Blender is used only for **props** (the rifle, the katana).

## 1. Before you write code
1. **Read the ability's rules** in [[Design/Abilities Mode]] and what `info` the server sends (the
   comment above `TITLES` in `Cutscene.lua`: captured squares, paths and so on).
2. **Pick a fantasy.** Every scene is one idea a player gets at a glance:
   - Snipe: a sniper;
   - Ram: a bull charge;
   - Double Jump: a rearing horse;
   - Royal Escape: a summoning sigil;
   - Any Passant: a samurai iaido;
   - Steal: a heist with chains.

   The user liked bold, specific themes, and asked for a katana when the first Passant was generic.
   Ask the user if the fantasy isn't obvious.
3. **Pick the colour** from the ability's card accent in `AbilityBar.CARDS`, plus white-hot
   (`WHITE_HOT`) for the hottest moments. Keep one or two colours per scene.
4. **Write the storyboard** in [[Design/Cutscene Storyboards]] as a table of beats (time, picture,
   sound), and get the user's OK when they're around.

## 2. The beat structure (every scene uses it)
| Beat | Length | What it does |
|---|---|---|
| **Wind-up / tension** | about 2.0–2.8 s | A slow push-in on the actor, low angle. Something **builds**: a charge, a sigil drawing itself, a blade an inch out, a red "?" or "!?" over the unaware target. A `braam` hit, and a `riser` **timed to cut dead on the hit**: start it at `timePosition = 4.0 - HIT_AT`. |
| **The hit** | instant, then hitstop | The action fires. An **impact-frame burst** (`VfxKit.impactFrames`), a shockwave, sparks, speed lines, a camera shake, and a stacked hit sound (`trailerHit` / `impactBoom` + the ability's own). |
| **Payoff** | about 1.5–3 s | The consequence, shown clearly: pieces launched or split apart with debris, the piece landing, a stamp ("STOLEN!", "MISS"). Captures happen **here**, through the scene's own effects. The board redraws when `done()` runs. |
| **Settle** | to the end | A slower, wider shot, motes or embers drifting, a soft tail sound (`twinkle`, `rumble`), and the props fade. This gives the eye a rest before control returns. |

- **Length:** 7.5–10.5 s in total, set in `Settings.CUTSCENES[id]`. That number is also how long
  the server holds the opponent's clock. `Cutscene.ability` waits out whatever the scene doesn't
  use, so a scene may finish early but must never run long.
- **Pacing rule from the user:** slow enough to read. Hold on the key picture (the scope, the
  hanging cuts, the chains) for at least about 0.6 s before the hit.

## 3. Anatomy of a scene
```lua
-- <Ability> -------------------------------------------------------------------------------------
-- one paragraph: the fantasy and the beats. About N s (Settings.CUTSCENES.<Id>).
local MY_COLOR = Color3.fromRGB(...)
local MY_HIT = 2.6 -- seconds from the start to the hit (the riser ends here)

scenes.<Id> = function(view, action, info, opts, folder)
	local cam, gui = opts.camera, opts.gui -- cam: this viewer is a seated player (camera + overlays)
	local function snd(name, pos, o)
		return Sounds.play(name, if cam then nil else pos, o) -- 2D for players, 3D for onlookers
	end
	local e = view:modelAt(action.from)
	if not (e and e.model.Parent) then task.wait(1) return end -- always guard
	if cam then hideLocal(Players.LocalPlayer.Character, true); VfxKit.bloom(true) end
	-- ... beats, each with a banner comment: -- THE MARK ------- ...
	-- at the end: put back anything you hid, and turn off the bloom
end
```
- **Everything you create goes in `folder`.** It's destroyed when the scene ends.
  `fadeAndDestroy` handles anything that should vanish sooner.
- **Only seated players** (`opts.camera`) get the camera, the overlays (impact frames, speed lines,
  pops) and 2D sound. Onlookers just see the world effects.
- **Don't move the real models in a lasting way.** Animate them, then let the board resync. For a
  piece that changes (Steal), build a copy with `Pieces.build(type, color)` and `hideLocal` the
  original.
- **`pcall` protects the scene.** An error shows as `[Cutscene] <id>: ...` in the client output.
  Check the output after every test.

## 4. The toolbox
**In `Cutscene.lua`:**

| Group | Helpers |
|---|---|
| Timing | `animate(duration, step)` (a frame loop with a = 0..1), `ease(a)` |
| Parts | `fx(parent, shape, size, cf, color, transparency)`, `fadeAndDestroy(p, t)` |
| Models | `partsOf(model)`, `fade(base, a)`, `hideLocal(model, on)`, `firstColor(model)` |
| Effects | `ring`, `burst`, `puff(folder, pos, n, color, size, speed, life)`, `debris(folder, pos, n, color, size, speed, neon, avoid)` |
| Capture | `launchCopy(folder, model, push)` (fling a captured piece), `splitApart(folder, model, n, back)` (cut in half), `afterimage(folder, model, color, life)` |
| Geometry | `across(pos, dir)` (a ring standing across a direction), `attackersOf(view, sq, color)` |
| Magic | `sigil(folder, pos, texture, color, size)` → `{ part, set(scale, angle, transparency) }`, `motes(folder, pos, color, life)` |
| Text | `popMark(folder, pos, text, color)` → remove (a small "?" / "!?"), `stamp(folder, pos, text, color, stroke)` → `fadeOut(t)` (a big word slammed in) |
| Props | `chain(folder, color)` → `{ set(a, b, shown), fade(t) }`, `makeKatana`, `bladeFrame`, `slashMark`, `makeRifle` |

**`VfxKit.lua`** (the header lists every signature):
- `shockwave`, `decal` (cracks), `flare` (a camera-facing glow or star), `sparks`;
- `charge` → stop, `beam` → `:set` / `:fade`, `aura(model, color)` → remove;
- `impactFrames(gui, models, pattern, dt)`, with patterns `"white"`, `"invert"`, `"manga"`, `"red"`;
- `speedLines(gui, time, color)`, `bloom(on)`.

The textures are in `VfxKit.T`: glow, spark, star, ring, speedlines, crack, energy, slash, smoke.

**Impact-frame patterns that worked:**
- `{ "white", "invert", "manga" }` on the main hit;
- `{ "invert", "manga", "invert", "red" }` on the big finisher.

Pass the models that should show as silhouettes (`view.models`, plus any props).

**Camera:** `CameraRig.override(cframe, fov, tweenTime?)`. To glide from A to B, set A, then
`task.delay(0.05, ...)` override to B with a tween time.

## 5. Camera rules (each one learned from a bad frame)
- **Frame from the board's side, never from off the board or from under it.** For landing shots,
  aim inward from the board centre (`view:squareCFrame(0)` and `view:squareCFrame(119)`).
- **Look at the piece's upper body** (`pos + UP * h * 0.45..0.85`), not its base.
- **Low and close for tension** (about 2.8–3.6 studs out, about 0.5 up). **Pull wide for the
  settle.**
- **Keep text in frame:** the "STOLEN!" stamp was cut off until the shot pulled back.
- **Close-ups need room.** The katana-guard close-up was too tight at first.
- **Flight shots** (Double Jump) track the midpoint and rise with the piece. Otherwise the scene
  looks "cut off".
- **Thin effects disappear on screen:** threat lines need a width of at least about 0.24, and beams
  read as wisps. When something should look solid (chains), use real parts.
- **Don't wash out the actor.** A pillar or column needs transparency of about 0.82 or more.

## 6. Sound
- **The stack:** `braam` (the opening hit) → `riser` (to the hit) → the ability's sounds →
  `trailerHit` / `impactBoom` / `lowBoom` on the hit → a tail (`rumble`, `twinkle`, `choir`).
- **`Sounds.play(name, pos, opts)` options:** `volume`, `speed`, `timePosition`, and
  `fadeAfter` + `fadeTime`.
- **To add a sound:**
  1. Search with Studio MCP `search_asset` (Creator Store, audio). If it only returns models, use
     `AssetService:SearchAudio` (see [[Tooling and Studio Gotchas]]).
  2. Check it loads in a Client `execute_luau`: `ContentProvider:PreloadAsync` and then
     `TimeLength > 0`.
  3. Add a key to the templates table in `Sounds.lua` (`id`, `volume`, `speed`, plus the `reverb`
     or `bass` flags).
  4. Note it in the changelog's "New sounds" table.
- **Nobody has heard them yet.** Nothing has been checked by ear, so say so in the changelog.

## 7. Props from Blender
1. Model it with a script in `art/props/make_<prop>.py` (see `make_katana.py`): units in studs,
   the front along -Y, the **origin at the grip or pivot**, and one mesh object per colour or
   material.
2. Export FBX (`axis_forward="-Z"`, `axis_up="Y"`) and render a preview PNG next to it.
3. Import with Studio's **3D Importer** (computer use, which uploads to The Depths Studio).
4. Read each MeshPart's `MeshId` and offset from `workspace.<Name>`.
5. Add the prop to `builders/cutscene_props.lua` with its `build(name, list)` helper. This creates
   `ReplicatedStorage.CutsceneProps.<Name>` with `CreateMeshPartAsync`.
6. Run the builder in **each place**. The Tournament place still needs this.
7. Always code a **part-built fallback** for when `CutsceneProps` is missing.

## 8. Testing in Studio (place Chess??)
1. **Stop play**, then `python push.py StarterPlayer/StarterPlayerScripts/Chess` (and
   `ReplicatedStorage/Shared` if Settings changed), and
   `python tools/luau_check.py <files>`. Both need Edit mode.
2. **Start play.** On the **Client**, after `task.wait(5)`, seat the real player:
   `game.ReplicatedStorage:FindFirstChild("Remotes",true).Lobby:InvokeServer("sit","T1","w")`.
3. On the **Server**, with `D = game.ServerStorage.ChessDebug`:
   ```lua
   D:Invoke("sit", "T1", 999001, "b", "Rival")            -- a fake opponent
   D:Invoke("configure", "T1", uid, { mode = "Abilities", clock = "none" })
   D:Invoke("start", "T1", uid, "<FEN with spare pawns>")  -- K v K is a dead draw: abilities refuse
   task.delay(4, function()
       D:Invoke("action", "T1", uid, { kind = "ability", id = "<Id>", from = sq, to = sq })
   end)
   ```
   - Squares are 0x88: `rank * 16 + file`.
   - Run `D:Invoke("reset", "T1")` and re-sit between runs: `start` fails while a game is going.
   - Steal needs a grant first: `D:Invoke("wallet", uid, nil, nil, 1)`. That's a session-only
     sandbox; **never touch real wallets or stats**.
4. **Capture frames:** fire the action with the 4 s delay, then immediately run one
   `computer_batch` of `zoom` captures on the viewport region ([120, 216, 1322, 772] on this
   screen), with waits between them. Separate tool calls lag by seconds and miss beats.
5. **To study impact frames**, set `workspace:SetAttribute("ImpactFrameHold", 0.6)` on the
   Client. **Remove it afterwards.**
6. **Check after each run:**
   - the client output has no `[Cutscene]` warnings;
   - no `ImpactFrame` ColorCorrection or `CutsceneBloom` is left in Lighting;
   - the board resynced (the right pieces on the right squares).
7. **Not yet covered anywhere:** black's side, 2D mode (2D hides during a scene), a phone, and the
   bot using the ability. Test them when you can, and list what you didn't test.

## 9. Finish
- Remove the old hand-coded scene, and update `TITLES` if the title changes.
- Set `Settings.CUTSCENES.<Id>`.
- Write `Changelog/YYYY-MM-DD <Ability> cutscene.md`, using the earlier ones as the template:
  - the beats table;
  - new sounds;
  - the test position;
  - what was checked in stills;
  - what was fixed;
  - what's not checked yet.
- Link the changelog in [[Home]], mark the storyboard section built in
  [[Design/Cutscene Storyboards]], and update [[Current State]].
- **The Tournament place** needs the same push, plus `builders/cutscene_props.lua` if props
  changed.

Back to [[Home]]
