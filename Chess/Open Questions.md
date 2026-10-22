---
tags: [core]
---
# Open questions (ask the user before building)

Recommended answers are in brackets. They're only defaults until the user confirms.

**Answered 2026-10-17:** #1 Roblox, #2 a new experience under The Depths Studio (place ID 93046632926618,
given 2026-10-17), #6 **PvP and a bot both at launch**, #8 a 3D board in a lobby room with tables. #3 the user
gives the abilities when the abilities phase starts; build the system plus one test ability first.
Still open: #4, #5 and #9. Resolved since: #7 and #10 (below), and the place ID (given 2026-10-17).

1. ✅ **Platform:** Roblox? [yes, like Descent Depths, owned by The Depths Studio]
2. ✅ **Same place or a new experience?** [a new experience. Ask for the place ID once it exists.]
3. **The abilities:** the user gives these. For each one, pin down:
   - who has it: a piece type, a specific piece, or the player;
   - when it can be used: instead of a move, as well as a move, or passively;
   - its cost: cooldown in turns, charges, or once per game;
   - its targets: squares, pieces, range, line of sight;
   - whether it can capture a king, give check, or get out of check;
   - how it shows on the board.

   Write the answers into the table in [[Design/Abilities Mode]].
4. **Can an ability leave your own king in check?** [no: the legality rule applies to ability
   actions too, unless the user says otherwise]
5. **How does an Abilities game end?** [checkmate, as in Classic; plus resign and timeout. Is
   "capture the king" allowed if abilities can bypass check?]
6. ✅ **Opponents:** (answer: PvP and bot at launch) two players at a table, a bot, or both? [player vs player first; a simple bot
   later, for testing and solo play]
7. ✅ **Clocks:** (built 2026-10-17: presets none / 10+0 / 5+3 / 3+2, [[Changelog/2026-10-17 Server tables]]) [none / 10+0 / 5+3 / 3+2 presets, chosen at the table]
8. ✅ **Look:** (answer: 3D board in a room) 3D pieces on a physical board in a room, or a 2D screen board? Any theme? [3D board,
   top-down camera with a tilt option. Ask for references.]
9. **Ranked / Elo, saving stats?** [later; record wins and losses per mode from the start]
10. **Spectators?** Answered 2026-10-18: anyone can watch a running tournament ([[Design/Tournament]]).

Back to [[Home]]
