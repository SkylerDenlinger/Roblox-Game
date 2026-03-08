# Matchmaking

Owns everything up to "a playable session has formed."

- `QueueService`: queue membership, target sizing, fallback formation rules.
- `QueueGatewayService`: remote-facing queue/lobby commands.
- `MatchmakerService`: polling loop that turns queue state into session specs.
- `TournamentPlanner`: target lobby sizing and tournament path lookup.
- `Adapters/`: queue/session/persistence backends.

This folder should not know about collectibles, cutscenes, doors, or winner presentation.
Legacy files under `server/Services/` are compatibility shims only.
