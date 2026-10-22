---
tags: [design, tournament]
---
# Tournaments

## Rules
**The user's rules (2026-10-18):**
- **Starting one:** a VIP starts it (pass 2037495121), and every server gets a global announcement
  that it starts in 5 minutes. **Anyone can join.**
- **Size:** at least 8 players, at most 16.
- **Where:** it's played in a separate place, made with the Create/Save Place API.
- **Format:** knockout.
  - A drawn game is replayed with the colours swapped.
  - If the replay is drawn too, **Armageddon** decides it.
- **Spectating:** once it has started, anyone can watch.
- **Daily log:** the day's top games are logged: the highest accuracy by a player, the most
  brilliant moves, and the 1st-place (final) game.

**Earlier rule ([[Next Steps]] #8):** Classic rules only. No abilities, no Steal, nothing
pay-to-win.

**Agent defaults** (all in `Shared/Tournament.lua`; change them if the user wants):

| Setting | Value |
|---|---|
| Clock | 5 min + 3 s |
| Armageddon | White 5:00, Black 4:00, +2 s each; a draw counts as a Black win |
| Tournaments at a time | one registering or running, across the whole experience |
| Arrival wait | 60 s for registered players to reach the tournament server; no-shows are left out of the bracket |
| Late or gone players | anyone not in the server when their next game is due forfeits it |
| First move | each player gets 30 s for their first move, or loses (`Settings.FIRST_MOVE_LIMIT`), since the clock only runs after White's first move |
| Break | 20 s between rounds |
| Bracket size | the smallest power of two that holds the players (8, or 16 with byes) |
| Seeding | random; byes are spread across the bracket |
| End | 2 min after the final, everyone is teleported back to the lobby |
| Rewards | win coins (+50) and stats (bucket "Tournament") work like any PvP game; no champion prize (not asked for) |

## The tournament place (decided with the user)
- **One template place,** made by the user: a second place in the experience, **copying on**,
  holding the same code (push.py into it). The main lobby place stays copy-locked. Its id goes in
  `Settings.TOURNAMENT_TEMPLATE_ID`: the "Tournament" place, **15361839010** (added by the user
  2026-10-18, found with `AssetService:GetGamePlacesAsync`).
- **Creating the place:**
  - The first launch runs `AssetService:CreatePlaceAsync("Chess Tournament", template)` and stores
    the result in DataStore `ChessTournament_v1` key `place` = `{ placeId, templateUpdated }`.
  - It's made again whenever the template's asset `Updated` time changes, so it always runs the
    current code. Old ones stay; scripts can't delete places.
- **Each tournament:** `TeleportService:ReserveServer(placeId)`, a private server of that place.
- **Roles:** any server whose `game.PlaceId ~= Settings.START_PLACE_ID` is a tournament server
  (ReplicatedStorage attribute `TournamentServer`).

**Keeping the template current:** push every code change into **both** places (open each in
Studio, `python push.py`) and publish both. Re-run `builders/build_room.lua` in the template when
the room changes.

## How it runs
**Lobby: `Tournament/Registry` + `Tournament/Launcher`**
- The current tournament is one MemoryStore record (hash map `ChessTournament_v1`, key
  `current`). Every change goes through UpdateAsync.
- MessagingService topic `ChessTournament` pokes every server, and servers also poll every 15 s.
- At `startsAt`, any lobby server may claim the launch:
  - with fewer than 8 players, it's cancelled;
  - otherwise the claimer makes or reuses the place, reserves a server and marks the record live;
  - every lobby then teleports its own registered players;
  - **Watch** teleports anyone else as a spectator.

**Tournament server: `Tournament/Runner`**
1. It finds its record by `PrivateServerId` and waits for the players.
2. It draws the bracket and plays it on the 8 room tables with `ChessTable:runMatch`. The runner
   owns those tables: nobody can sit, stand, configure or ready up.
3. The client gets the bracket through `Remotes.Tournament`.

**Daily log: `Tournament/DailyLog`**
- Each finished game is reviewed on the server (`Review.analyse`, one at a time) and written to
  DataStore `ChessDaily_v1` key `d_YYYY-MM-DD` (UTC; Studio writes `studio_d_…`).
- The lists:
  - `champions`: every final's deciding game;
  - `top`: 10 games by best single-player accuracy, at least 20 plies and not abandoned;
  - `brilliant`: 10 games by brilliant-move count.

**Client**
- **Banner** (`TournamentBanner`) in every lobby server: "Name's tournament starts in 4:32 · 6/16
  [Join]", then started [Watch] / champion / cancelled messages.
- **Tournament card** (`TournamentPanel`, from the Play screen's Tournament card):
  - Start (VIP) / Join / Leave / Watch, the players, and the rules;
  - a **Today's games** tab, which opens a game in the review.
- **Bracket** (`BracketPanel`, tournament server):
  - rounds as columns; live matches with a red border and **Watch**, which walks you beside that
    table;
  - your own status, and Back to lobby.
  - PLAY and Tables are hidden there.

## Studio testing
**`ChessDebug` verbs:**

| Verb | What it does |
|---|---|
| `tourneyLocal`, n, botTime, withPlayers | plays a whole bracket here with bots, plus you |
| `tourneyFake`, n | adds n fake players to the open tournament |
| `tourneyStartsIn`, s | shortens the countdown to s seconds |
| `tourneyClear` | ends the Studio tournament record |

- **Studio's own MemoryStore map and Messaging topic** keep tests away from live servers.
- **Workspace attribute `TestTournamentServer = true`** (set in Edit, before Play) makes the Studio
  server a tournament server, so the bracket UI can be tested. **Remove it afterwards.**
- **Teleports don't work in Studio:** the cross-server flow needs a live test.

Back to [[Home]]
