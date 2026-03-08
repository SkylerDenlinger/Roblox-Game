# Regular State

Regular owns its own state semantics on top of the shared state stack in `server/State`.

## Ownership
- `RegularStateController`
  - session-level lifecycle boundary for Regular
  - starts a Regular run and resets the mode back to idle
- `RegularRoundContext`
  - per-round state boundary used by the round runtime
  - translates phase events into leaderboard, progress, presentation, and player-state updates

## Lifecycle
1. `RegularSessionFlowController` starts a session.
2. `RegularStateController.BeginSessionRun()` stamps a new Regular run.
3. `RegularRoundContext:InitializeReplicatedState()` seeds round values before `Pregame`.
4. `Pregame`, `Gameplay`, and `Ending` mutate replicated state through the context and shared `StateReplicator`.
5. `RegularStateController.ResetToIdle()` clears the mode back to idle after the session ends.

## State Responsibilities
- qualification ordering
- fallback qualifier promotion
- spectate target ordering
- per-round placements and result modes
- phase presentation text for HUD/results flow

## Separation Rule
If a state rule only exists because the mode is `Regular`, it belongs here or in `RegularRoundContext`, not in `server/State`.

Future modes should mirror this shape:
- shared infra in `server/State`
- mode lifecycle in `Modes/<ModeName>/State`
- per-round or per-match state adapters owned by that mode
