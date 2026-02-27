# Core Architecture Plan for Launch Public Mode

## Summary
Build a server-authoritative, modular tournament system that supports your launch mode (dynamic queue sizing, elimination rounds, keys/gears gameplay) with a hybrid deployment strategy: interfaces support full multi-place scale, while early development can still run in a single-place topology.

## Architecture Blueprint
1. **Single bootstrap composition root**
Create one startup script (`Main.server.lua`) that wires services in order and removes duplicate boot paths (`Start.server.lua` / legacy overlap).  
Order: `StateContract -> Config -> Party -> QueueGateway -> Matchmaker -> SessionManager -> RoundRuntime -> StateReplicator`.

2. **Shared contracts and config layer (`src/shared`)**
Add shared modules for strict contracts and tuning data:
- `QueueBands`: `1-40=>6`, `41-100=>12`, `101-500=>25`, `501+=>50`.
- `TournamentTemplates`: `50->25->12->6->1`, `25->12->6->1`, `12->6->1`, `6->1`.
- `RoundRules`: phase durations, key/gear spawn counts, required keys.
- `RemoteSchemas`: payload shapes for lobby/party/match state.
- `FeatureFlags`: `queue_backend=local|memory_store`, `session_transport=in_server|teleport`.

3. **Domain modules (server)**
Implement clear service boundaries:
- `PartyService`: party lifecycle only.
- `QueueService`: ticketing, cancel, queue population counting, policy lookup.
- `MatchmakerService`: consumes queue tickets, forms lobby groups at dynamic target size, emits `SessionCreated`.
- `TournamentPlanner`: creates round plan from starting lobby size.
- `SessionManager`: owns tournament session lifecycle and entrants across rounds.
- `RoundRuntimeService`: executes one round phases and returns qualifier list.
- `GameplayServices`: key spawn/collect, gear spawn/collect, exit-door gating, qualification-zone checks.
- `StateReplicator`: projects authoritative domain state into `ReplicatedStorage.State` and sends remote snapshots.

4. **Adapters for hybrid topology**
Use interfaces so core logic is deployment-agnostic:
- `QueueBackendAdapter`: `LocalQueueAdapter` (dev) and `MemoryStoreQueueAdapter` (prod universe-wide).
- `SessionTransportAdapter`: `InServerSessionAdapter` (dev) and `TeleportSessionAdapter` (reserved servers).
- `PersistenceAdapter`: stubbed for launch public mode, extensible for ranked/MMR later.

5. **Round and qualification behavior (locked decisions)**
- Timer timeout ends the round immediately.
- Qualifier contention uses first authoritative server timestamp.
- If timeout ends with zero qualifiers, apply deterministic fallback promotion: highest keys, then earliest key timestamp, then lowest userId.
- Final round winner is first valid qualifier in `6->1`.

6. **Map/gameplay runtime contract**
Define `MapManifest` per map:
- `spawnZones`, `keySpawnPoints`, `gearSpawnPoints`, `exitDoor`, `qualificationZone`, `introCutsceneNodes`.
Round runtime consumes only this manifest; no hardcoded workspace names outside manifest loader.

## Public API / Interface Changes
1. **Keep existing remotes for compatibility**
Keep `PartyGetState`, `PartyInvite`, `PartyRespondInvite`, `PartyLeave`, `PartyUpdated`, `PartyMessage`, `LobbyGetState`, `LobbyCommand`, `LobbyUpdated`, `LobbyMessage`.

2. **Extend lobby snapshot schema**
`LobbyGetState`/`LobbyUpdated` payload adds:
- `queuePopulation`
- `targetLobbySize`
- `tournamentPath` (example `[25,12,6,1]`)
- `estimatedRounds`
- `sessionId` when formed

3. **State tree additions**
Extend `ReplicatedStorage/State` minimally:
- `Match`: `SessionId`, `EntrantCount`, `RoundTargetQualifiers`.
- `Progress`: `EscapedCount`, `RemainingQualifierSlots`.
- `PlayerState/<UserId>`: `Qualified` (Bool), `QualifiedAtServerTime` (Number), keep `Keys`, `Gears`, `Thrust`.

4. **Internal service interfaces**
Define explicit methods:
- `QueueService.JoinPublic(leaderUserId, memberUserIds) -> Result`
- `QueueService.Cancel(leaderUserId) -> Result`
- `MatchmakerService.Tick(now) -> {formedSessions}`
- `SessionManager.StartSession(sessionSpec)`
- `RoundRuntimeService.RunRound(sessionId, roundSpec) -> RoundResult`

## Implementation Plan (decision-complete)
1. **Phase 1: Foundation**
Unify bootstrap, remove duplicate startup paths, move constants into shared config, keep current behavior stable.

2. **Phase 2: Contracts + state projection**
Add shared schemas/config and a dedicated `StateReplicator`; migrate direct service writes to domain-state then projection.

3. **Phase 3: Queue + matchmaker**
Refactor `LobbyService` into `QueueService` + `MatchmakerService`; implement queue bands and tournament planner output.

4. **Phase 4: Session + round runtime**
Introduce `SessionManager` and `RoundRuntimeService`; port existing round/door/qualification logic under round runtime hooks.

5. **Phase 5: Gears as first-class collectible**
Split collectibles into `KeyCollectibleService` and `GearCollectibleService`; gears increment `PlayerState.Gears` and feed movement unlock path.

6. **Phase 6: Global queue adapter**
Implement `MemoryStoreQueueAdapter` with lock-safe pop/form behavior; keep `LocalQueueAdapter` for Studio testing.

7. **Phase 7: Teleport adapter (optional in staged rollout)**
Add reserved-server transport path; keep in-server adapter as fallback until stable.

8. **Phase 8: Hardening**
Add telemetry events (`queue_joined`, `session_created`, `round_ended`, `player_qualified`, `session_winner`) and fail-safe recovery on server shutdowns.

## Test Cases and Scenarios
1. Queue band mapping boundaries: `40->6`, `41->12`, `100->12`, `101->25`, `500->25`, `501->50`.
2. Tournament plan generation for start sizes `6`, `12`, `25`, `50`.
3. Party queue join/cancel with leader-only constraints.
4. Deterministic tie-break on last qualifier slot using server timestamp.
5. Timeout round ending with partial qualifiers and with zero qualifiers fallback.
6. Gear collection increments `Gears` and updates thrust unlock behavior.
7. Exit door gating requires per-player required keys; one player opening does not globally open for others.
8. State replication consistency between domain state and `ReplicatedStorage/State`.
9. Matchmaker concurrency safety under simultaneous queue joins/cancels.
10. Adapter parity tests: local queue backend vs memory-store backend return identical session specs for same input stream.
11. End-to-end tournament run: `25` entrants funnels to one winner through expected round path.
12. Client compatibility test: existing homepage lobby/party UI still functions with extended payloads.

## Assumptions and Defaults Chosen
1. Launch-critical scope is Public/Regular mode; Ranked is interface-ready but not implemented now.
2. Queue sizing is universe-wide in production (MemoryStore-backed), local fallback in dev.
3. Hybrid staged topology is the target: architecture supports multi-place, development can run single-place.
4. Queue bands are fixed to `1-40`, `41-100`, `101-500`, `501+`.
5. Timeout ends round immediately; no auto-extension.
6. Tie-break is authoritative server timestamp.
7. If no qualifiers on timeout, deterministic fallback promotion applies.
8. Current party capacity remains unchanged unless product decision updates it later.
