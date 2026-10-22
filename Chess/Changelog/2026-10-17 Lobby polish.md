---
tags: [changelog]
---
# Phase 5: lobby polish (2026-10-17)

## Built
- **`UiKit`** (client) holds the shared look: colours, Builder Sans fonts, card, chunky button,
  label, list. Both `Hud` and the new `LobbyHud` use it.
- **`LobbyHud`**, shown while you're not seated. A bottom bar with four buttons:
  - **Play vs Bot** opens a card with four level tiles (Beginner "Just learning", Casual, Club,
    Strong), a clock cycle, "Play as" White / Random / Black, and **Start game**. One click
    seats you, invites the bot and starts;
  - **Play vs Player** joins the first table where a human is waiting alone. If nobody is
    waiting, it takes an empty table at random colour and waits there;
  - **Tables** lists T1–T6 with the players, a status (Free / Waiting for an opponent / About
    to start / Game in progress) and Sit/Join buttons;
  - **Stats** shows W/L/D per mode, vs players and vs bots. If the DataStore isn't available, it
    explains that instead.

  It also has a green toast for errors ("All tables are busy", …). On a controller, Y focuses
  the bar and B closes a card.
- **Server:**
  - Lobby verb `"quick"` with `{ vs = "bot"|"player", level, clock, color }`;
  - `ChessTable:start(fen?)`. `startFen` is carried in snapshots, so clients replay from the
    right position. Only test drivers use it;
  - the debug `reset` now keeps the table's seq counting. Before, the client ignored the new
    table's snapshots;
  - the debug `start` takes an optional FEN.
- **The seated HUD:**
  - the table panel shows "✓ ready" next to each ready player;
  - the result card says "Opponent wants a rematch!" when they've readied first. An aborted
    game is titled "Game aborted", not "Draw";
  - the draw-offer card moved into the left column above the buttons. It used to cover the 8th
    rank;
  - the table signs were restyled: white pills, green text and a green rim.

## Verified in a playtest (real mouse clicks unless noted)
- The Tables list and live status (bot games, a waiting player, free tables).
- **Play vs Bot → Start game:** seated at T1, my character in the chair, the game running
  against Casual.
- **Resign → confirm → result card** shows "Game aborted" (no moves yet).
- **Promotion:** from a test position, clicking b7 then b8 in 2D opened the picker with piece
  pictures. Choosing Queen played `b8=Q+`.
- **Draw:** the scripted opponent offered, the offer card showed, Accept gave a draw by
  agreement.
- **Rematch:** after the opponent readied first, the card showed the rematch prompt. Rematch
  started a new game with colours swapped and the 2D board flipped to Black.
- **Leave table** (with confirm) returns to the lobby. Stats loads gracefully.
- **Play vs Player** matched me with the scripted player waiting at the first table, as
  designed.

## Not verified
- Controller and touch, on real devices.
- Two real players matchmaking. Scripted participants stood in for the opponent; a real test
  needs 2 players (Studio's Test → Clients and Servers).

Stills: `chess/stills/2026-10-17d-*.jpg`.

Back to [[Home]]
