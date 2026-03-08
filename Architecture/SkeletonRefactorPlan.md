# Skeleton Refactor Plan

## Goal
Refactor the current architecture docs into clearly separated skeletons:

1. `MainGameFlowSkeleton.md`
2. `SharedStateSkeleton.md`
3. `RegularGameSkeleton.md`
4. `RankedGameSkeleton.md`
5. `TrainingSkeleton.md`
6. `TutorialSkeleton.md`
7. future `PrivateServerSkeleton.md` if/when private custom game flow is formalized

The main intent is to stop mixing:
- top-level player flow
- shared backend/replicated state structure
- Regular-mode internals
- future Ranked-mode internals
- lightweight feature flows
- future private-server/custom-game flow

## Why This Refactor Makes Sense
Right now the current naming is overloaded:
- `MainStateSkeleton` sounds like the full game flow, but it is actually the shared backend state skeleton.
- `RegularModeStateSkeleton` is close to correct, but it only explains one mode and not how it fits into the larger game loop.

The cleaner split is:

### Main Game Flow
This should answer:
- Where can the player go?
- What are the top-level game states?
- How does the player move between menu, play, queue, games, and feature spaces?

### Shared State
This should answer:
- What replicated state exists for all modes?
- What state infrastructure is common regardless of mode?
- What is the shared contract between server and client?

### Regular Game
This should answer:
- What happens inside Regular once the player enters it?
- What are the session states, round states, and transitions?
- What state does Regular own on top of the shared layer?

### Ranked Game
This should answer:
- What should Ranked own later?
- How should Ranked parallel Regular structurally without sharing mode-specific logic?

### Training / Tutorials
These should answer:
- What lightweight feature flow exists here?
- How does the player enter, remain active, and exit?
- How do these interact with party presence?

## Proposed Document Responsibilities

### `MainGameFlowSkeleton.md`
Top-level player-facing and app-facing flow.

Proposed scope:
- Main Menu
- Play
- Regular Queue
- Ranked Queue
- future Private Server / Custom Game entry
- Regular Game
- Ranked Game
- Shop
- Training
- Tutorials
- note that `Party` is a cross-cutting social container, not a destination state

Proposed style:
- high-level state map
- transition arrows between screens/systems
- no deep replicated-tree details
- light notes where mode skeletons expand further

Candidate shape:
```text
Main Menu
  -> Play
  -> Shop
  -> Training
  -> Tutorials

Play
  -> Regular Queue
  -> Ranked Queue
  -> future Private Server / Custom Game
  -> Return To Menu

Regular Queue
  -> matchmaking forms session
  -> Regular Game
  -> Cancel To Play

Ranked Queue
  -> matchmaking forms session
  -> Ranked Game
  -> Cancel To Play

Regular Game
  -> expands into RegularGameSkeleton

Ranked Game
  -> expands into RankedGameSkeleton

Training
  -> expands into TrainingSkeleton

Tutorials
  -> expands into TutorialSkeleton

Shop
  -> Return To Main Menu
```

Cross-cutting note:
- `Party` persists across Main Menu, Shop, Training, Tutorials, Queues, and Match entry
- it should be documented beside the flow, not as a main destination node inside the flow diagram
- `Shop`, `Training`, and `Tutorials` can all be accessed while the player is in a party
- the designated party leader should be able to search for a game from `Play` while party members are active in Shop, Training, or Tutorials
- the skeletons should make clear that party membership persists even when party members are in different activities
- `Training` and `Tutorials` should be treated as interruptible for party pull-in
- `Shop` should be treated as interruptible while browsing, but protected while a purchase transaction is pending
- if a member is in `ShopTransactionPending`, party queue commit should wait rather than auto-excluding that member
- if needed later, a timeout-based leader override can be added, but the default should preserve the party together

### `SharedStateSkeleton.md`
Canonical shared backend state skeleton.

Proposed scope:
- `SessionStateController`
- `StateContract`
- `StateReplicator`
- `PlayerStateService`
- replicated tree under `ReplicatedStorage/State`

This document should not describe player navigation flow.

### `RegularGameSkeleton.md`
Canonical Regular-mode flow and Regular-owned state semantics.

Proposed scope:
- Regular queue handoff into Regular session
- session lifecycle
- round loop
- `Pregame -> Gameplay -> Ending`
- `RegularStateController`
- `RegularRoundContext`
- how Regular writes into shared state

### `RankedGameSkeleton.md`
Canonical placeholder for future Ranked mode.

Proposed scope:
- top-level ownership only
- expected queue/session/state boundaries
- expected relationship to shared state

This should stay intentionally high-level until Ranked implementation starts.

### `TrainingSkeleton.md`
Lightweight feature-flow skeleton for Training.

Proposed scope:
- entry from Main Menu or Party context
- active training state
- return path back out
- note that training runtime is solo-only even if party membership persists socially

This should stay small and should not be treated like a full match/session architecture doc.

### `TutorialSkeleton.md`
Lightweight feature-flow skeleton for Tutorials.

Proposed scope:
- entry from Main Menu or Party context
- tutorial selection or tutorial start
- active tutorial state
- completion / exit path
- note that tutorials runtime is solo-only even if party membership persists socially

This should stay small and should not be treated like a full match/session architecture doc.

### future `PrivateServerSkeleton.md`
Future skeleton for paid private-server / custom-game flow.

Proposed scope:
- acquisition / ownership of a private server
- entry into private/custom game creation flow
- private server session creation
- how party members enter private games
- relationship to shared state and reusable mode/runtime pieces

This should not be written yet as a full doc until the flow is defined more concretely.

## Proposed Naming Rules
- Use `GameFlow` when the document is about player/app movement between major areas.
- Use `StateSkeleton` when the document is about shared backend/replicated structure.
- Use `<ModeName>GameSkeleton` when the document is about one mode’s internal lifecycle.
- Use lightweight feature skeleton names for smaller activity flows.

That gives us:
- `MainGameFlowSkeleton.md`
- `SharedStateSkeleton.md`
- `RegularGameSkeleton.md`
- `RankedGameSkeleton.md`
- `TrainingSkeleton.md`
- `TutorialSkeleton.md`
- future `PrivateServerSkeleton.md`

## Proposed Migration Plan

### Phase 1: Establish Correct Roles
- Create `MainGameFlowSkeleton.md`
- Replace the current `MainStateSkeleton.md` with `SharedStateSkeleton.md`
- Replace or rename `RegularModeStateSkeleton.md` to `RegularGameSkeleton.md`
- Create `RankedGameSkeleton.md`
- Create lightweight `TrainingSkeleton.md`
- Create lightweight `TutorialSkeleton.md`
- note future `PrivateServerSkeleton.md` as a later expansion point

### Phase 2: Rewrite By Responsibility
- Remove top-level menu/navigation language from the shared state doc
- Keep shared-state docs focused on infrastructure and replicated structure
- Keep mode docs focused on queue/session/round ownership and transitions
- Keep training/tutorial docs lightweight and feature-scoped

### Phase 3: Align With Current Code
- Make sure each document references the actual canonical folders:
  - `src/server/State`
  - `src/server/Modes/Regular`
  - `src/server/Modes/Ranked`
  - `src/shared`
- Avoid documenting legacy shim paths

### Phase 4: Cross-Link The Skeletons
- `MainGameFlowSkeleton.md` should point into the mode skeletons
- `MainGameFlowSkeleton.md` can lightly point to `TrainingSkeleton.md` and `TutorialSkeleton.md`
- `RegularGameSkeleton.md` and `RankedGameSkeleton.md` should point into `SharedStateSkeleton.md`
- `SharedStateSkeleton.md` should stay mode-agnostic and link outward instead of inward

## Suggested Final Architecture Folder
```text
Architecture/
  MainGameFlowSkeleton.md
  SharedStateSkeleton.md
  RegularGameSkeleton.md
  RankedGameSkeleton.md
  TrainingSkeleton.md
  TutorialSkeleton.md
  SkeletonRefactorPlan.md
```

## Decisions Locked In

### 1. `Play` is a real top-level state
- it owns mode selection before the player enters a mode-specific queue

### 2. No separate pre-queue lobby/setup state is needed right now
- players can queue directly from `Play`
- solo players can queue themselves
- party matchmaking is leader-authoritative

### 3. Queue should be split by mode
- use `Regular Queue` and `Ranked Queue`

### 4. Party is cross-cutting, not a destination state
- party membership persists across multiple activities
- party members may be in different activities while staying in the same party
- non-leader party members may enter `Play`, but should be prohibited from starting `Regular` or `Ranked` queue searches while they remain in that party

### 5. Party leader can queue while members are elsewhere
- the designated leader should be able to start search from `Play`
- other members can still be in Shop, Training, or Tutorials

### 6. Interrupt / protection rules
- `Training` is interruptible
- `Tutorials` is interruptible
- `ShopBrowsing` is interruptible
- `ShopTransactionPending` is protected
- protected shop purchase states should temporarily block party queue commit rather than auto-excluding that member

### 7. Postgame stays inside mode skeletons
- do not make postgame a top-level main-flow state
- Regular and Ranked each own their own end-of-match flow

### 8. `Shop`, `Training`, and `Tutorials`
- `Training` gets a lightweight skeleton
- `Tutorials` gets a lightweight skeleton
- `Shop` stays a simple top-level node for now

### 9. Training is solo
- training should be treated as a solo runtime activity
- party membership may persist socially while a player is in training
- training should not imply shared spatial/runtime presence with party members

### 10. Tutorials are solo
- tutorials should be treated as a solo runtime activity
- party membership may persist socially while a player is in tutorials
- tutorials should not imply shared spatial/runtime presence with party members

### 11. Private server / custom game should exist later
- the architecture should leave room for a paid private-server/custom-game flow
- this should eventually become its own skeleton because it is distinct from public queue-based matchmaking

## Open Questions
These are the main unresolved things before I rewrite the actual skeleton files.

### 1. Ranked placeholder depth
Decision:
- `RankedGameSkeleton.md` should remain a placeholder for now
- keep it intentionally high-level until Ranked implementation actually starts

### 2. Training party behavior detail
Decision:
- training is solo-only from a runtime perspective
- party relationship persists socially, not spatially

### 3. Tutorial party behavior detail
Decision:
- tutorials are solo-only from a runtime perspective
- party relationship persists socially, not spatially

## My Recommendation
Yes, we should do this.

The separation should be:
- `MainGameFlowSkeleton`
  - top-level game/app loop
- `SharedStateSkeleton`
  - common backend state backbone
- `RegularGameSkeleton`
  - actual Regular mode lifecycle
- `RankedGameSkeleton`
  - future mirror of Regular at the architecture level
- `TrainingSkeleton`
  - lightweight feature-flow outline
- `TutorialSkeleton`
  - lightweight feature-flow outline
- future `PrivateServerSkeleton`
  - paid private/custom game flow once defined

## Space For Corrections
Use this section to mark anything you want changed before I rewrite the actual skeleton files.

### User Notes
- 
- 
- 
