---
tags: [changelog]
---
# Phase 4: room, board, input, HUD (2026-10-17)

## Built
- **`builders/build_room.lua`** builds `workspace.Lobby`. Run it with
  `python tools/run_luau.py builders/build_room.lua`; it's re-runnable and replaces the old build.
  - **The look:** an evening chess club. Walnut plank floor, deep green plaster walls with wood
    wainscot, burgundy rugs, brass hanging lamps and wall sconces.
  - **6 tables, T1–T6, each a Persistent model.** A table has:
    - 64 square parts, each with a `Square` attribute (0x88 index), White at +Z;
    - a frame, and two `Seat` chairs with `SitPrompt` ProximityPrompts (E / ButtonX / tap);
    - a lamp with a spot and a fill light.
  - The default Baseplate and SpawnLocation are removed. Lighting is tuned: ambient, exposure
    0.15, bloom eased, no depth of field or sun rays.
  - **The z-fighting check** (`builders/check_zfighting.lua`, adapted from Descent Depths) finds
    0 coplanar overlaps in 541 block parts.
- **`tools/run_luau.py <file> [Edit|Server|Client]`** runs any Luau file in Studio and prints
  what it returns.
- **Server `Tables/Seating`:**
  - chair prompts sit you down, and the Seat parts follow the logical seats;
  - walking into a chair doesn't seat you, and jumping out puts you back;
  - you can't switch tables mid-game;
  - prompts hide on taken seats and during games.
- **The client** is in `StarterPlayerScripts/Chess/`:
  - `Pieces`: piece models built from primitive parts (ivory and ebony, with brass rings), so no
    uploads are needed yet. Stacked parts are embedded, never coplanar;
  - `BoardView`: per table, it renders and diffs pieces by engine piece id, so castling, en
    passant, promotion and future abilities all animate the same way. It handles the move arc and
    capture fade, plus the marks: last-move tint, check tint, legal dots, capture squares, the
    selection box and the controller cursor box. All marks float above the squares;
  - `CameraRig`: the seated camera, top-down or tilted (T / LB / button):
    - it fits the board to the window;
    - it stays under the ceiling, widening the field of view if it has to;
    - it re-asserts itself every frame;
    - it hides your own table's lamp for you only;
  - `Hud`: everything is a real button, so mouse, touch and pad all work:
    - player bars with clocks (red under 20 s), a turn outline and material +N;
    - the move list (hidden on narrow screens);
    - Offer draw, Resign (with a confirm), Tilt, Auto-queen, Leave;
    - the table panel: Clock preset cycle, Play the bot plus a level cycle, Ready, Leave;
    - the result banner (Rematch / New game, Leave) and the draw-offer banner;
    - the promotion picker, toasts, and device hints;
  - `Device`: mouse / touch / pad detection;
  - `ChessClient`:
    - mirrors every table from `State`: replays snapshots, checks the FEN after each action, and
      resyncs on seq gaps;
    - shows floating signs over the tables;
    - while you're seated, it locks jumping and hides prompts;
    - input: click-click, drag-and-drop, touch tap/drag, right-click cancel, and a controller
      cursor (D-pad / stick, A pick/drop, B back, Y menu, LB tilt).

## Verified in a playtest
- Sitting by Lobby invoke puts you in the WhiteSeat with jumping off, the board camera on, and
  the panel showing.
- The panel's "Play the bot" and "Ready" buttons, clicked with the real mouse, start the game.
- **Real mouse clicks:** clicking e2 then e4 played e4. A drag from g1 to f3 played Nf3. The bot
  replied each time.
- Selecting a piece shows the dots, the capture square and the selection box. The last move and
  the clocks update.
- The Resign button opens the confirm dialog. The tilt button switches the view.
- The user then played a game against the Strong bot themselves in the same playtest. I stopped
  driving it at that point.

## Bugs found and fixed on the way
- **Instance streaming** had left far tables' squares off the client, so `BoardView` crashed.
  Table models are now Persistent, and the client waits for 64 squares.
- **No `PlayerModule`** in this place: jumping is locked through Humanoid state instead.
- **The lamp was blocking the top-down camera.** Lamps went up to y = 22.2, and your own lamp is
  hidden locally.
- **The camera** rose through the ceiling on squarish windows. It's now capped, and the field of
  view widens instead.
- **`Hud`:** the `confirm` Frame field shadowed the `confirm()` method. Renamed to
  `confirmFrame`.

## Studio MCP lessons (also in [[Tooling and Studio Gotchas]])
- `screen_capture` returns the frame from the *previous* request's lighting state, so capture
  twice. In Play mode the 3D view goes grey when Studio isn't focused; GUIs still draw.
- `execute_luau` on the Client resets `CameraType` to Custom afterwards. That's why the rig
  re-asserts itself every frame.
- `user_mouse_input` coordinates are inset-adjusted screen space: viewport Y minus the GuiInset,
  58 px. `instance_path` works for buttons.

## Not done or not verified
- **Controller and touch** haven't been tested on real devices. The code paths exist; check them
  with Studio's device emulator or a real pad.
- ✅ (done 2026-10-17, [[Changelog/2026-10-17 Lobby polish]]) **Not seen in a still:** the result banner, the promotion picker, and the draw-offer banner.
- ✅ (done 2026-10-17, [[Changelog/2026-10-17 Bright restyle and 2D board]]; later sized from its rows, see [[Changelog/2026-10-18 Live freeze fix]]) The table panel has empty space at the top and bottom; it should be auto-sized.
- The piece models are placeholders made from primitives. Group-owned meshes come later.

Stills are in `chess/stills/2026-10-17-*.jpg`.

Back to [[Home]]
