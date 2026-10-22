---
tags: [changelog, abilities, ui]
---
# Any Passant and the ability panel (2026-10-18)

The user's requests:
1. **Forced Passant becomes "Any Passant":** any piece that goes to the side of a pawn on the 5th
   rank can be captured en passant style.
2. **An ability panel** like the ability cards at the bottom of the screen in the user's Huss Valley
   reference.

## Any Passant (pawn), `Shared/Abilities/PawnPassant.lua`
- It's the pawn's ability: **once per game per player**, and it uses the turn, like the other five.
- **Rule:** an enemy piece that **just landed** beside one of your pawns on its 5th rank can be taken.
  The pawn moves diagonally forward to the square behind it and removes it.
- **Rules the agent chose:**
  - only right after the piece lands;
  - never the king;
  - the square the pawn moves to must be empty;
  - a pawn's double step beside it is left to normal en passant, so the charge isn't spent on a
    free capture.
- **"Just landed"** is `game.landed`, set after every action by the mode's `onTurnStart`:
  - normal moves use `to`;
  - abilities set `rec.landed`: the jump's last square, the ram's landing, both swapped squares,
    the escape square.
  - Undo restores it through the record's new `onPop` hook (`Game:pop`), and clones copy it.
- **Move text:** "e5 passant xd6". Review label "Passant". Cutscene: "ANY PASSANT", a short teal hop
  with a burst on the piece it takes.
- **Bot:** sees it, because it always captures.
- **Known limit:** inside the bot's quiescence search (raw make/unmake) `game.landed` isn't
  refreshed, so a passant there can be judged from a slightly stale landing. This only affects
  evaluation; the real game always checks the real rule.

## The ability panel (`AbilityBar.lua`)
- **One card per piece, pawn to king:**
  - Any Passant;
  - Double Jump;
  - Snipe;
  - Battering Ram;
  - Swap;
  - Royal Escape.
- **Each card shows:**
  - your piece on a coloured tile (teal, blue, red, orange, purple, gold);
  - the piece name as a kicker, and the ability name in chunky caps;
  - a key chip (1-6, keyboard players only);
  - a status: **READY** (green ring), **NO TARGET**, **AIMING** (gold ring, slightly bigger), or
    **USED** (the card fades; it's a CanvasGroup).
- **Using it:**
  - Click / tap a card or press its key to aim **that** ability; the same card again cancels.
  - If only one piece has it (queen, king, a lone pawn) it skips straight to the targets.
  - The controller's X / F still aims every ability at once.
- **Layout:**
  - **wide screens:** a row of 164×64 cards along the bottom; your player bar moves up above it.
    `Ui.seatLayout(v, inset, strip)` takes the strip off the board height and shifts the 2D board
    up (`Board2D:setStrip`). The 3D camera aims 1.5 studs toward you and fits a little wider
    (`CameraRig.setStrip`), so the board sits above your bar.
  - **phones:** a 3×2 grid of 56×64 icon cards beside the board, between the player cards. The
    status is short (READY, AIM, WAIT, USED).
  - The strip stays for as long as you sit at an Abilities table, so the board doesn't jump when the
    game starts.
- The old purple **Ability** button in the left column is gone; the panel replaces it.
- The "Click or drag a piece" hint moves above the panel.

## Tested
- AbilityTests: 24/24. The new passant cases cover:
  - the capture itself;
  - only right after the piece lands;
  - not the king, not onto an occupied square;
  - a double step left to normal en passant;
  - undo, including what had landed.
- BotTests pass.
- **Studio:**
  - **phone-sized window:** the grid shows READY / WAIT; the Pawn card aimed and auto-picked the
    pawn; Any Passant took a knight that had just landed on d5 (the bot was moved through the debug
    hook); afterwards the card showed USED.
  - **wide window (1274×587):** the row of cards with keys and statuses; text fits after
    shrink-to-fit; key **5** aimed Swap (AIMING, gold); the 3D board sits above your bar.
- **Console:** no game warnings or errors.
- **Gotcha:** Studio restarted mid-session with a new instance ID, and everything pushed since the
  last save was gone, so everything was pushed again. The 3D view also captured black in some
  playtests; the GUI was fine.

Back to [[Home]]
