# Regular Session

Owns tournament/session progression across multiple rounds.

- `RegularSessionManager.lua`: pending-session registry and public session API.
- `RegularSessionFlowController.lua`: end-to-end Regular tournament loop.

This folder decides which round runs next. It should not own per-round collectible or presentation mechanics.
