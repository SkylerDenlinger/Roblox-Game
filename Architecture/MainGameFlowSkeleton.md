# Main Game Flow Skeleton

## Purpose
This document describes the top-level player flow of the game.

It is intentionally player-facing first:
- where the player can go
- how they move between top-level areas
- where the detailed mode skeletons take over

It does not describe the replicated backend state tree. That belongs in [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md).

## Top-Level Flow
```text
Main Menu
  -> Play
  -> Shop
  -> Training
  -> Tutorials

Play
  -> Regular Queue
  -> Ranked Queue
  -> future Private Server / Custom Game
  -> Return To Main Menu

Regular Queue
  -> matchmaking forms session
  -> Regular Game
  -> Cancel To Play

Ranked Queue
  -> matchmaking forms session
  -> Ranked Game
  -> Cancel To Play

Regular Game
  -> expands into RegularGameSkeleton

Ranked Game
  -> expands into RankedGameSkeleton

Training
  -> expands into TrainingSkeleton

Tutorials
  -> expands into TutorialSkeleton

Shop
  -> Return To Main Menu
```

## State Meanings

### Main Menu
The broad home state.

This is where the player can:
- enter `Play`
- open `Shop`
- enter `Training`
- enter `Tutorials`

### Play
The top-level mode-selection state.

This state exists to:
- separate "I want to play" from the rest of the main menu
- choose between public playable modes
- let queue commit happen directly without inventing a fake setup state

### Regular Queue
Committed public matchmaking for Regular.

This state means:
- the player or party has asked the server to find/form a Regular match
- matchmaking may form a session and hand off into the Regular runtime
- cancel returns to `Play`

### Ranked Queue
Committed public matchmaking for Ranked.

This follows the same top-level pattern as Regular, but its detailed runtime is intentionally left as a placeholder for now.

### Regular Game
The full Regular runtime.

This is not a single atomic state. It expands into:
- [RegularGameSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/RegularGameSkeleton.md)

### Ranked Game
The future Ranked runtime.

This should stay high-level until Ranked is actually designed and implemented.

### Training
A lightweight solo feature flow.

This expands into:
- [TrainingSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/TrainingSkeleton.md)

### Tutorials
A lightweight solo feature flow.

This expands into:
- [TutorialSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/TutorialSkeleton.md)

### Shop
A top-level feature destination.

For now, this remains a simple node in the main game flow rather than its own detailed skeleton.

## Party Rules
`Party` is cross-cutting and should be documented beside the main flow, not as its own destination node.

Party rules:
- party membership persists across `Main Menu`, `Shop`, `Training`, `Tutorials`, queues, and match entry
- party members may be in different activities while remaining in the same party
- the designated leader controls party matchmaking
- non-leader members may enter `Play`, but should not be able to start `Regular` or `Ranked` queue searches while they remain in that party
- the designated leader should be able to search from `Play` while other members are active in `Shop`, `Training`, or `Tutorials`

## Interrupt / Protection Rules
- `Training` is interruptible for party pull-in
- `Tutorials` is interruptible for party pull-in
- `ShopBrowsing` is interruptible for party pull-in
- `ShopTransactionPending` is protected
- if a member is in `ShopTransactionPending`, party queue commit should wait rather than auto-excluding that member

## What Is Not In This Document
- replicated state structure
- Regular round internals
- Ranked internals beyond placeholder ownership
- private server/custom game flow details

## Related Docs
- [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md)
- [RegularGameSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/RegularGameSkeleton.md)
- [RankedGameSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/RankedGameSkeleton.md)
- [TrainingSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/TrainingSkeleton.md)
- [TutorialSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/TutorialSkeleton.md)
