extends Node
## The channel between the game and the HUD. Gameplay says what changed: a new place, an objective, an
## interaction, an item, a notice. The HUD shows it. Nothing here holds state: the save and the game's own
## systems keep that. Autoloaded as HudEvents.

signal location_changed(location_name: String, chapter_name: String)
signal objective_changed(title: String, description: String, complete: bool)
signal objective_cleared
## The places to look at while a house objective is on: each with its label, and whether it has been seen. Empty when none.
signal places_changed(places: Array)
signal interaction_changed(text: String)
signal inventory_changed
signal notification_requested(text: String)
signal screen_requested(screen_id: String)
signal item_open_requested(item_id: String)
signal item_opened(item_id: String)
signal item_view_requested(item_id: String)
## A talk box opened (true) or closed (false). The HUD hides the quick slots while one is on screen.
signal dialogue_changed(is_open: bool)

## True while a screen (the inventory) is open. Gameplay then takes no movement and no E.
var screen_open := false
## True while a conversation is on the full-screen stage (SceneDialogue, DialogueStage). The HUD steps aside then.
var dialogue_stage := false
