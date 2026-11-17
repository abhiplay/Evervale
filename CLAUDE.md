# Evervale — Project Instructions

Evervale is a 2D illustrated exploration/adventure game. Its visual direction is inspired
by the detailed illustrated presentation of The Genesis Order, while its characters,
story, environments, assets, and identity must remain original.

The intended environment approach is hybrid:
- illustrated/pre-rendered backgrounds for static architectural detail;
- independent scene objects for furniture, doors, props, collectibles, and interactions;
- independently controlled player, collision, triggers, dialogue, and gameplay systems.

## Non-negotiable workflow

1. Inspect before editing. Read the relevant scene, scripts, resources, project settings,
   and nearby conventions before proposing a change.
2. Preserve the existing project. Do not replace the engine, restructure folders, migrate
   systems, or rewrite working features unless explicitly requested and justified.
3. Establish facts. Read `project.godot` and relevant files to determine the actual Godot
   version, renderer, input map, scene architecture, and coding conventions. Never guess.
4. Make the smallest safe change that solves the stated problem.
5. Keep changes scoped. Do not modify unrelated rooms, assets, scripts, or settings.
6. Verify. Run available headless/editor checks and relevant automated tests. If visual
   behavior cannot be verified automatically, say so and provide a precise manual test.
7. Report honestly. Separate what was changed, what was tested, what passed, and what
   remains unverified.

## Spatial and gameplay quality

- A room must have clear walkable routes between its intended entrances and interactable areas.
- Furniture and decorative art must not accidentally block required player paths.
- Collision geometry must represent gameplay boundaries, not blindly copy every visible pixel.
- Door transitions must have explicit entry/exit positions and preserve intended player state.
- Foreground occlusion and Y-sorting must be intentional and tested from relevant player positions.
- Interactive objects must have clear activation rules and feedback.
- Room and floor connections must be represented consistently rather than inferred from filenames.

## Art direction

Maintain a cohesive illustrated 2D look:
- consistent perspective within a room;
- consistent scale between characters, doors, furniture, and props;
- coherent lighting, shadows, palette, and line/detail treatment;
- deliberate depth layers and occlusion;
- original Evervale assets and characters.

Do not copy The Genesis Order's proprietary artwork, characters, story, UI, or assets. Use it only
as a high-level reference for illustrated presentation and adventure-game structure.

## Source of truth

Before changing design or architecture, consult:
- `docs/EVERVALE_MASTER.md`
- `docs/TECHNICAL_BASELINE.md`
- any existing room plans, asset guides, and technical documentation in the repository.

If documentation conflicts with the running project, report the conflict. Do not silently
force the project to match outdated documentation.
