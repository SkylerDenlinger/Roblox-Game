# Regular

Regular mode is organized by ownership and round timing.

- `State/`: Regular-owned state entrypoints and schema boundaries.
- `Session/`: tournament/session ownership across multiple rounds.
- `Pregame/`: map selection, runtime map loading, spawn planning, intro setup.
- `Gameplay/`: collectibles, qualification, doors, leaderboard logic.
- `Ending/`: result assembly, advancement, and winner ceremony.
- `RegularRoundRuntimeService`: round orchestrator that runs `Pregame -> Gameplay -> Ending`.
- `RegularRoundContext`: per-round state and bookkeeping boundary shared across those phases.

The legacy `Services/RoundRuntimeService.lua` path remains as a compatibility shim only.
