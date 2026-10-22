---
tags: [core]
---
# Goal

A chess game with more than one game mode:

- **Classic**: standard chess, every rule ([[Design/Classic Mode]]).
- **Abilities**: chess where pieces or players have special abilities. **The user will tell the
  next agent what the abilities are.** Don't invent them: build the ability *system* so they can be
  dropped in ([[Design/Abilities Mode]]).

More modes may follow, so modes are data + rule hooks, not forks of the code.

## Assumed platform (confirm first)
Roblox, built the same way as the user's other game, Descent Depths:
- the group **The Depths Studio** owns it;
- Luau code in `src/`, pushed into Studio by `push.py`;
- Studio driven through the Roblox Studio MCP.

See [[Open Questions]].

## Standing rules (from the user, carried over from Descent Depths)
- **Console support is required**: everything works with a controller, and phone touch too. No
  keyboard-only actions.
- **No z-fighting**: no coplanar overlapping faces in any build (board squares, borders, pieces).
- **No pirated plugins.**
- **Review artifacts:** send small stills, not full video renders. Send files with SendUserFile;
  publish finished write-ups as Artifacts.
- **Asset ownership:** publish animations, sounds and images under **The Depths Studio** group, or
  give the experience permission. A personal upload silently fails to load in a group game.
- Be efficient with tool calls; the user has hit weekly usage limits before.

Back to [[Home]]
