---
tags: [changelog, bugfix]
---
# Live-client freeze: the runaway table panel (2026-10-18)

## What the user saw (published game, live Roblox client)
- Tables → Sit, or Play → a 1v1 card: a tall, empty dark-green strip filled the middle of the
  screen and Roblox stopped responding.
- In a bot game: very laggy, with the character barely moving.

## Cause
- The seated **table panel** (`Hud.lua`) was the only card using `AutomaticSize` (Y), and it's
  centre-anchored.
- On the live client it **grew without limit**: the strip was exactly the panel's 340 px width at
  the user's UI scale, with its contents pushed off-screen above.
- The panel's **checkerboard** (`UiKit.checker`) rebuilt its squares on every `AbsoluteSize`
  change. So a panel that kept growing meant endless rebuilds with ever more Frames, and Roblox
  froze.
- It kept going after the panel was hidden. That's the bot-game lag: the panel shows briefly
  before the game starts.
- It didn't happen in Studio on the user's PC, so it was missed. Live-client layout behaviour
  differs.

## Fix
- **Table panel:** no `AutomaticSize`. The height is computed in `Hud:update` from the rows
  showing (title 56, rows plus 10 px gaps, 18 px margin), and the list aligns to the top.
- **Checkerboard:** built **once**, at the card's own offset size (600×700 when the size is a
  scale or unknown), clipped by the panel, and capped at 400 squares. It **no longer listens to
  AbsoluteSize**, so no layout loop can make it rebuild again.
- **Rule:** no `AutomaticSize` on cards, and nothing may rebuild on `AbsoluteSize`.

## Status
Pushed and tested in a Studio playtest (2026-10-18):
- **Play → Classic 1v1** and **Tables → Sit (Table 2)**, done with real clicks:
  - the table panel shows at a fixed 253×189 px at this scale, unchanged after 2 s;
  - with the bot and Ready rows added it grows to 253×238, then hides when the game starts;
  - the checkerboard stays at 877 squares, built once and never growing.
- **Server during a Strong-bot game:** 60 fps, average 16.7 ms, worst 19 ms over 4 bot moves.
  The 4 ms slices work.
- **Client frame rate in Studio isn't trustworthy right now:** the lobby also showed about 14 fps,
  where it ran at 60 earlier. Studio throttles when its window isn't focused, and a Roblox Player
  was running beside it. Game-side numbers were fine: render CPU about 2 ms; ~1,700 "moving
  primitives" while seated, but removing every piece model didn't change the frame rate.
- **Next:** the user re-publishes and retests on live Roblox (both flows, plus a bot game) and
  reports the Shift+F5 FPS.

## Live retest (user, 2026-10-18)
- Gameplay is fine: a **constant 240 fps** on live Roblox, including bot games. The freeze is gone.
- Follow-up fix: the review opened on the **last** move. It now opens on the start position while
  it analyses, then jumps to **move 1** when the analysis finishes, unless the player has already
  stepped or clicked a move (`userNavigated`). Tested in Studio: start position at opening,
  "1. e4 is a good move" after 3.1 s.

Back to [[Home]]
