---
tags: [changelog, lobby, leaderboards, tournament]
---
# Lobby makeover (2026-10-20)

**The user's brief:** "work on lobby first." This is Phase 4 of the next-round plan, with the
elements the user picked on 2026-10-18:
- a centrepiece;
- a tournament stage;
- a leaderboard wall;
- life and ambience.

## The layout
**Plaza:** 190 × 150 (it was 150 × 110), hedges round it, 16 trees on the lawn outside.

**Spawn:** at the south (+Z) entrance, facing north.

**Walking in from the spawn:**
- a warm stone path with flower beds either side;
- the two **leaderboards**, angled towards the spawn;
- then the **fountain**, with a giant king, between the two rows of tables;
- the **tournament stage** at the north end.

An east–west path runs between the table rows.

**Tables:** still 8, in a 4 × 2 grid, now at x = ±27 and ±63, z = ±24 (they were x = ±18 and ±54,
z = ±22). That opens a 39 × 24 gap in the middle for the fountain.

**Table contract:** unchanged (`Lobby.Tables.T1..T8`, seats, prompts, Persistent streaming).

## Builders
**`builders/build_room.lua`:** the wider plaza, hedges, trees and the spread-out tables.

**`builders/build_decor.lua` (new):** run it after build_room. It builds `workspace.Lobby.Decor`:

| Piece | What it is |
|---|---|
| **Paths** | South (spawn → fountain), North (fountain → stage), East/West, and a round plaza round the fountain |
| **Fountain** | A stone basin with a 32-block rim, glassy water, and a marble plinth with a gold band. **The Classic set's king, 8× life size** (about 18 studs), turned to face the spawn. Four arcing water jets, gold glints and a soft blue light |
| **Stage** | A 48 × 16 navy stage with gold trim and steps, and a backdrop wall. The **30 × 13 screen** sits in a gold frame. Two giant dark-marble Classic rooks stand on gold pedestals, with two warm spotlights and four audience benches in front |
| **Leaderboards** | Two 12 × 15 boards on posts at x = ±24, z = 56, turned to face the spawn. Most wins has a green crest; Champions has a gold one |
| **Flower beds** | Two stone beds along the spawn path |
| **Lamps** | 18 lamp posts (along the paths, round the fountain, round the plaza's edge) with warm neon bulbs and PointLights |
| **Flags** | 4 flag poles (the stage corners and the entrance) with green and white flags |

- **Persistent models:** Fountain, Stage and Flags, since the client code needs them from the
  start (streaming is on).
- **The contract** for the code is listed in the builder's header.
- **Size:** 211 parts. The whole workspace is 992 parts. `check_zfighting` reports **0 coplanar
  overlaps**.

## Code
**`ServerScriptService/Tables/LobbyBoards.lua` (new, written by a helper agent and reviewed):**
- The server draws both boards as SurfaceGuis: the title bar, then 10 rows (rank in medal
  colours, a headshot, the name and the count).
- It uses `Leaderboards.top`, refreshes every 60 s, and shows a friendly line when a board is
  empty.
- It's started from `TableService` in the lobby place only.

**`StarterPlayerScripts/Chess/StageScreen.lua` (new, helper agent, reviewed):**
- The stage's big screen is a client SurfaceGui (so its buttons work), fed by the same
  `Remotes.Tournament` state as the banner.
- What it shows:
  - no tournament: "TOURNAMENT STAGE" and how a VIP starts one;
  - open: the host, a live countdown, the player count and JOIN (or "You're in!");
  - live: a LIVE pill, the round and WATCH;
  - done: a crown and the champion;
  - cancelled: the reason.

**`StarterPlayerScripts/Chess/LobbyAmbience.lua` (new):**
- The flags sway round their poles.
- 6 birds circle high over the park, flapping in bursts.
- Two Creator Store loops, following the Settings sound switch:
  - **birdsong** everywhere: "Nature's Soft Chorus", 139786277679262;
  - **running water** at the fountain: 137086424700822, fading out by 45 studs.

**`ChessClient`:** starts LobbyAmbience, and creates StageScreen next to the tournament banner.

**Leaderboards (Phase 3):** the server code is now **pushed** into Chess?? (the client half went up
with the Swap push).

## Tested (Chess?? playtest)
- **The spawn view:** the path, beds and boards, with the king fountain and the stage behind. An
  aerial still shows the whole park.
- **Leaderboards:** `ChessDebug lbFake 12` (Studio `_studio` stores only) filled the Most wins board
  on the next refresh: Fake 8 with 114, and so on. The empty boards show "No wins yet. Be the first!"
  and "No champions yet".
- **Stage screen:** a test tournament (`tourneyStart` + `tourneyFake`) showed "kaydnn's
  tournament", a ticking 4:51 and "You're in! 3 / 16 players". It was cleared with `tourneyClear`
  before launching.
- **Sound:** both loops load (167 s and 150 s), the flags move, and the 6 birds fly.
- **Tables:** sitting at T6 (moved) and starting a game works, and the board and pieces draw at
  the new spot.
- **Console:** no errors (only Roblox's own UIBlox warnings).

**Fixed during testing:**
- the boards loomed over the spawn and covered the south tables, so they're moved out, back and
  made smaller;
- two lamps blocked the spawn view, so they're removed;
- the fountain's water sound and the flags missed parts that hadn't streamed in yet, so those
  models are Persistent now.

**Not checked yet:**
- by ear (volumes);
- a phone (frame rate and the spawn view in emulation);
- the Champions board with real data;
- the stage screen's live, done and cancelled states;
- the Tournament place: it needs `build_room` + `build_decor` and the pushes. The stage screen
  and boards stay off in a tournament server.

**Known limit:** Roblox caps text at 100 px, so the stage countdown is smaller than the code asks
for. It's still readable from the plaza.

**For the user:** save and publish Chess??.

Back to [[Home]]
