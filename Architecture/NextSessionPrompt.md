# Next Session Prompt

Continue work on this Roblox game repo from the current architecture/state refactor.

First, read these files for context:
- `PROJECT_CONTEXT.txt`
- `PLAN.md`
- `Architecture/SkeletonRefactorPlan.md`
- `Architecture/MainGameFlowSkeleton.md`
- `Architecture/SharedStateSkeleton.md`
- `Architecture/RegularGameSkeleton.md`
- `Architecture/RankedGameSkeleton.md`
- `Architecture/TrainingSkeleton.md`
- `Architecture/TutorialSkeleton.md`

Treat the Architecture docs as the current source of truth.

## Important Locked Decisions
- `Play` is a real top-level state.
- No separate pre-queue lobby/setup state for now.
- Players queue directly from `Play`.
- Queue is split by mode: `Regular Queue` and `Ranked Queue`.
- `Ranked` stays a placeholder for now.
- `Training` and `Tutorials` are solo-only runtime activities.
- Party is cross-cutting and persists across menu/shop/training/tutorials/queue.
- Party matchmaking is leader-authoritative.
- Non-leader party members may enter `Play` but cannot start `Regular` or `Ranked` queue searches.
- Party leader can start queue from `Play` while members are in `Shop`, `Training`, or `Tutorials`.
- `Training` and `Tutorials` are interruptible for party pull-in.
- `ShopBrowsing` is interruptible.
- `ShopTransactionPending` is protected and should block party queue commit temporarily instead of excluding the member.
- Postgame stays inside mode-specific skeletons, not the top-level flow.
- Future private/custom server flow should remain only a placeholder unless explicitly requested.

## What To Do Next
1. Give a short summary of the current architecture and the most logical next implementation slice.
2. Identify the exact files/modules that need to change for that slice.
3. Begin implementation directly unless something is genuinely ambiguous or risky.
4. Preserve the canonical folder structure and avoid reviving legacy `Services` paths.
5. Validate changes and summarize results clearly.

## Default Expectation
- prioritize clean architecture and separation of concerns
- keep party/queue/runtime behavior aligned with the Architecture docs
- if you need to make a new architectural choice, call it out explicitly before coding
