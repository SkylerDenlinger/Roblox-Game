# Shared State Skeleton

## Purpose
This is the shared state backbone used by every game mode.

The rule is simple:
- `server/State` owns the replicated state infrastructure.
- `Modes/<ModeName>/State` owns the mode-specific meaning of that state.

## Ownership Flow
```text
Bootstrap
  -> SessionStateController
    -> StateContract
    -> StateReplicator
    -> PlayerStateService
  -> Modes/<ModeName>/State
```

## Shared Replicated Tree
```text
ReplicatedStorage
  State
    Match
      Phase
      Mode
      RunId
      SessionId
      RoundIndex
      RoundId
      EntrantCount
      RoundTargetQualifiers
      TimerVersion
      PhaseStartServerTime
      PhaseDuration
      PhaseEndsServerTime
      CurrentMapId
      CurrentMapName
      NextMapId
      NextMapName

    Progress
      RequiredKeys
      WinnerUserId
      DoorState
      QualifyCount
      QualifiedCount
      EscapedCount
      RemainingQualifierSlots

    Leaderboard
      UpdatedAt
      Entries
        <Rank>
          Rank
          UserId
          DisplayName
          Keys
          Gears
          Qualified
          IsOnline
          QualifiedAtServerTime
          FirstKeyAtServerTime

    Presentation
      Phase
      ResultsMode
      PrimaryText
      SecondaryText
      Message
      SpectateTargetUserId
      SpectateTargetName
      UpdatedAt
      ShowcasedCollectibles
        <Index>

    PlayerState
      <UserId>
        Keys
        Gears
        Thrust
        Qualified
        QualifiedAtServerTime
        Placement
        ResultMode
        Eliminated
        LastRoundKeys
        LastRoundGears
        SpecialMoves
          Move1Ready
          Move2Ready
```

## Shared Responsibilities
- `StateContract`
  - creates and validates the tree
- `StateReplicator`
  - writes authoritative values into the tree
- `PlayerStateService`
  - manages per-player replicated values
- `SessionStateController`
  - starts shared state once during bootstrap

## Boundaries
- Shared state should own structure, not mode rules.
- Shared state should not contain Regular-specific or Ranked-specific branching logic.
- Modes should write through their own controllers and contexts instead of expanding the shared API with mode-only behavior.

## Extension Pattern
```text
server/State
  shared transport + replicated tree

server/Modes/Regular/State
  Regular lifecycle + Regular state semantics

server/Modes/Ranked/State
  Ranked lifecycle + Ranked state semantics
```

## Mental Model
Think of `server/State` as the common state bus.
Think of each mode state folder as the translator that gives that bus mode-specific meaning.

## Related Docs
- [MainGameFlowSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/MainGameFlowSkeleton.md)
- [RegularGameSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/RegularGameSkeleton.md)
- [RankedGameSkeleton.md](/a:/Roblox/Roblox-Gamev2/Roblox-Game/Architecture/RankedGameSkeleton.md)
