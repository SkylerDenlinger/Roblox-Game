# Mode And State Architecture Plan

## Summary
The codebase should read as a pipeline:

`Bootstrap -> Social -> Matchmaking -> State -> Modes/<ModeName>`

Shared infrastructure owns transport, replication, and lifecycle primitives.
Each mode owns its own session flow, phase logic, and mode-specific state shaping.
Regular is the canonical implementation today. Ranked should follow the same structure later rather than extending Regular with conditionals.

## Canonical Ownership

### `src/server/Bootstrap`
- Composes the runtime once.
- Wires shared infrastructure before any mode logic runs.

### `src/server/Social`
- Party and social coordination only.
- Must not know round phases, collectibles, or winners.

### `src/server/Matchmaking`
- Owns queueing, target sizing, fallback formation, and session creation.
- Stops at `session formed`.
- Must not know doors, collectibles, cutscenes, or spectate presentation.

### `src/server/State`
- Owns replicated state infrastructure shared by all modes.
- Defines the replicated tree, remote contract setup, and per-player replicated folders.
- Does not contain mode rules.

### `src/server/Modes/Regular`
- Owns the full Regular tournament.
- `Session/` decides which round runs next.
- `Pregame/` owns map selection, runtime map loading, spawn planning, and countdown setup.
- `Gameplay/` owns collectibles, leaderboard ordering, qualification, and exit-door access.
- `Ending/` owns round results, advancement, and winner presentation.
- `State/` owns Regular lifecycle transitions and Regular-specific state semantics.

### `src/shared`
- `Config/` is the canonical home for tuning and templates.
- `Contracts/` is the canonical home for payload/schema definitions.
- `Content/` is the canonical home for map/content manifests.
- Root shared files are compatibility shims only.

## State Architecture

### Shared State Layer
Shared state infrastructure exists once and is mode-agnostic.

- `SessionStateController`
  - Starts `StateContract`, `StateReplicator`, and `PlayerStateService`.
  - Is the shared entrypoint every mode depends on.
- `StateContract`
  - Creates and validates the replicated folder/value tree under `ReplicatedStorage`.
- `StateReplicator`
  - Writes authoritative server state into the replicated tree.
  - Owns projection, not business rules.
- `PlayerStateService`
  - Owns per-player replicated folders and common per-player value helpers.

### Mode State Layer
Each mode gets its own state controller and round/session state shaping.

- `RegularStateController`
  - Starts a Regular run.
  - Resets Regular back to idle after a session completes.
- `RegularRoundContext`
  - Bridges Regular phase logic to replicated state during one round.
  - Owns spawn plans, leaderboard refreshes, qualification ordering, placements, and presentation updates for that round.
- Future `RankedStateController`
  - Should follow the same pattern without modifying Regular logic.

### Replicated Tree
The shared tree is stable and mode-safe:

- `State/Match`
  - universal run and round metadata
  - phase, mode, session id, round id, map ids, timers, entrant counts
- `State/Progress`
  - universal round outcome counters
  - required keys, qualified count, escaped count, remaining slots, winner id, door state
- `State/Leaderboard`
  - ordered round standings and spectate ordering
- `State/Presentation`
  - UI-facing phase and result presentation
  - primary/secondary text, message, showcased collectibles, spectate target
- `State/PlayerState/<UserId>`
  - per-player replicated round data
  - keys, gears, qualified, placement, result mode, elimination state, last-round stats

## Regular Runtime Flow
1. `ServerBootstrap` starts shared state infrastructure.
2. `MatchmakerService` forms a session.
3. `RegularSessionManager` accepts the session and delegates execution to `RegularSessionFlowController`.
4. `RegularSessionFlowController` resolves the tournament path and loops rounds until a winner exists.
5. `RegularRoundRuntimeService` runs:
   - `PregamePhase`
   - `GameplayPhase`
   - `EndingPhase`
6. `RegularRoundContext` updates leaderboard, progress, presentation, and player placements during the round.
7. `RegularStateController.ResetToIdle()` returns the mode to idle when the session ends.

## Clarity Rules
- Shared state infrastructure must not branch on mode behavior.
- Mode logic must not live in `server/State`.
- Matchmaking must stop at `session formed`.
- Phase folders should answer `when does this run?`
- Mode state folders should answer `who owns this state?`
- Legacy `Services/` and shared root files are compatibility shims only and should not receive new logic.

## Next Steps
1. Mirror the same folder and controller pattern for `Modes/Ranked`.
2. Split client Regular UI into `Pregame`, `Gameplay`, and `Ending` folders to match the server flow.
3. Delete legacy shims only after all references move to canonical folders.
