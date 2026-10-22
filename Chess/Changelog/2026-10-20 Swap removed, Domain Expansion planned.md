---
tags: [changelog, abilities, queen, cutscenes]
---
# Swap removed, Domain Expansion planned (2026-10-20)

**The user's brief:** "I think we should scrap the swap ability, I want to make a queen domain
expansion ability, but make it not available yet in the shop." Then: "Remove swap, ask me questions
about domain expansion rules, write in vault. We will not do the domain expansion yet, work on lobby
first. Write down the cutscene treatment in vault so future agents can make cutscenes easier."

## Swap is gone from play
| Where | Change |
|---|---|
| `Shared/Shop.lua` | The Swap entry is removed, so it's not sold (coins or gamepass) |
| `Shared/Modes/Abilities.lua` | It's out of `Abilities.list`, so it's not offered to players or the bot. Its charge starts at 0, and it's dropped from the position key |
| `AbilityBar.lua` | The queen card is removed. The bar has 5 cards, and the number keys 1–5 follow them |
| `ChessClient.client.lua` | The Swap aiming marks are removed |
| `Cutscene.lua` | The old 2.6 s Swap scene, its `SWAP` title and the now-unused `shot` helper are removed |
| `AbilityDemo.lua` | The Swap demo in the Shop's detail view is removed |
| `Settings.lua` | `CUTSCENES.QueenSwap` is removed |
| `Tests/AbilityTests.lua`, `StealTests.lua` | The Swap tests are replaced. "once per game" now uses Royal Escape, and the Steal test counts `#Abilities.list` instead of 6 |

**Kept on purpose:**
- `Shared/Abilities/QueenSwap.lua` stays as a **retired** module, still registered in
  `Abilities.byId`.
- `Abilities.prepareReplay` gives a swap back to whoever used one, so **games saved before today
  still replay** (VIP saved reviews).
- The review's purple swap mark and the "Swap" name in PGN stay for those old games.
- A new test checks that Swap is never offered and an old saved game with a swap still replays.

**Tests:** AbilityTests, StealTests and BotTests all pass in Studio (Chess??), and `luau_check` is
clean. The Shop and the 5-card ability bar haven't been looked at in a playtest yet.

**For the user:**
- Take the **Swap gamepass (2036241682)** off sale on the Creator Dashboard. Per the user, nobody
  owns it yet.
- Publish Chess??. The Tournament place needs the same push.

## Domain Expansion
The user answered the rules: queen's realm, the whole board, cast uses the turn, then the queen may
teleport and capture on your next 2 moves, never the king, normal counterplay.

The rules, the agent's open questions and a cutscene draft are in [[Design/Domain Expansion]]. It
isn't built, and must stay out of the Shop when it is.

## Cutscene treatment written down
[[Design/Cutscene Treatment]] is the recipe for future agents, covering:
- the beat structure;
- the scene skeleton;
- every helper;
- the camera rules learned from bad frames;
- sound;
- the Blender prop route;
- the Studio test and frame-capture flow;
- the finish checklist.

Back to [[Home]]
