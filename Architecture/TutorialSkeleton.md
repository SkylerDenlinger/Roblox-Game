# Tutorial Skeleton

## Purpose
This document describes the lightweight flow for Tutorials.

Tutorials are a feature flow, not a full public matchmaking mode.

## Runtime Rule
Tutorials are solo-only from a runtime perspective.

That means:
- the player may remain socially in a party
- the player is not spatially or runtime-linked to party members while in tutorials

## Flow
```text
Main Menu
  -> Tutorials

Tutorials
  -> Tutorial Select / Start
  -> Active Tutorial
  -> Complete Or Exit
  -> Return To Main Menu
```

## Party Behavior
Party membership may persist while a player is in tutorials.

Important rules:
- tutorial runtime is solo
- tutorials are interruptible for party pull-in
- if the designated party leader starts public matchmaking from `Play`, a tutorial player can be pulled out of tutorials into the party queue flow

## What This Doc Does Not Cover
- public queue/session creation
- shared replicated state internals
- mode-specific match logic

## Related Docs
- [MainGameFlowSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/MainGameFlowSkeleton.md)
- [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md)
