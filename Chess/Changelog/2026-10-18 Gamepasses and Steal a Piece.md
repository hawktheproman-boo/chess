---
tags: [changelog, shop, abilities, monetisation]
---
# Ability gamepasses, free Any Passant, Steal a Piece (2026-10-18)

Follow-up to [[Changelog/2026-10-18 Shop and coins]]. The user said:
- every player **starts with Any Passant**;
- the other abilities cost more coins;
- each ability also has its own **Robux gamepass**;
- **Steal a Piece** is a **developer product** (paid every use). It's **not in the Shop**: it has
  its own button in a game;
- they asked for a recommended Robux-to-coins rate.

## Prices: 10 coins per Robux (`Shared/Shop.lua`, `COINS_PER_ROBUX`)
| Ability | Gamepass | Robux | Coins | Wins (at +50) |
|---|---|---|---|---|
| Any Passant | (free) | – | – | – |
| Double Jump | 2040261216 | 25 | 250 | 5 |
| Swap | 2036241682 | 25 | 250 | 5 |
| Royal Escape | 2040423129 | 50 | 500 | 10 |
| Battering Ram | 2036577735 | 100 | 1,000 | 20 |
| Snipe | 2037519702 | 150 | 1,500 | 30 |

All five cost 3,500 coins (about 70 PvP wins) or 350 Robux. New wallets start with **0 coins**
(Any Passant is already theirs).

**Why 10:1:**
- The cheap passes take an evening (5 wins).
- Snipe is a long goal (30 wins), so paying stays tempting.
- Coin prices stay round and readable next to the Robux price.
- If coin packs are ever sold, use the same rate or a little worse (e.g. 1,000 coins for 120 R$),
  so the gamepass stays the better deal for a single ability.

**Live prices:** in Studio the Robux buttons read **23 / 135 / 90 / 23 / 45**, and VIP read 360.
That's 90% of the set prices, the same for every pass, so it's Roblox's price for the user's
account/region. The button always shows what the player will pay.

## Ownership
- **`Tables/Passes.lua` (new):** `UserOwnsGamePassAsync` per ability pass, cached like VIP.
  - All passes are checked when a player joins.
  - A purchase in this server flips the cache and pushes the wallet, so the Shop says OWNED at once.
- **`Wallet`:**
  - `owned` (what the client sees, and the game's loadout) = free + bought with coins + gamepass;
  - buying with coins refuses what a pass already owns.
- **The game's creator account owns every pass**, so in Studio the Shop shows everything owned.
  To test as a normal player, run `ChessDebug:Invoke("passes", userId, false)`.

## Shop cards
- The bottom row is two buttons: a **green coin button** (price + coin icon; two taps, then
  "Sure?") and a **blue Robux button** (live pass price; Roblox's own purchase dialog confirms).
- "Need N more coins" sits above them when you can't afford the coin price.
- Any Passant shows **FREE · OWNED**.
- The VIP tab is just the VIP pass now (the Steal card is gone).

## Steal a Piece (`Shared/Abilities/StealPiece.lua`, new)
**Rules (user):**
- in Classic and Abilities;
- instead of a move, once per game;
- any enemy piece except the king and queen becomes yours, on its square.

**Agent rules (change them if the user disagrees):**
- it may never leave your own king in check, so stealing the checker gets you out of check
  (a steal never exposes your king, because the piece stays where it is);
- it can give check and mate;
- the stolen piece counts as moved;
- it counts like a capture for the 50-move rule;
- stealing a corner rook removes its castling right.

**How it works:**
- **Charge:** `abilityState[color].steal` is 0 until the server grants it. It isn't in the
  position key (repetition).
- **Classic mode** now has hooks, only for this (`setup`, `abilityActions`, `applyAbility`,
  `abilityScore`, `prepareReplay`). With no grant it is plain chess, and perft is unchanged.
- **Abilities mode** adds it beside the six: in `byId` and `abilityActions`, but not in the
  panel, the loadout or `chargesLeft`.
- **Replays:** `Game.forReplay(fen, mode, actions)` grants the steal to whoever used it. Saved
  games, the server's record check and all review replays use it.
- Move text "Steal Nc6" / "Steal e5". The bot never gets a grant, but it does see yours in its
  search.

## Paying for it (developer product 3719153067, `Settings.STEAL_PRODUCT`)
- **Wallet** keeps `steals` (paid, unspent) and the last 50 `receipts`, so a receipt is never
  granted twice.
- **`MarketplaceService.ProcessReceipt`** is in `TableService`:
  - it adds a steal and returns `PurchaseGranted` once that's saved, otherwise `NotProcessedYet`;
  - if the buyer is mid-game, `ChessTable:grantSteal` gives it in that game at once and
    re-sends the snapshot.
- **At game start**, a human with an unspent steal gets it for that game (`stealFor`). Snapshots
  carry `steal = { w?, b? }`. Using it spends one (`onSteal` → `Wallet.spendSteal`). An unused
  steal is kept for the next game.

## In-game button (`Hud.lua`, left column above Draw)
- **No steal this game:** a gold **Steal** button (magnet icon) with a Robux price chip. It
  prompts the product; when the purchase lands, the client aims straight away (`ui.stealPending`).
- **Ready:** **Steal!**, which aims. Every stealable enemy piece glows; tap one, confirm
  ("Steal this knight? It becomes yours.").
- **Used:** the button hides.
- **Cutscene:** "STEAL!", a gold beam, the piece lifts, spins and settles, then it's redrawn in
  your colour.
- **New icon:** `steal` (a red magnet), in the Illustrator set.

## Tested
- **StealTests 8/8:**
  - nothing without a grant;
  - 14 targets, no king or queen;
  - once per game, and undo;
  - stealing the checker;
  - no help against a queen check;
  - a smothered mate stays mate without a grant, and isn't mate with one;
  - Abilities mode;
  - replays.
- AbilityTests 24/24, BotTests, perft and the rules tests all pass.
- **Studio (sandbox wallet, passes hidden):**
  - the Shop showed FREE · OWNED, coin and Robux buttons, and "Need … more coins";
  - buying Double Jump with coins: 600 → 350, OWNED, and the Robux button hid.
- **Classic game vs a bot:**
  - the Steal button showed the price;
  - a test receipt was granted mid-game, and the same receipt again did **not** add a second
    steal;
  - the button turned to Steal!, aiming lit the black pieces, and a click on g8 brought up the
    confirm;
  - the cutscene played; the move list read "Steal Ng8" (the bot answered Rxg8);
  - the wallet's steals went 1 → 0, and the button hid.
- **Console:** only Roblox's own UIBlox warnings.
- **Not checked:**
  - a real Robux purchase (the Studio purchase dialog wasn't clicked);
  - the Shop on a phone;
  - the robux icon on the Steal chip is grey on a dark chip; it reads, but a lighter chip may
    look better.

Stills: `stills/2026-10-18o-shop-robux.jpg`, `p-steal-button`, `q-steal-aim`, `r-steal-cutscene`.

Back to [[Home]]
