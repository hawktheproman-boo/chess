---
tags: [core, plan]
---
# Build plan (approved 2026-10-17)

## Context
The vault at `C:\Users\liter\Documents\CLAUDE\chess\Chess\` is the brief: a Roblox chess game
with a **Classic** mode and an **Abilities** mode, where more modes may follow. Nothing is built
yet. `src/` doesn't exist, and the ability table is empty. `push.py` and `tools/luau_check.py`
are ready to use.

Decisions confirmed with the user (2026-10-17):
- It's a **new experience** owned by The Depths Studio. The user opens it in Studio and gives us
  the place ID.
- The board is **3D, in a lobby room with tables**. The camera is top-down with a tilt option.
- **PvP and a bot** are both in the launch scope.
- **Abilities come later.** We build the system plus one test ability, and the user gives the real
  abilities when that phase starts. We don't invent any.

Standing rules still apply:
- controller and touch support for everything;
- no z-fighting;
- no pirated plugins;
- assets go under the group;
- send small stills for review;
- keep tool calls lean.

Vault housekeeping:
- `CLAUDE.md` says `vault/`, but the vault is actually at `Chess/`. Fix the paths in `CLAUDE.md`.
- Update the chess memory's vault path too.

## File layout (`src/`, Rojo naming for push.py)
```
src/ReplicatedStorage/Shared/Chess/   Board, Moves, Game, Notation, Attacks   (pure, no services)
src/ReplicatedStorage/Shared/Modes/    Classic, Abilities                     (settings + hooks)
src/ReplicatedStorage/Shared/Abilities/ <Name>                               (one module each)
src/ReplicatedStorage/Shared/Bot/      Search                                 (pure)
src/ReplicatedStorage/Shared/Tests/    Perft, AbilityTests                    (run via execute_luau)
src/ServerScriptService/Tables/        TableService.server, Clock, Results    (authority)
src/ServerScriptService/Lobby/         Lobby.server, Stats (DataStore)
src/StarterPlayer/StarterPlayerScripts/Board/  BoardView, Input, Highlights, Camera, Hud
src/ReplicatedFirst/Input.lua          device detection + glyphs (adapted from Descent Depths)
```
Remotes live in `ReplicatedStorage/Remotes`:
- `RequestAction(tableId, action)`
- `State(tableId, seq, snapshot|action)`
- `Result`
- `Lobby` (sit/leave/choose mode+clock)

## Phases

### 1. Rules engine: Classic (pure Luau)
- `Board`: a 0x88 or 10×12 mailbox. Each piece is `{type, color, id, moved, data={}}`.
- `Moves`: pseudo-legal moves per piece, then a legality filter (apply → is the king attacked? →
  undo). Covers castling through attacked squares, en passant with the horizontal-pin case, and
  promotion to Q/R/B/N.
- `Game`:
  - an action-based `apply(action)` / `undo()`, where an action is
    `{kind="move"|"ability", ...}`;
  - turn, castling rights, the en passant square, the halfmove clock, Zobrist-style repetition
    keys, and the result;
  - the end detection set: mate, stalemate, threefold, the 50-move rule, insufficient material.
- `Notation`: FEN in/out, plus SAN (disambiguation, `+`/`#`, `=Q`, O-O).
- **Gate:** perft must match before moving on:
  - start position, depth 1–4 (20 / 400 / 8,902 / 197,281);
  - Kiwipete, depth 1–3 (48 / 2,039 / 97,862);
  - CPW positions 3–6.

  Re-check the numbers against the CPW page. If one is off, use perft-divide. Run it all through
  `execute_luau` (Edit), since these are pure modules and the VM caveat doesn't matter.

### 2. Server tables (authority)
- A `TableService` holds a `Game` per table:
  - it validates `RequestAction` with the shared engine (never trust the client);
  - it applies the action, bumps `seq`, and broadcasts the action;
  - on a seq gap, the client asks for a full snapshot (FEN plus ability state).
- Server clocks with increment, using the presets none / 10+0 / 5+3 / 3+2. Timeout against
  insufficient material is a draw.
- Resign, draw offer/accept, and disconnect grace (e.g. 60 s, then forfeit).
- A results hook writes per-mode W/L/D to a DataStore from day one.
- A Studio-only `BindableFunction` debug hook in ServerStorage, for test drivers.

### 3. Bot (launch scope)
- `Shared/Bot/Search` is a pure module:
  - alpha-beta with iterative deepening and a time budget;
  - material plus piece-square tables, and MVV-LVA move ordering;
  - quiescence on captures;
  - difficulty levels set by depth/time and a random top-N pick.
- Run it server-side as a "player" in a table slot. Yield between iterations (task.wait) so it
  doesn't hitch the server.
- The bot generates **ability actions alongside moves** through the same action list, so it works
  automatically once abilities land.

### 4. Board, room and input (client)
- **Room:** a lobby room with several tables. Each table has a board of separate, non-overlapping
  square parts and a raised border with no coplanar faces. Seats use ProximityPrompts, which work
  on every device.
- **Pieces:**
  - anchored models, moved by tween from the replicated state, never by physics;
  - placeholder Roblox-made meshes first, then group-owned assets.
  - Run `builders/check_zfighting`-style checks, as on Descent Depths.
- **Camera:** when seated, a top-down view oriented to your colour, with a tilt toggle.
- **Input:**
  - mouse: click-click or drag, right-click to cancel;
  - touch: tap-tap, with full-square hit areas;
  - controller: a board cursor on the stick/d-pad, A pick/drop, B cancel, a shoulder button for
    the ability bar;
  - glyphs per device, from the adapted `Input.lua`.
- **Feedback:**
  - legal-move dots and capture rings, the last-move tint and the check tint, all raised slightly
    or done with Highlights;
  - a promotion picker (queen pre-pick option) and in-UI confirms for resign and draw;
  - a SAN move list, clocks, captured pieces, and the mode label.
- Send small stills to the user for the look before polishing.

### 5. Lobby flow
- Sit at a table and pick the mode (Classic/Abilities), the clock, and the opponent (player or
  bot + difficulty).
- Stand up, rematch, swap colours.
- Everything is controller/touch navigable (GuiService selection).

### 6. Abilities system
- Fill the `Modes/Abilities` hooks:
  - setup assigns abilities;
  - `modifyMoves` runs during generation;
  - `onTurnStart` ticks cooldowns;
  - `onMove`/`onCapture` fire after apply.
- An ability module follows the shape in `Design/Abilities Mode.md` (`id, owner, pieces, use,
  cost, targets, apply, hooks`). `apply` records the changes so `undo` works.
- Rules:
  - the same legality filter applies to ability actions (a default: an action can't leave your own
    king in check);
  - mate/stalemate counts ability actions;
  - ability state is serialised with the FEN for snapshots and replays.
- UI:
  - an ability bar with cooldown/charge counters;
  - a targeting mode with highlighted targets, confirm/cancel on every device;
  - the move list shows the ability.
- Prove the plumbing (undo, legality, networking, bot, UI) with **one throwaway test ability**,
  e.g. "swap two own adjacent pieces, cooldown 3". It gets removed or hidden before release.
- **Then stop and ask the user for the real abilities.** Fill one table row per ability and confirm
  the open rules (who, use type, cost, targets, check interaction, visuals), along with Open
  Questions #4–5. Implement them one at a time, each with a FEN-plus-state test.

### 7. Polish
- Sounds and move/capture animations, all group-owned.
- A stats display; spectators and ranked play are later.
- Update the vault:
  - a changelog per session;
  - Current State and Next Steps;
  - tick the Classic checklist.

## Verification
- **Engine:** the perft suite and SAN/FEN round-trip tests via `execute_luau`. This gate must pass
  before phase 4.
- **Server:** a Studio playtest test driver fires `RequestAction` with illegal moves (expect
  rejects) and with legal sequences:
  - Scholar's mate gives a result;
  - stalemate, threefold and the 50-move rule end correctly;
  - an en passant pin is refused.
- **Bot:** bot vs bot to completion at each difficulty, with no errors in `get_console_output`,
  and it doesn't hang the server.
- **Client:** playtest `screen_capture` stills of the board, highlights, promotion picker and HUD.
  Check controller and touch paths with the device emulator.
- **Abilities:** the test ability's apply → undo restores the exact state, an illegal ability
  (exposing the king) is rejected, and the bot uses it.
- After every session, check `get_console_output` and log the work in the vault.

## First step once approved
The user creates the new experience under The Depths Studio, opens it in Studio, and shares the
place ID. In the meantime, phase 1 (the pure engine plus perft) can be written and checked.

Back to [[Home]]
