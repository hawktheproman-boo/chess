---
tags: [core]
---
# Next steps (build order)

The full approved plan, with phases and verification, is in [[Build Plan]]. The bot is in the launch
scope, as phase 3 of the plan.

## ▶ User feedback 2026-10-17: done 2026-10-18 ([[Changelog/2026-10-18 Lag, review UI and sounds]])
1. ✅ (fixed; the user's live retest on 2026-10-18 showed a constant 240 fps, [[Changelog/2026-10-18 Live freeze fix]]) **Lag:** the bot search took
   12 ms of every server frame and the client review the same. Both now yield every 4–6 ms. If
   it's still laggy live, ask which device and where, then try:
   - the bot search in an `Actor` (parallel Luau);
   - the checker tile instead of frames;
   - no shadows on the piece parts.
2. ✅ **Review UI:** decluttered, with skeleton loaders.
3. ✅ **Review sounds:** move sounds while stepping, plus a chime or low note for grades.
4. ✅ **Button sounds:** hover and click on every button.

0. ✅ (done 2026-10-17: place ID 93046632926618) **Ask the [[Open Questions]]**, platform and abilities first. Get the place ID and set up
   `src/` for it.
1. ✅ (done 2026-10-17, perft passes) **Rules engine, Classic** (`src/ReplicatedStorage/Shared/Chess/`): Board, Moves, Game with
   undo, FEN, SAN. Pass the perft numbers in [[Design/Classic Mode]] before anything visual.
2. ✅ (done 2026-10-17) **Server tables.** create a game, validate and apply actions, replicate state, game end, resign
   and draw, clocks.
3. ✅ (done 2026-10-17) the bot, and the board and input (phase 4). Left from phase 4: test
   controller and touch, see the result, promotion and draw banners, auto-size the table panel.
   Original notes for this step: a 3D board from state, legal-move highlights, mouse + touch + controller,
   the promotion picker, the move list, clocks. Small stills to the user for the look.
4. ✅ (done 2026-10-17) Lobby polish (phase 5). **Next: phase 6, abilities.** Build the system plus one
   test ability, then ask the user for the real abilities.
   Original notes: Much of it already exists in the table panel.
   **Lobby:** pick a mode and a clock, sit at a table, play against another player (and a test bot).
5. ✅ (2026-10-18: Snipe + Double Jump, Battering Ram, Swap (removed 2026-10-20), Royal Escape, [[Changelog/2026-10-18 Four piece abilities]]) **Abilities system:** the hooks in [[Design/Abilities Mode]] plus one test ability to prove the
   plumbing (undo, legality, networking, UI targeting). Then the user's abilities, one at a time,
   each with a test position.
6. **Polish:** sounds, piece animations, stats per mode (DataStore), then tell the user what's
   ready to try.

## ▶ Now (user, 2026-10-20)
1. ✅ (built 2026-10-20, [[Changelog/2026-10-20 Lobby makeover]]) **The lobby makeover** (Build Plan Phase 4). Left: a phone check, by ear, and building it into the Tournament place.
2. Then the queen's **[[Design/Domain Expansion]]**. The rules are recorded, with a few agent
   questions still open. Build it with [[Design/Cutscene Treatment]], and keep it out of the Shop
   until the user says so.
3. **Store art** ([[Design/Store Art]]): the CHESS?? icon first, then the hero thumbnail, the 6 pass
   and product icons, and thumbnails 2–5.
4. **For the user:** take the Swap gamepass (2036241682) off sale.

## ▶ Shop follow-ups (2026-10-18, [[Changelog/2026-10-18 Shop and coins]])
- Shop on a phone: checked in Studio's emulation ([[Changelog/2026-10-18 Shop detail view and ability demos]]);
  still to see on a real phone. Coin rewards on a live server are still to check.
- Prices follow 10 coins per Robux (user asked for a recommendation, 2026-10-18); the reward
  is still an agent default in `Shared/Shop.lua`. Starting coins are 0 now ✅ (done 2026-10-18,
  [[Changelog/2026-10-18 Gamepasses and Steal a Piece]]).
- Steal a Piece: done ([[Changelog/2026-10-18 Gamepasses and Steal a Piece]]). Still to check: a
  real Robux purchase on a live server; agent rules (can give mate, steal the checker) to confirm.
- The review's bot may suggest an ability the player doesn't own (reviews replay with all six).

## Backlog from the user (2026-10-17)
Suggested order, cheapest and most visible first:
1. ✅ (done 2026-10-17, [[Changelog/2026-10-17 Sounds and themes]]; tune by ear) **Sound effects:** move, capture, check, castle, game start and end, low time, snipe. Use
   group-owned or Roblox-library sounds; never copy chess.com's.
2. ✅ (done 2026-10-17, 6 board themes; piece styles still to do) **Custom board themes:** board colour sets (and piece styles later), picked in a menu and saved
   per player.
3. **2D board with images:** replace the ViewportFrame icons with flat piece images. Uploads go
   under the group. Use an open-licensed set, e.g. cburnett (lichess), or draw our own; never the
   chess.com set.
4. ✅ (done 2026-10-17, [[Changelog/2026-10-17 PGN and game review]]; reviewing past games from the lobby is still to do) **PGN and game review:** a PGN export or copy of each game (Abilities actions as comments). A
   review screen steps through the moves, and the bot rates each move (best / good / inaccuracy /
   mistake / blunder, plus an accuracy %).
5. ✅ (done 2026-10-17: emoji icons, then the dark simulator style + Play screen, [[Changelog/2026-10-17 Simulator style and Play screen]]; Adobe art in [[Design/UI Style]] waits on uploads) **UI restyle:** "look like the UI on top Roblox games right now, an icon beside text". That means
   icon + label buttons, chunky rounded cards and bold text, keeping the green/white palette and
   avoiding brainrot.
6. ✅ (done 2026-10-18 as developer product 3719153067, [[Changelog/2026-10-18 Gamepasses and Steal a Piece]]) **Steal a Piece (Robux gamepass):** in Classic and Abilities. Once per game, it uses the turn,
   and any enemy piece except the king and queen becomes yours. See [[Design/Abilities Mode]]. It
   needs a gamepass ID from the user.
7. ✅ (built 2026-10-18 as Any Passant, [[Changelog/2026-10-18 Any Passant and ability panel]]) **En Passant Anything** (the user's "forced passant"): once per game, a pawn can take en passant
   any enemy piece that just moved past it. Rules: see the ability table.
8. ✅ (built 2026-10-18, [[Changelog/2026-10-18 Tournaments]], [[Design/Tournament]]) **Tournament mode:** Classic rules only, with no abilities, no Steal and nothing
   pay-to-win. The user decided (2026-10-18): VIPs start one, anyone joins; 8–16 players; knockout.
   **Still to do:**
   - the template place exists (Tournament, 15361839010): the code is pushed and the room is built
     (8 tables, 0 overlaps) as of 2026-10-18. **The user publishes it**, and publishes Chess?? too
     (it has the template id);
   - test it live: cross-server banner, teleports, spectators, the trip home.

Back to [[Home]]
