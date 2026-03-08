# Training Skeleton

## Purpose
This document describes the lightweight flow for Training.

Training is a feature flow, not a full public matchmaking mode.

## Runtime Rule
Training is solo-only from a runtime perspective.

That means:
- the player may remain socially in a party
- the player is not spatially or runtime-linked to party members while in training

## Flow
```text
Main Menu
  -> Training

Training
  -> Active Training
  -> Exit To Main Menu
```

## Party Behavior
Party membership may persist while a player is in training.

Important rules:
- training runtime is solo
- training is interruptible for party pull-in
- if the designated party leader starts public matchmaking from `Play`, a training player can be pulled out of training into the party queue flow

## What This Doc Does Not Cover
- public queue/session creation
- shared replicated state internals
- mode-specific match logic

## Related Docs
- [MainGameFlowSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/MainGameFlowSkeleton.md)
- [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md)
