# Ranked Game Skeleton

## Purpose
This is the placeholder architecture document for Ranked mode.

Ranked should eventually mirror the same broad separation used by Regular:
- queue entry
- session ownership
- mode-specific runtime flow
- mode-specific postgame flow
- mode-specific state semantics written into the shared state backbone

For now, Ranked is intentionally left high-level.

## Current Status
Ranked is not fleshed out yet.

This document exists to reserve the architectural boundary so Ranked does not get folded into Regular or into the shared state layer by accident.

## Expected Ownership Shape
```text
Play
  -> Ranked Queue
  -> matchmaking forms ranked session
  -> Ranked Game

Ranked Game
  -> mode-owned runtime
  -> mode-owned postgame
```

## Expected Boundaries
- shared infrastructure still lives in [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md)
- Ranked should get its own mode-owned state/controller boundary under `src/server/Modes/Ranked`
- Ranked should not be implemented by adding large `if mode == "Ranked"` branches to Regular logic

## Future Responsibilities
Ranked will likely need to own:
- ranked queue/session rules
- ranked scoring or placement rules
- ranked-specific result and progression screens
- ranked persistence or progression logic

## Canonical Folder
Reserved path:
- [src/server/Modes/Ranked](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Ranked)

## Related Docs
- [MainGameFlowSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/MainGameFlowSkeleton.md)
- [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md)
- [RegularGameSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/RegularGameSkeleton.md)
