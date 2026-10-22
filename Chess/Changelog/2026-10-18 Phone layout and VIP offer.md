---
tags: [changelog, ui, mobile, vip]
---
# Phone layout, bigger 2D board, VIP offer revamp (2026-10-18)

The user's feedback:
- the UI is too small on phones, and so is the 2D board;
- the VIP section looks bland; make it enticing;
- the Get VIP button should show the price with the Robux icon (400).

## Why it was small
Every GUI was scaled for 1280×720 with `min(v.X/1280, v.Y/720)`, clamped at 0.55. A phone in
landscape (the Studio emulator: 750×381 with a 58 px top bar) hit that floor, so text came out at
about half size. The player bars above and below the board also left the 2D board only ~210 px.

## UiKit: screen classes (shared)
- `Ui.compact(v)`: true when the screen is shorter than 560 px.
- `Ui.uiScale(v)`:
  - compact screens: `min(v.Y/430, v.X/860)`, clamped 0.6–1;
  - other screens: the old rule.
- `Ui.seatLayout(v, inset)`: the seated layout, used by the HUD and the 2D board. It returns the
  `{ compact, scale, board }` for the screen.
  - **Compact:** the board gets the full height (usable height − 16). The buttons stay on the left
    and the player bars move to the right, both columns 176 wide. The scale is lowered if the
    columns wouldn't fit; below 0.6 the board gives way instead.
- `Ui.setFit(holder, fit)`: shrinks a `card()` to fit the screen. `popOnShow` now pops to the
  card's `Fit` attribute.
- `setText` takes an image path (`rbxasset://…`) as an icon. `Ui.ROBUX` =
  `rbxasset://textures/ui/common/robux@3x.png`, which ships with every Roblox client, so there's
  nothing to upload.

## Screens on a phone (750×381)
- **HUD:**
  - scale 0.87 (was 0.55);
  - the player bars become 176×100 cards on the right, with the clock across the bottom;
  - the draw offer sits between them;
  - Roblox's player list hides while seated on a compact screen (it covered the opponent card);
  - wide screens are unchanged.
- **2D board:** 307 px (was ~210), centred between the two columns.
- **Lobby:**
  - scale 0.87;
  - cards fit the height (with room for the close X) and are centred;
  - the side column hides while a card is open and sits a little higher, clear of the thumbstick.
- **Play screen:** on phones the tip is dropped and the layout is cropped to the kicker…scroll-bar
  band, then stretched to the screen's width. The cards are ~30% bigger and scroll sideways.
- **Settings:** a landscape card on phones (themes left, Sound / Auto-queen / Done stacked
  right), at 0.82 (was 0.61).
- **Review:** unchanged; it already fills the screen.

## Stats card, now landscape (720×410)
- Wins, Draws and Losses are stacked down the left. The right side shows the VIP details or the
  VIP offer.
- The VIP details have shorter labels so they fit two columns: Classic PvP / Classic bots, …,
  Accuracy, Brilliant. VIPs get a gold **VIP** badge in the title bar.
- **VIP offer (non-VIP):**
  - a gold gradient card with 12 white light rays turning slowly behind a glowing, bobbing crown;
  - the kicker "UNLOCK", a big chunky **VIP** and a tilted red **FOREVER** tag;
  - three perks with icons (fire, target, bookmark);
  - a big green button with the Robux icon and the price, a light streak sweeping across it, and a
    small bounce every couple of seconds;
  - a tap on the locked Saved tab nudges the button;
  - the animations only run while the offer is on screen.
- **Price:** the button shows the pass's **live price** (`GetProductInfo` on the pass,
  `PriceInRobux`), with 400 as the fallback. In Studio it read **360**, so the pass is set to 360
  on Roblox. Set it to 400 in the Creator Hub and the button follows on its own.
- **Gotcha:** Roblox doesn't draw rotated GUI objects inside a `ClipsDescendants` frame. The offer
  doesn't clip, and the rays are short enough to fade out inside it.

## Tested (Studio phone emulator, 750×381)
- Lobby, Stats (VIP and non-VIP, through the VIP override), Settings, Play screen, the 3D HUD and
  the 2D board, checked from screenshots.
- **Console:** only Roblox's own UIBlox warnings.
- **Not checked:**
  - Wide (PC) screens weren't re-checked in this pass. The wide code paths are the old values.
  - Scripted clicks stopped landing in the emulator partway through, so the panels were opened
    by script.

Back to [[Home]]
