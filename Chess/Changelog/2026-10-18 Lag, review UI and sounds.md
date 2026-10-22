---
tags: [changelog]
---
# Lag, the review UI and sounds (2026-10-18)

This works through the "Start here" list in [[Next Steps]], from the user's feedback on 2026-10-17.

## Lag
Measured in a Studio playtest on the user's PC. Studio caps the frame rate at 60 here, so CPU and
GPU times tell more:
- **Lobby:** render CPU 2.8 ms, GPU 1.1 ms, Heartbeat 0.15 ms per frame. That's cheap.
  - About 2,000 GUI objects and 297 checker frames.
  - 2,273 parts, about 1,500 of them in the part-built pieces. They're static and cheap.
- **The likely live-server cause:** the bot's search ran on the **server** and took **12 ms of
  every server frame** while thinking. Roblox servers are slower than a desktop, so one or two
  bot games could overrun the server's 16.7 ms frame. Every player then gets choppy movement and
  delayed moves. Studio on a fast PC hides this.
- **The client review** also took 12 ms per frame while analysing. On this PC that gave hitches up
  to 32 ms; slower machines get worse.

Fixes in `Search.lua`:
- `opts.slice` sets the thinking time between yields. The default dropped from 12 ms to **4 ms**,
  so the server bot keeps frames free. Its wall-clock budget is unchanged, so it thinks a little
  less per move. BotTests still pass.
- `opts.computeBudget`: when true, time spent waiting in yields doesn't use up the budget. The
  review uses it with a 6 ms slice and a 0.15 s thinking budget per position, so its grades keep
  their depth and only take longer to arrive. A 20-ply game took about 15 s.

Not verified on a live server yet. If it's still laggy, ask which device and where (lobby, in a
game, the review). Next candidates:
- move the bot search into an `Actor` (parallel Luau, off the main thread);
- swap the frame-built checker for the Photoshop tile;
- turn off shadows on the piece parts.

## Review UI (less clutter + skeleton loaders)
The right panel in `ReviewPanel.lua` was rebuilt:
- A red ✖ sits in the header; the bottom Close button is gone.
- Two accuracy cards.
- **"Your moves"**: one row of 7 grade chips (symbol badge + count) for the viewer only. Good and
  Excellent are merged, and Forced is dropped. The old 9-row two-column table is gone.
- One **feedback card** with a big grade badge.
- The move list is taller.
- One nav row: |◀ ◀ ▶ ▶| plus a PGN tile (Classic) or a Key moment tile (Abilities).
- Abilities games show one line: "✦ Abilities: N used · M missed".

**Skeleton loaders** while the analysis runs:
- shimmering bars in the accuracy cards and the chip counts;
- a grey badge and two lines in the feedback card for an unanalysed move;
- a shimmer over the eval bar;
- pulsing grade dots in the move list.

One RenderStepped loop drives all of them, and only while something is still loading.

The feedback text's grade colours are brightened so they read on the green card.

## Sounds
- **Review:** stepping forward plays the move's sound (move, capture, castle, check; snipe for an
  ability), and stepping back a soft knock. A brilliant or great move adds a bright chime (`good`);
  a mistake or blunder adds a low note (`bad`). Opening the review is silent.
- **Buttons** (done by a subagent, checked here):
  - every UiKit button, tile and ✖ plays `hover` (Roblox's built-in `volume_slider.ogg`,
    debounced 0.06 s, also on controller focus) and `click` (the wood knock pitched up);
  - the Play cards and the theme swatches play them too.
- All of these respect the Sound setting.

## Checked
- Syntax check, push, BotTests and AbilityTests pass.
- Studio playtest: review stills while analysing (`stills/2026-10-18a-review-skeletons.jpg`) and
  done (`stills/2026-10-18b-review-done.jpg`); stepping gave no console errors.
- Sounds weren't checked by ear.

## Also
The user asked to use **subagents for easy tasks**; that's now in the global `~/.claude/CLAUDE.md`.

Back to [[Home]]
