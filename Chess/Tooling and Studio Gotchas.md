---
tags: [core, tooling]
---
# Tooling and Studio gotchas

## Scripts in this folder (copied from Descent Depths)
- `python push.py [prefix ...]`: pushes `src/` into the open Studio place. Rojo naming:
  `*.server.lua` → Script, `*.client.lua` → LocalScript, otherwise ModuleScript. The first folder
  under `src/` is the service (`src/ReplicatedStorage/Shared/...`). Stop Play mode first.
- `python tools/luau_check.py <files...>`: syntax-checks by compiling in Studio, with Studio in
  Edit mode. Pass file paths; with no arguments it checks nothing.

## Roblox Studio MCP (learned the hard way)
- **The `studio_id` changes between sessions.** Call `list_roblox_studios` first. Wait a few
  seconds after Studio opens before connecting.
- **`execute_luau` needs `datamodel_type`** (`Edit` / `Server` / `Client`) and runs in **its own
  Lua VM**. `require`-ing a game module there gives a fresh copy with none of the live game's
  state. Reach live state through instances: attributes, a BindableFunction debug hook in
  ServerStorage (only under `RunService:IsStudio()`), or remotes.
- **Playtests:**
  - Use `start_stop_play` with `is_start`.
  - `screen_capture` needs a `capture_id`.
  - The 3D viewport can go grey or black when Studio isn't the focused window; GUIs still draw.
  - `user_keyboard_input` presses don't always reach the game.
  - Test drivers that fire the game's own remotes (choose, advance) work reliably.
- **Script edits:** `luau_check` and `push` fail in Play mode. Stop the playtest first.
- **Moderation and ownership:**
  - A personal upload can't be loaded by a group game until the experience is given permission.
    A loaded AnimationTrack with `Length == 0` is the tell.
  - A moderation-rejected texture makes a whole SurfaceAppearance fail.
  - Check `get_console_output` after playtests.

## Running the engine tests
- **`require` is cached between `execute_luau` calls**, so after a push you get the old module.
  Require from a fresh clone:
  ```lua
  local c = game.ReplicatedStorage.Shared:Clone()
  local T = require(c.Tests.Perft)
  local ok, report = T.rules()  -- and T.perft(i) for i = 1..6; T.divide(i, depth) to debug
  c:Destroy()
  ```
- The full perft suite takes about 2 s in Edit mode. Put a `task.wait()` between positions.

## Captures and input in playtests (learned 2026-10-17)
- **`screen_capture` lags one request**: it shows the previous request's lighting or camera
  state. Capture twice and keep the second.
- Edit-mode captures with `camera_position` / `look_at_position` render the 3D view reliably.
  Client-only pieces don't exist in Edit mode, so `builders/preview_pieces.lua` places a sample
  position. Remove the `PiecePreview` folder afterwards.
- **`execute_luau` on the Client resets the camera to Custom** when it returns.
- **`user_mouse_input` x/y** are viewport coordinates minus the GuiInset (58 px here). Get them
  with `camera:WorldToViewportPoint(p)` and subtract the inset Y. `instance_path` targets
  buttons directly.
- **The user may be playing in the same playtest.** If moves appear that you didn't make, stop
  driving it.
- Run builders with `python tools/run_luau.py builders/<file>.lua`. Then run
  `builders/check_zfighting.lua`.

## Stills and sounds (learned 2026-10-20)
- **Edit-mode captures can come back black** while Studio isn't the focused window. Take stills in
  a playtest instead.
- **To hold a camera shot in a playtest,** run a Client `execute_luau` that starts a
  `task.spawn` loop. The loop sets `Camera.CameraType = Scriptable` and the CFrame every
  RenderStepped, reading it from a workspace attribute (e.g. `ShotCF`), for about 2 minutes.
  Change the attribute between captures. This gets round the reset to Custom that happens when
  `execute_luau` returns. Clear the attributes afterwards.
- **Finding sounds:** Studio MCP `search_asset` sometimes returns only models. Use
  `AssetService:SearchAudio` in an Edit `execute_luau` instead: an `AudioSearchParams` with
  `SearchKeyword`, `AudioSubType = SoundEffect` (that skips the music) and `MinDuration`.

## UI gotchas (learned 2026-10-20)
- A `UIPadding` on a button face also moves its overlay children (Sheen, Stripes). UiKit's
  `fitOverlays` counters it, so keep using `setText` / `Ui.checkbox` for padded faces.
- Don't clip with a CanvasGroup under a UIScale: Roblox drew it offset. Use a plain frame with
  `ClipsDescendants`.
- GUI inset has an X part on notched phones: subtract `GetGuiInset()` X and Y from
  `MouseButton1Down` coordinates.
- Settings toggles write the real `ChessPrefs_v1` from Studio, so put back anything a test flips.

## Desktop
- Windows. Bash (Git Bash) and PowerShell are both available.
- Write Python patch scripts to files: heredocs with `\u` or nested quotes break.
- Computer use: Studio may need a fresh `request_access` after a Studio update. Don't take over the
  mouse while the user is visibly using another app.
- A script's **Source is capped at 200,000 characters**: `push.py` fails on anything bigger. Split
  generated data (e.g. `PieceArtW` / `PieceArtB`, joined by `PieceArt.lua`).
- After Studio restarts, the MCP **studio id changes** and the connection can take a few seconds
  to come back. Call `list_roblox_studios` again before giving up.

- **Never put `AutomaticSize` on a card, and never rebuild GUI on `AbsoluteSize` changes.** The
  table panel grew without limit on the live client (not in Studio), and the checkerboard rebuilt
  endlessly and froze the game (2026-10-18). Give cards computed fixed sizes.

- **Image icons need EncodingService + EditableImage.** `Icons.lua` decodes zstd atlases (IconArt.lua, from art/ui/make_icon_data.py). Rerun the packer after any icon change. Published games need "Allow Mesh & Image APIs".

Back to [[Home]]

## Phones and the Studio emulator (2026-10-18)
- Test phone layouts with Studio's device emulator. In a playtest, `workspace.CurrentCamera.ViewportSize`
  reads the emulated size (e.g. 750×381) and `GuiService:GetGuiInset()` reads the 58 px top bar.
- In the emulator, scripted `user_mouse_input` clicks can stop landing (the mouse location stops
  updating). Open panels by script instead (set the ScreenGui `Enabled`, or build a test copy of
  a panel from its module).
- Roblox doesn't draw rotated GUI objects inside a `ClipsDescendants` frame. Don't clip, and keep
  rotated decoration inside the bounds.
- `rbxasset://textures/ui/common/robux@3x.png` (the Robux icon) ships with the client and can be
  used without uploading.

## Studio restarts lose pushes (2026-10-18)
- `push.py` writes the scripts into the open place but doesn't save it. If Studio restarts (the MCP
  `studio_id` changes), everything pushed since the last save is gone: run `python push.py` again.
- After toggling the device emulator, the 3D view sometimes captures black in a playtest while the
  GUI is fine. Restarting the playtest usually fixes it; check 3D motion by script meanwhile.
