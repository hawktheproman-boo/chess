---
tags: [changelog]
---
# Phase 1: rules engine (2026-10-17)

- The user created the experience: start place ID **93046632926618**.
- Wrote the pure Classic engine in `src/ReplicatedStorage/Shared/Chess/`: Board, Moves, Notation,
  Game. Also wrote `Modes/Classic` and `Tests/Perft`. Details are in [[Current State]].
- **The perft gate passes** for CPW positions 1–6 (start to depth 4: 197,281). All 13 rules tests
  pass: mate, stalemate, threefold, 50-move, insufficient material, the en passant pin, castling
  through check, promotion and undo, SAN disambiguation, FEN round trip, illegal-move rejection,
  timeout draws.
- Gotchas: `require` caching in `execute_luau` (fix in [[Tooling and Studio Gotchas]]), and
  position 6's FEN must come from the CPW page, not from memory.
- Ability hooks are ready in Game/Moves: `setup`, `modifyMoves`, `abilityActions`,
  `applyAbility` (it pushes its own undo record), `onTurnStart` (it must record what it changes),
  `checkResult`, `stateKey`.
- Next: phase 2, the server tables.

Back to [[Home]]
