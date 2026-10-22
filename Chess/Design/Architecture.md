---
tags: [design]
---
# Architecture

Keep the chess logic **pure and separate from Roblox**, so it can be tested in isolation and shared
by every mode.

## Layers
1. **`Shared/Chess/` (ModuleScripts, no Roblox services):**
   - `Board`: an 8×8 array (or 0x88 / 10×12 mailbox). Each piece is `{ type, color, id, moved,
     data = {} }`. `data` holds per-piece ability state (charges, cooldowns, statuses).
   - `Moves`: generates pseudo-legal moves per piece type, then filters for legality (your own king
     not in check after the move).
   - `Game`: whose turn it is, castling rights, the en passant square, the halfmove clock, a
     position-repetition table, and the result. `Game:apply(action)` / `Game:undo()`.
   - **Actions**, not just moves: `{ kind = "move", from, to, promotion }` and later
     `{ kind = "ability", id, piece, targets }`. Everything a player can do is an action, so
     abilities, undo, replays and networking all go through one path.
   - `Notation`: FEN in and out, plus SAN for the move list. Useful for tests, saves and debugging.
2. **`Shared/Modes/`:** one module per mode (`Classic`, `Abilities`). Each holds its settings plus
   rule hooks that `Moves` and `Game` call ([[Design/Abilities Mode]]). Classic has no hooks.
3. **Server (`ServerScriptService/`):**
   - **The server is the authority.** The client sends an action request; the server validates it
     with `Shared/Chess`, applies it, and replicates the new state.
   - Never trust client moves.
   - Matchmaking and tables, clocks, resign/draw offers, disconnect handling, results and stats
     (DataStore).
4. **Client (`StarterPlayerScripts/`):**
   - draws the board from the replicated state;
   - handles input (pick up, legal-move highlights, drop) and runs animations;
   - plays sounds and shows the UI.

   The client may run `Shared/Chess` locally to show legal moves instantly. The server still
   decides.

## Networking
- Remotes:
  - `RequestAction(tableId, action)`
  - `State(tableId, snapshot or delta)`
  - `Result(tableId, result)`
- Send compact state: FEN plus ability state, or the action that was applied, plus a sequence
  number so a client can detect a missed update and ask for a full snapshot.

## Testing
- **Perft:** counts the move-tree leaves from a given position to a given depth. Compare against
  the published numbers ([[Design/Classic Mode]]).
- Run the tests in Studio with `execute_luau` on the pure modules. It runs in its own VM, which
  suits pure modules ([[Tooling and Studio Gotchas]]).
- Ability tests: a FEN plus ability state, an action, then the expected FEN or state.

Back to [[Home]]
