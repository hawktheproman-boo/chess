---
tags: [changelog, tournament]
---
# Tournaments (2026-10-18)

The user asked for tournaments: a global announcement 5 minutes before one starts, 8–16 players,
played in a separate place (Create/Save Place API), open to spectators, with the day's top games
and the 1st-place game logged.

**The user then chose:**
- one created place, made from a **separate template place** with copying on (so the lobby stays
  copy-locked);
- **VIP starts, anyone joins**;
- **knockout**;
- draws: **a rematch with colours swapped, then Armageddon**.

The rules, the defaults and the full design are in [[Design/Tournament]].

## New
**Shared**
- `Shared/Tournament.lua`: the constants, plus the bracket (`newBracket`, `current`, `nextGame`,
  `report`, `markAbsent`, `roundName`, `matchOf`). It's pure and serialisable. A subagent wrote
  it, and it was reviewed.
- `Shared/Tests/TournamentTests.lua`: 10 cases.

**Server (`ServerScriptService/Tournament/`)**
- `Registry`: MemoryStore + Messaging.
- `Launcher`: the lobby side; countdown, launch, CreatePlaceAsync, ReserveServer, teleports, Watch.
- `Runner`: the tournament server.
- `DailyLog`: server-side reviews into `ChessDaily_v1`.

**Client**
- `TournamentBanner`: the global announcement.
- `TournamentPanel`: the lobby card, with a Today's games tab.
- `BracketPanel`: the tournament server's bracket, with Watch and Back to lobby.

## Changed
- **`ChessTable`:**
  - `runMatch` / `release` and `owner` (the runner owns the table);
  - `clockOverride` (per-side times);
  - `noAbort` (resigning or leaving early is a loss);
  - `firstMoveLimit` (30 s, or you lose);
  - no Steal in tournament games;
  - snapshots carry `tournament`, which hides the Steal button.
- **`Clock.new(base, inc, blackBase?)`:** Black can have its own time (Armageddon).
- **`TableService`:**
  - the roles (`TournamentServer` attribute; `START_PLACE_ID`), `Remotes.Tournament`;
  - the verbs `tourney`, `tourneyStart` (VIP), `tourneyJoin`, `tourneyLeave`, `tourneyWatch`,
    `today` and `todayGame`;
  - tournament games are recorded in the stats bucket "Tournament";
  - quick play and sitting are refused in a tournament server and at runner-owned tables;
  - debug verbs `tourneyLocal`, `tourneyFake`, `tourneyStartsIn` and `tourneyClear`, plus the
    Studio `TestTournamentServer` switch.
- **`Seating`:** chair prompts are off at owned tables and in a tournament server.
- **`Settings`:**
  - `TABLE_COUNT = 8`, `START_PLACE_ID`;
  - **`TOURNAMENT_TEMPLATE_ID = 0` (the user still has to make the template place)**;
  - `FIRST_MOVE_LIMIT`.
- **Room:** `builders/build_room.lua` now builds **8 tables** (columns −54, −18, 18 and 54). The room
  was rebuilt and the overlap check found 0 overlaps. The Tables card fits 8 rows.
- **Play screen:** the Tournament card is unlocked ("VIP HOSTS") and opens the Tournament card.
- **Lobby HUD:** a `tourney` card, and `setTournamentServer` hides PLAY and Tables.

## Tested (Studio)
- **Tests:** TournamentTests 10/10, StealTests 8/8, AbilityTests 24/24.
- **A whole 8-bot bracket** (`tourneyLocal`): the quarter-finals ran on T1–T4, the tables were
  given back, then a 20 s break, the semi-finals and the final, to a champion.
- **Daily log (`studio_d_` key):** the final went to `champions`, the games went to `top` sorted by
  accuracy, and one game with a brilliant move went to `brilliant`. The reviews finish in the
  background.
- **Clock and timing:**
  - the Armageddon clock read 5:00 / 4:00;
  - a player who didn't make a first move lost by "abandoned" after 30 s;
  - a bot isn't treated as disconnected.
- **Lobby UI (VIP):**
  - Play → Tournament → Start: the banner "You're in! Starts in 4:31 · 7/16", and the card lists
    the players;
  - a cancel with 7 players ("only 7 joined (8 needed)") shows on the banner and the card;
  - a launch with 9 players cancels with "the tournament place couldn't be opened", because the
    template isn't set yet;
  - Today's games lists the logged games, and Review opens one.
- **Tournament server** (`TestTournamentServer`, 7 bots + me):
  - I was seated automatically at my match, with no Steal button;
  - the bracket shows the live matches with Watch, and Watch put me beside the table;
  - "You're out" and the champion line show correctly.
- **Console:** no errors on the client or the server.

## Not tested (needs live servers)
- the announcement across servers;
- CreatePlaceAsync and ReserveServer;
- teleports in and out;
- a spectator joining from the lobby;
- the end-of-tournament teleport home.

## The user's setup (before tournaments can run live)
1. In Creator Hub, add a new place to the experience (the template). Turn on copying in its
   settings, and turn on the experience's Create/Save Place API permission if Roblox asks for it.
2. Open the template in Studio, push the code (`python push.py`), and publish it. Run the room
   builder there too, or copy the Lobby model over.
3. Put its place id in `Settings.TOURNAMENT_TEMPLATE_ID`, push into the main place and publish it.
4. Set the template's max players to about 40 (16 players + spectators).

## Template place set up (later 2026-10-18)
- **The place:** the user added the place "Tournament" with copying on. Its id is **15361839010**,
  found with `AssetService:GetGamePlacesAsync` from Chess??.
- **Settings:** `Settings.TOURNAMENT_TEMPLATE_ID = 15361839010`, pushed into Chess??.
- **Opened in Studio,** with all the code pushed (`push.py`). `builders/build_room.lua` built the
  room: 8 tables, 768 parts, 0 overlaps.
- **Playtest there:**
  - it's a tournament server (`TournamentServer = true`);
  - with no tournament running it shows "There's no tournament in this server" and Back to lobby;
  - no errors.
  - Studio drew no 3D in that window, in edit mode too (the axis gizmo still showed), most likely
    because the window wasn't in front. A script confirmed the room is there.
- **Keeping it up to date:** every code change has to be pushed into **both** places and both
  published. The created tournament place is made again from the template the next time its
  `Updated` time changes.

Stills:
- `stills/2026-10-18w-play-tournament-card.jpg`
- `x-tournament-open-banner`
- `y-tournament-cancelled`
- `z-todays-games`
- `2026-10-19a-bracket-live-watch`
- `b-bracket-champion`
- `c-watching-a-table`

Back to [[Home]]
