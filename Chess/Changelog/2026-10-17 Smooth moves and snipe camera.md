---
tags: [changelog]
---
# Smooth moves, snipe camera, new backlog (2026-10-17)

## Moves show instantly (client prediction)
The user said pieces "lag before moving". The cause: the client only drew a move after the
server echoed it back, so every move waited a full round trip (small in Studio, 50–200 ms live).
- `ChessClient.send` now plays your move on a clone of the mirror game (`st.predicted`) and draws
  it straight away. `currentGame(st)` returns `predicted or game or display`.
- The server's echo clears `predicted` and applies the action to the real mirror. The models are
  already on those squares, so nothing moves twice. A reject or a snapshot clears it too, and the
  board snaps back.
- `canAct` is false while a prediction is pending, so you can't send two moves.
- `BoardView`: an ease-in-out slide (the hop and the slide peak together), 0.24 s, a lower arc. A
  dragged piece now glides on from where you let go, instead of jumping back to its old square
  first.
- **Measured in a playtest:** 33 ms from the click to the piece moving, which is about 2 frames
  (the floor).

## Bishop Snipe cutscene, fixed and checked by eye
- The camera goes from high and wide (`base - d*8 + up*8`, FOV 50) to above and behind the
  bishop (`base - d*4.5 + up*5.5`, FOV 44), looking at the midpoint of the line. The bishop sits
  at the bottom of the scope and the targets run up the middle. A side offset was tried first,
  but the king ended up in the way.
- The HUD is hidden during the cutscene. Before, a game-over card such as "Draw by insufficient
  material" popped up over the scope.
- **Verified in a playtest, by clicks:** Snipe button → targeting → click a line square → the
  confirm ("Snipe 3 pieces?") → Yes → cutscene → 3 pieces gone, HUD back, "Snipe used". The bot
  waited out the cutscene, then moved. No script errors. Still: `stills/2026-10-17e-snipe-cutscene.jpg`.
- Still not checked: the cutscene in 2D mode, and the bot as the sniper in a live game.

## New backlog from the user
The list and the decided rules are in [[Next Steps]] (the backlog section) and in the ability
table in [[Design/Abilities Mode]].

Back to [[Home]]
