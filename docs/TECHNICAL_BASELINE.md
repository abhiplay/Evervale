# Evervale — Technical Baseline (To Be Verified)

This document intentionally distinguishes intended direction from confirmed implementation.
Claude must inspect the repository and fill in the verified values before proposing major
technical changes.

## Verify from the project

| Area | Current verified value |
|---|---|
| Godot version | To be inspected from project configuration / project metadata |
| Scripting language | To be inspected |
| Renderer | To be inspected from project settings |
| Main scene | To be inspected |
| Player scene and controller | To be inspected |
| Room scene convention | To be inspected |
| Room transition system | To be inspected |
| Collision approach | To be inspected |
| Sorting / occlusion approach | To be inspected |
| Input actions | To be inspected |
| Save/load implementation | To be inspected |
| Automated tests | To be inspected |

## Godot 4 guidance (apply only if the project is confirmed to use Godot 4)

- `CharacterBody2D` is generally appropriate for a script-controlled player with collision.
- `Area2D` is generally appropriate for proximity triggers, interaction zones, and transition zones.
- `CollisionShape2D` / `CollisionPolygon2D` should be used for explicit collision geometry.
- `Node2D.y_sort_enabled` can support Y-based draw ordering where the art perspective requires it.
- `AnimationPlayer` or `AnimatedSprite2D` may be appropriate depending on how existing animation assets
  and state logic are organized.
- `Resource`-based data definitions can be useful for reusable room, item, or dialogue data.
- `NavigationAgent2D` should only be introduced if actual pathfinding is required; it is not a
  substitute for a well-designed player collision and movement controller.

Do not apply Godot 4 APIs if the project is on Godot 3. Do not migrate versions as part of
ordinary feature work.

## Hybrid room implementation considerations

For each room, determine which elements are:
- baked into the background image;
- independent visual nodes;
- independently animated;
- interactive;
- solid to the player;
- foreground/occluding;
- triggers or navigation boundaries.

A large background image should not automatically become one giant collision shape. Build
collision from intended walkable boundaries and solid gameplay objects. Likewise, not every
visible furniture pixel needs collision.

## Performance and asset discipline

- Inspect source image dimensions, import settings, texture filtering, and compression before
  changing asset pipelines.
- Avoid loading duplicate copies of large room textures unnecessarily.
- Prefer reuse of shared resources where appropriate.
- Do not lower visual quality or alter project-wide rendering settings without profiling and
  a clear reason.
