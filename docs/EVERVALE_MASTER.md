# Evervale — Master Game Brief

## Product identity

Evervale is an original 2D illustrated exploration/adventure game. It combines detailed,
illustrated room environments with character-led exploration and interactive storytelling.

The Genesis Order is a reference for broad visual presentation and gameplay structure only.
Evervale must develop its own visual identity, world, characters, writing, assets, and interface.

## Experience pillars

1. **Believable spaces** — rooms feel architecturally coherent and have readable circulation.
2. **Comfortable exploration** — players can understand where they can walk, enter, and interact.
3. **Meaningful interaction** — objects and locations respond consistently and communicate feedback.
4. **Visual cohesion** — backgrounds, props, characters, lighting, and UI belong to one art direction.
5. **Reliable continuity** — room transitions and saved progress behave predictably.

## Environment model

Use a hybrid 2D environment where appropriate:

- **Static visual layer:** pre-rendered or illustrated room backgrounds, including architectural
  details that do not need independent gameplay behavior.
- **Independent prop layer:** furniture, doors, foreground elements, collectibles, and objects
  that need movement, animation, interaction, visibility changes, or independent collision.
- **Gameplay layer:** player, collision shapes, navigation aids, triggers, interaction areas,
  and room transition logic.
- **Presentation layer:** dialogue, menus, HUD, prompts, and overlays.

Do not force every room to use exactly the same node structure. Reuse a documented room
template where it fits, while allowing justified exceptions.

## World structure

Evervale is intended to be a connected world with multiple floors and rooms. Known examples
from the current concept include a ground-floor reception, reading lounge, reading hall,
staircase, and additional spaces on an upper floor.

Treat this as concept context, not proof that these rooms or systems already exist in the
repository. Confirm actual implementation before editing.

Every connection should define:
- source room and exit;
- destination room and entry point;
- transition trigger or interaction;
- player spawn position and facing direction, where relevant;
- any state that must persist across the transition.

## Level-design principles

- Preserve clear routes between entrances and important interactables.
- Use a consistent world scale within each connected area.
- Provide sensible clearance around doors, stairs, and furniture.
- Keep collision shapes simple and intentional.
- Avoid relying on visual appearance alone to determine whether an object is solid.
- Consider occlusion: the player may pass behind or in front of props depending on position.
- Check the room from the player's actual movement range, not just from a static screenshot.

## Character and interaction principles

The player controller should be responsive and consistent with the game's camera and art
perspective. Determine whether the existing game uses four-direction or eight-direction
movement before changing it.

Interactions should have:
- a defined activation method;
- a defined range or trigger;
- clear feedback;
- a predictable priority when interactables overlap;
- safe handling when an object or target becomes unavailable.

## Narrative and progression

Dialogue, story events, collectibles, inventory, quests, and save data should be modular
systems if and when the game needs them. Do not add speculative systems just because they
appear in another adventure game.

## Quality bar

A feature is not complete merely because code was written. Completion requires:
- implementation consistent with existing architecture;
- relevant runtime or automated verification;
- regression checks for connected systems;
- a concise record of any manual testing still required.
