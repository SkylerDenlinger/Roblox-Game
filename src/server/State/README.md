# State

This folder owns shared state infrastructure for every mode.

## Ownership
- `SessionStateController`
  - Starts the shared state stack once during bootstrap.
- `StateContract`
  - Defines the replicated tree and remotes under `ReplicatedStorage`.
- `StateReplicator`
  - Projects authoritative server values into that tree.
- `PlayerStateService`
  - Owns per-player replicated folders and common player-state helpers.

## What Belongs Here
- run/session/round fields that every mode can use
- replicated timer fields
- generic leaderboard/presentation containers
- shared per-player replicated values

## What Does Not Belong Here
- Regular-specific qualification rules
- Ranked-specific scoring or placement rules
- phase flow logic
- map/gameplay mechanics

## Replicated Tree
- `State/Match`
  - mode, phase, session id, round id, timers, entrant counts, current/next map
- `State/Progress`
  - required keys, qualified count, escaped count, remaining slots, winner id, door state
- `State/Leaderboard`
  - ordered round standings used by HUD and spectate flows
- `State/Presentation`
  - UI-facing phase/result text plus showcased collectible ids and spectate target
- `State/PlayerState/<UserId>`
  - keys, gears, qualification, placement, result mode, elimination, last-round stats

## Mode Boundary
Mode-specific shaping belongs under `Modes/<ModeName>/State`.

For Regular, the shared stack is consumed by:
- `RegularStateController` for session lifecycle transitions
- `RegularRoundContext` for per-round projection into the shared state tree
