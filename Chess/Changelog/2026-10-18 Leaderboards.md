---
tags: [changelog, leaderboards]
---
# Leaderboards (2026-10-18)

Phase 3 of the next-round plan: global leaderboards. **The user chose two boards:**
- **Most wins**: games won against people, every mode, Tournament games included;
- **Tournament champions**: tournaments won.

The code is written and syntax-checked (`tools/luau_check.py`). **Update 2026-10-20:** it's pushed into
Chess??, and `lbFake` filled the new lobby boards ([[Changelog/2026-10-20 Lobby makeover]]). The Stats
tab and the rest of "Still to test" below are still open.

## Stores
Two OrderedDataStores. The key is `tostring(userId)`, and the value is a count.

| Board | Store | Studio store |
|---|---|---|
| `wins` | `ChessLB_Wins_v1` | `ChessLB_Wins_v1_studio` |
| `titles` | `ChessLB_Champions_v1` | `ChessLB_Champions_v1_studio` |

Studio always uses the `_studio` stores (the same rule as `Tournament/Registry`), so tests never
touch the live boards.

## New
**`ServerScriptService/Tables/Leaderboards.lua`**
- `addWin(userId)` / `addTitle(userId)`: `IncrementAsync(+1)` in the background, 3 tries, real
  ids (> 0) only.
- `top(board, n = 10)`:
  - reads `GetSortedAsync(false, n)`, cached for 60 s per board;
  - callers that come in while a read is out wait and share it;
  - a failed read returns the stale list, or `{}`;
  - returns `{ { rank, userId, name, value } }`.
- Names: the player's `Name` when they're in the server, else `Players:GetNameFromUserIdAsync`
  (cached; the lookups run side by side). Fake ids show "Fake n" (from lbFake), or "Test n".
- `mine(userId)` -> `{ wins, titles }`, from `GetAsync` on both stores (no cache).
- `debugSet(board, userId, value, name?)`: Studio only (it asserts), for `lbFake`.

**`builders/backfill_wins.lua`**: a one-off. **Written, not run.**
- It lists the `ChessStats_v1` keys (`ListKeysAsync("u_")`) and sums `w` over each player's
  buckets, skipping `detail` and the old `*_bot` buckets, as the Stats card does.
- It writes the total into the **live** `ChessLB_Wins_v1`, on purpose: it's the one thing that
  names the live store from Studio.
- It only raises a value, never lowers it (UpdateAsync with max), so running it twice is safe.
- `DRY_RUN = true` by default: it prints what it would write. Set `DRY_RUN = false` to write.
- Run it once, in the main place, after the code is published:
  `python tools/run_luau.py builders/backfill_wins.lua`.

## Writes
- **`TableService.onFinished`**: `Leaderboards.addWin` for the winner, inside the same check as
  `Results.record`: both seats must be real Players and the game wasn't aborted. Bots and test
  drivers' fake players never count.
  - **No minimum length.** The coin reward needs `Shop.MIN_PLIES`, but the board counts every win,
    like the stats do (and the backfill reads them). A user decision: should a win need
    `MIN_PLIES` to count here too, against farming with resigns?
- **`Tournament/Runner.finishTournament`**: `Leaderboards.addTitle(champion)`, only when:
  - it isn't a test run (`ctx.test`);
  - the champion is a real id (> 0);
  - the champion played at least one game. A walkover champion (byes and no-shows only, for
    example the only player who arrived) gets no title.

## Lobby verb
- `leaderboard`, arg = `"wins"` | `"titles"` -> `{ board, top (the top 10), mine = { wins, titles } }`.
- Any other arg returns `false, "no such board"`.
- It's listed in TableService's header comment.

## UI: the Stats card's Leaderboard tab
- `StatsPanel`: a third tab, **Leaderboard** (crown icon), next to Overview and Saved games. It's
  open to everyone, not only VIPs.
- **Two boards side by side:**
  - Most wins, with a green title bar;
  - Champions, with a gold title bar.
- **Each row:**
  - the rank (gold, silver and bronze for the top 3);
  - a round headshot (`rbxthumb://type=AvatarHeadShot&id=<id>&w=48&h=48`; fake ids get the person
    icon);
  - the name and the count.
- **Your own row** is green with a green outline.
- **Under the boards:** "You: N wins · N titles".
- **Loading:**
  - the boards load when the tab is opened, and again after 60 s (the server caches them for as
    long);
  - they show "Loading…" first, and a friendly empty or error line when there's nothing to show.
  - The stats "Loading…" line is hidden on this tab.
- **Sizes:** fixed sizes in the 720×410 card (rows of 40, text at 16 or more), so it fits a phone
  like the other tabs. Ten rows scroll inside a list.
- **Wiring:** `LobbyHud` passes `fetchLeaderboard(board)` through to StatsPanel, and
  `ChessClient` invokes `Lobby("leaderboard", nil, board)`.

## Studio testing
**ChessDebug `lbFake`**: `("lbFake", n = 12, board?, mine?)`
- It writes n fake entries (ids -901, -902, …, named "Fake 1", …) with random values: up to 120
  wins and up to 8 titles.
- Without a board it fills both. It only writes the `_studio` stores, through `debugSet`.
- `mine` = a number also puts every player in the server on the board with that value, to test
  your own row and the "You:" line.

## Still to test in Studio
1. `push.py` into the main place, then Play. Run `ChessDebug:Invoke("lbFake", 12, nil, 5)` and open
   Stats → Leaderboard:
   - both boards fill;
   - your row is green;
   - "You: 5 wins · 5 titles" shows.
2. The empty boards: before any lbFake, on a fresh `_studio` store.
3. Headshots load for real ids. Fake ids show the person icon.
4. The phone layout (Studio's device emulator): the tab row (Overview, Saved games, Leaderboard)
   fits, and the rows read well.
5. The controller: the Leaderboard tab can be selected.
6. A real PvP win (two Studio test clients have negative ids, so they're skipped): this needs a
   live test with two accounts. Check that the `wins` board goes up by 1 and that a bot win doesn't
   count.
7. Champions: `tourneyLocal` is a test run, so it must not add a title. Check that
   `ChessLB_Champions_v1_studio` doesn't change. A real champion needs a live tournament.
8. The backfill: a dry run in the main place, before `DRY_RUN = false`.
9. Both places: push into the Tournament template too, since the Runner writes the titles there.

## Later (Phase 4)
- The lobby's leaderboard wall reads `Leaderboards.top` on the server, as SurfaceGuis.

Back to [[Home]]
