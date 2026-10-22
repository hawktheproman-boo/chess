---
tags: [design]
---
# Classic mode

Standard FIDE chess. Every rule below must work before the Abilities mode is built on top.

## Rules checklist
- [x] **Piece moves:**
  - pawn: single push, double push from the start rank, diagonal capture;
  - knight, bishop, rook, queen, king.
- [x] **Castling**, both sides. Allowed only if:
  - the king and that rook haven't moved;
  - the squares between them are empty;
  - the king isn't in check, doesn't pass through an attacked square, and doesn't land on one.
- [x] **En passant:** only on the move right after the double push, and only if it doesn't expose
  your own king. Watch the horizontal pin: king and enemy rook on the same rank as the two pawns.
- [x] **Promotion:** (engine done; ✅ picker UI built, done 2026-10-17, [[Changelog/2026-10-17 Lobby polish]]) to queen, rook, bishop or knight, with a choice UI. Allow pre-picking queen.
- [x] **Legality:** no move may leave your own king in check, which covers pins and discovered
  checks.
- [x] **Game end:** (in the engine; repetition and the 50-move rule are automatic)
  - checkmate; stalemate (draw);
  - threefold repetition (claim, or automatic);
  - 50-move rule (100 halfmoves without a capture or pawn move);
  - insufficient material: K v K, K+B v K, K+N v K, and K+B v K+B with same-coloured bishops;
  - resign, a draw offer accepted, timeout. Timeout against insufficient material is a draw.
- [x] **Clocks** with an increment, run by the server. ✅ (done 2026-10-17, [[Changelog/2026-10-17 Server tables]])

## Proving the move generator (perft)
**Status 2026-10-17: all pass.** `Shared/Tests/Perft` covers positions 1–6, the start position to depth 4
and the rest to depth 3–4. Checked against the CPW page; position 6's FEN was mistyped at first,
so copy FENs from the page.

Use the standard published perft results. Get them from the Chess Programming Wiki "Perft
Results" page and check the numbers there. At minimum:
- the start position, depth 1–4: 20, 400, 8,902, 197,281;
- "Kiwipete", the castling/en passant/promotion torture position:
  `r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -`, depth 1–3: 48, 2,039,
  97,862;
- positions 3–6 from the same page, for the en passant pin and promotion edge cases.

If one is off, use perft "divide" (count per root move) to find the bad move.

Back to [[Home]]
