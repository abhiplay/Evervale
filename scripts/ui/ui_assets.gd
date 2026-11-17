class_name UiAssets
## Where the HUD's pictures are. Every component takes its picture from here, so a frame or an icon is swapped
## in one place. The frames are cut from the UI sheet and the icons from the reference picture, under
## assets/ui/hud/.

const DIR := "res://assets/ui/hud/"
const BANNER := DIR + "Panels/banner_location.png"
const PANEL_LARGE := DIR + "Panels/panel_large.png"
const PANEL_SMALL := DIR + "Panels/panel_small.png"
const FRAME_SQUARE := DIR + "Buttons/frame_square_nav.png"
const FRAME_BUTTON := DIR + "Buttons/frame_button_laurel.png"
const FRAME_WIDE := DIR + "Buttons/frame_wide_laurel.png"
const SLOT := DIR + "Buttons/frame_square_nav.png"
const BADGE := DIR + "Decorations/badge_circle.png"
const KEYCAP := DIR + "Decorations/badge_square.png"
const DIAMOND := DIR + "Decorations/marker_diamond.png"
const DIVIDER := DIR + "Decorations/divider_line.png"
const ICON_JOURNAL := DIR + "Icons/icon_journal.png"
const ICON_INVENTORY := DIR + "Icons/icon_inventory.png"
const ICON_MAP := DIR + "Icons/icon_map.png"
const ICON_SETTINGS := DIR + "Icons/icon_settings.png"
const ICON_HOME := DIR + "Icons/icon_location_home.png"
const TAB_ALL := DIR + "Icons/tab_all.png"
const TAB_KEY := DIR + "Icons/tab_key.png"
const TAB_DOCUMENTS := DIR + "Icons/tab_documents.png"
const TAB_CLUES := DIR + "Icons/tab_clues.png"
const TAB_PERSONAL := DIR + "Icons/tab_personal.png"
## The tab icons by category id, as the inventory's tabs use them.
const TAB_ICONS := {"all": TAB_ALL, "key": TAB_KEY, "documents": TAB_DOCUMENTS, "clues": TAB_CLUES, "personal": TAB_PERSONAL}
const DISCOVERY_FRAME := DIR + "Discovery/discovery_frame.png"
const DISCOVERY_GLOW := DIR + "Discovery/discovery_glow.png"
const BUTTON_GLOW := DIR + "Discovery/button_glow.png"
const BUTTON_DARK := DIR + "Discovery/button_dark.png"
