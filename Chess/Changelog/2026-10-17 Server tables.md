---
tags: [changelog]
---
# Phase 2: server tables (2026-10-17)

- Added `Shared/Settings` (modes, clock presets none/10+0/5+3/3+2, 6 tables, 60 s grace) and
  `ServerScriptService/Tables/`: `TableService.server`, `ChessTable`, `Clock`, `Results`.
  Details are in [[Current State]].
- Rules decided here (change them if the user wants something else):
  - leaving or resigning before both sides have moved = **aborted**, with no stats;
  - leaving later = a loss ("abandoned") after the 60 s grace. Rejoining the same server within
    the grace restores the seat;
  - a draw offer stays open until it's answered or the opponent moves. A player can make one
    offer per own move;
  - no clock runs until White's first move. The increment is added after each timed move;
  - in a rematch, the colours swap.
- **Tested in a playtest through `ServerStorage.ChessDebug`, all passing:**
  - Scholar's mate gives a result;
  - the SAN list and seq numbers are continuous;
  - the 5+3 increment maths;
  - rejections: wrong turn, not seated, fractional or off-board squares, bad promotion,
    non-table actions, illegal moves, moves after the game is over;
  - the draw offer, decline, accept, re-offer limit, and an offer declined by moving;
  - a 3+2 flag;
  - an early resign aborts, a later resign is a loss, the rematch colour swap;
  - the disconnect grace, cancelled by a rejoin, and forfeit after it, with the seat freed;
  - bad settings are refused.
- **The client remote path was checked from the playtest client:** list, sit, configure
  validation, a rejected action, a snapshot request, stand.
- The DataStore is blocked in Studio until API access is enabled. Results only warn.
- Next: phase 3, the bot.

Back to [[Home]]
