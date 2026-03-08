# Regular Game Skeleton

## Purpose
This document describes the internal lifecycle of the Regular mode.

Regular owns:
- queue handoff into a public session
- multi-round tournament progression
- phase flow inside each round
- qualification, elimination, and winner resolution
- Regular-specific meaning applied to shared replicated state

The shared backend state structure itself lives in [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md).

## Entry Point
```text
Play
  -> Regular Queue
  -> matchmaking forms session
  -> Regular Game
```

Regular begins only after:
- the player or party has entered `Regular Queue`
- matchmaking has formed a playable session

## Ownership Flow
```text
MatchmakerService
  -> RegularSessionManager
    -> RegularSessionFlowController
      -> RegularStateController
      -> RegularRoundRuntimeService
        -> PregamePhase
        -> GameplayPhase
        -> EndingPhase
      -> RegularRoundContext
```

## Session Skeleton
```text
Regular Queue
  -> Session Formed
  -> BeginSessionRun
  -> Round 1
  -> Round 2
  -> ...
  -> Winner Decided
  -> ResetToIdle
```

What the session owns:
- current entrants
- round path
- map history
- qualified players by round
- eliminated players by round
- final winner

## Round Skeleton
```text
Pregame
  SessionLobby
  MapSelect
  Runtime map load
  Spawn plan build
  IntroCutscene
  Countdown

Gameplay
  Collectathon
  Key collection
  Gear collection
  Door evaluation
  Qualification attempts
  Leaderboard refresh
  Timeout / fallback promotion

Ending
  RoundResults
  NextRoundTransition
  or
  WinnerCeremony
```

## Player Outcome Flow
Regular owns its own post-match outcomes inside the mode flow.

Possible player outcomes:
- `qualified`
  - advances to the next round
- `eliminated`
  - exits the tournament and sees the eliminated postgame flow
- `winner`
  - final-round winner sees the winner ceremony and winner postgame flow

Postgame is intentionally mode-owned and should not be represented as a top-level main-flow state.

## State Roles

### `RegularStateController`
Session-level lifecycle boundary for Regular.

Responsibilities:
- start a Regular run
- reset the mode back to idle after the session ends

### `RegularRoundContext`
Round-local state and bookkeeping boundary.

Responsibilities:
- seed round state before pregame
- build spawn plans
- track qualification order
- track per-player key and gear counts
- refresh leaderboard ordering
- choose fallback qualifiers on timeout
- apply placements and result modes
- publish presentation text and spectate targets

## Shared Tree Usage
Regular writes into the shared state tree like this:

- `Match`
  - current phase, round, timers, map identity, entrant counts
- `Progress`
  - required keys, qualifier counts, winner state, door state
- `Leaderboard`
  - authoritative standings and spectate order
- `Presentation`
  - HUD/result messaging and showcased collectibles
- `PlayerState/<UserId>`
  - round stats, qualification state, placement, elimination state

## Phase Responsibilities

### Pregame
Pregame owns:
- session lobby timing
- map selection
- runtime map loading
- spawn plan generation
- highlighted collectible presentation
- countdown into live play

### Gameplay
Gameplay owns:
- active collectibles
- key/gear pickup handling
- door access evaluation
- qualification attempts
- leaderboard refresh and spectate ordering
- timeout and fallback promotion behavior

### Ending
Ending owns:
- final round ordering for the round
- qualified vs eliminated resolution
- next-round transition
- winner ceremony in the final round

## File Map
Canonical files:
- [RegularSessionManager.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/Session/RegularSessionManager.lua)
- [RegularSessionFlowController.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/Session/RegularSessionFlowController.lua)
- [RegularStateController.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/State/RegularStateController.lua)
- [RegularRoundRuntimeService.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/RegularRoundRuntimeService.lua)
- [RegularRoundContext.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/RegularRoundContext.lua)
- [PregamePhase.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/Pregame/PregamePhase.lua)
- [GameplayPhase.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/Gameplay/GameplayPhase.lua)
- [EndingPhase.lua](/a:/Roblox/Roblox-Gamev2/Roblox-Game/src/server/Modes/Regular/Ending/EndingPhase.lua)

## Separation Rules
- matchmaking decides who enters the session, not who qualifies in-round
- shared state infrastructure publishes the data, but Regular decides what the data means
- pregame, gameplay, and ending should stay phase-owned
- session ownership should not leak into matchmaking
- postgame stays inside the Regular skeleton, not the main game flow

## Related Docs
- [MainGameFlowSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/MainGameFlowSkeleton.md)
- [SharedStateSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/SharedStateSkeleton.md)
