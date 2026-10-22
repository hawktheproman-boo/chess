---
tags: [changelog]
---
# PGN export and game review (2026-10-17)

Backlog item 4 in [[Next Steps]]. The user chose it ahead of the image pieces, since they can't
upload images to Roblox yet.

## PGN (`Shared/Chess/Pgn.lua`)
- `Pgn.build({ startFen, moves, mode, white, black, result, clock, date })`, `Pgn.movesFrom(game)`
  and `Pgn.resultToken(result)`.
- **Classic games are standard PGN:** the Seven Tag Roster, plus TimeControl (`600+0`),
  Termination, and SetUp/FEN for non-standard starts. Lines wrap at 80, and `N...` is used when
  Black moves first.
- **Abilities games use a dialect:** a `Variant "Abilities"` header, and each ability written as a
  null move with a comment, e.g. `-- {Bishop Snipe: Bc1 snipe NE x3}`. The move numbers stay right,
  but other chess programs can't replay these games.

## Analysis (`Shared/Bot/Review.lua`)
- `Review.analyse(record, opts)` searches every position with the bot (depth 5, 0.25 s each,
  yielding per frame) and reports each ply through `onPly` as it goes.
- **Grading:** it compares the best move's score with the played move's score (minus the
  opponent's best reply), turned into lichess-style **win %**:
  - **Best** when the played move is the bot's move;
  - **Excellent** for a drop under 2;
  - **Good** under 10;
  - **Inaccuracy** at 10 or more;
  - **Mistake** at 20 or more;
  - **Blunder** at 30 or more;
  - **Forced** when only one move was legal.
- **Accuracy per move** is `103.17·e^(−0.04354·drop) − 3.17`; each side's accuracy is the mean,
  leaving out forced moves.
- Mates count as ±10000 cp, and `mateAfter` gives moves to mate (+ for White).
- Abilities are graded like any other move, since the search already knows them.

## Review screen (`Chess/ReviewPanel.lua`)
- It opens from a new **Review** button on the game-over card (Rematch / Review / Leave).
- **Layout:** a 2D board on the left, mounted in a frame (new `Board2D.new(onDown, { parent })`
  option), with an eval bar and the player names. On the right:
  - each side's accuracy;
  - a grade count table;
  - feedback ("3. Bc4 is a blunder. Best was **Qf3**.");
  - the move list with coloured grade badges (click to jump);
  - the controls |◀ ◀ ▶ ▶|;
  - Copy PGN, which opens a select-all-and-copy text box (Roblox has no clipboard API);
  - Close.
- A grade badge sits on the moved piece's square. Arrows / D-pad step through the game,
  Home/End and D-pad up/down jump, and B closes.
- It analyses in the background, so you can browse while it fills in. It's oriented to your
  colour.

## Abilities games: their own review, no PGN (user, 2026-10-17)
The user said not to offer PGN copying for Abilities games ("it would not work") and to give them
a custom review instead.
- **No PGN:** the Copy PGN button and sheet are hidden, and no PGN is built. The `Pgn.lua` dialect
  stays in the code but isn't shown.
- **Title:** "Game Review · Abilities".
- **Ability moves in the list:** a red label with ✦ and a short form, e.g. "✦ Bc1 Snipe ×3".
- **Snipe on the board:** the bishop is tinted, its line gets dots, and the pieces it took are
  marked red, on the position before the shot.
- **Feedback:** the grade sentence plus "It took 3 pieces (+9)." When an ability was the best move
  and the played move lost 10%+ win chance, it adds "Best was **Bc1 Snipe ×3**. A missed ability!"
  (the `missedAbility` field in `Review.lua`).
- **Summary row:** "✦ Abilities used / missed" per side (`abilitiesUsed`, `abilitiesMissed` in
  `Review.summary`).
- **Next key moment ▶** (in Copy PGN's place) jumps through ability uses, mistakes, blunders and
  missed abilities, wrapping round.
- **Verified by script in a playtest:**
  - a snipe game: graded ★ best, "+9" (pawn + knight + rook), the line and hit marks drawn, the
    summary "1 / 0", the PGN button hidden, and Next key moment visible;
  - a game where you pushed a3 instead: an inaccuracy, "Best was Bc1 Snipe ×3. A missed
    ability!", the summary "0 / 1", and Next key moment jumps to it;
  - test-hook verb `reviewKey` added.

## Show best move (user, 2026-10-17)
- On a **mistake, blunder or missed ability**, the feedback box gets a **Show best move** button.
  It puts the board back to the position before that move and plays the best move instead, with a
  ★ badge and that move's marks. A snipe shows its line and hits, then fires. The eval bar shows
  the best line's eval. The feedback reads "★ Best move here: **Rxa2**" (plus "It takes 3 pieces
  (+9)." for a snipe).
- The button then reads **Back to game**. Stepping to another move also returns to the game.
- Code: `ReviewPanel:toggleBest()`, `drawMove()` (marks + badge, shared with `go()`), and
  `offersBest(e)`. Test-hook verb `reviewBest`.
- **Verified by script:**
  - Classic `4k3/8/8/8/8/8/q7/R3K3 w`, 1.Kf1?? → the button shows, and Show best plays Rxa2
    (queen gone, ★ badge, eval +5.0); Back to game restores it; a Good move shows no button;
  - Abilities 1.a3 (a missed snipe) → the button shows, Show best fires the snipe (11 → 8 pieces,
    line and hits marked), "It takes 3 pieces (+9)";
  - no script errors.

## Great and Brilliant (user, 2026-10-17)
- **New grades:** **Brilliant !!** (teal) and **Great !** (blue), above Best. Excellent's badge
  is now ✓ and Good's is ○. Both new grades count in the summary table (rows are now 16 px) and
  appear as key moments.
- **Brilliant:** the move is best or excellent, not an ability, and leaves a knight-or-better en
  prise. That's measured with the opponent's *legal* captures: all the piece if undefended,
  otherwise the piece minus the cheapest capturer. That risk is at least 200 more than what the
  move captured, the mover's win chance after it is at least 45%, and the mover wasn't already up
  more than 300 in material. A mating sacrifice counts; tossing a piece when you're already a
  queen up doesn't.
- **Great:** the move is the bot's best and not a recapture (the opponent didn't just capture on
  that square). The best alternative is found by a second search with the move left out (new
  `Search.choose` option `skip`, applied at the search root too). That alternative must be 20%+
  win chance worse and leave the mover at 65% or less, so the move actually matters for the
  result.
- **Fixed on the way:** `skip` first only filtered the first move list, so the root search still
  found the skipped move. It's now filtered inside `negamax` at ply 0 as well.
- **Verified (Edit mode):**
  - `r5k1/5ppp/8/1Q6/8/8/q4PPP/4R1K1 w`: 1.Qe8+!! is **brilliant**, then Rxe8 forced and Rxe8#
    best;
  - `3q2k1/5ppp/8/8/8/7P/PPn2PP1/Q1B3K1 w`: 1.Qb1 is **great** (+1.8; the next best, Bg5, is
    −1.2);
  - Scholar's Mate and a plain queen trade get no false Brilliant or Great;
  - BotTests and AbilityTests still pass.
- **Limits:** grades are only as good as the bot (depth 5, 0.25 s). A deep sacrifice it can't see
  through gets no !!.

## Test hook
`PlayerScripts.ChessClientDebug` (Studio only) is a BindableFunction with the verbs `review`,
`reviewGo(ply)`, `reviewKey`, `reviewBest`, `closeReview`, `settings` and `theme(id)`. Scripts can use it to press what a
player would press, for when Studio isn't focused.

## Verified
- **Edit mode:**
  - the Scholar's Mate PGN is correct;
  - the review grades 3…Nf6 a **blunder** (best was g6, and it allows mate in 1) and 4.Qxf7#
    **best**, with accuracy W 92 / B 67, in 1.3 s;
  - the Abilities PGN from a FEN with Black to move reads `1... Qa6 2. -- {Bishop Snipe: …} *`.
- **Playtest (by script):**
  - a 10-ply game against the bot, then a resignation; Review opened from the seat;
  - everything was analysed in 3 s; 3.Bc4 (leaving the queen to be taken) was graded a
    **blunder**, best Qf3, and 2…g6 **forced** (the only answer to the check);
  - accuracy 73.7 / 91.4, eval −10.1 at the end;
  - stepping to ply 5 put the ?? badge on the board, the last-move marks and the list highlight in
    place;
  - the PGN text matches the game;
  - no script errors.

## Not checked yet (needs the PC)
- What the review screen and the 3-button result card look like.
- Selecting and copying from the PGN box.
- Phone and controller layouts.

## Ideas for later
- Review your last few games from the lobby. That means storing games, e.g. in DataStore, the last
  10 per player.

Back to [[Home]]
