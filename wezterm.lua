-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- config.color_scheme = "AdventureTime"
config.keys = {
	{
		key = "LeftArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivateTabRelative(-1),
	},
	{
		key = "RightArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivateTabRelative(1),
	},
}
for i = 1, 8 do
	-- CTRL+ALT + number to move to that position
	table.insert(config.keys, {
		key = tostring(i),
		mods = "CTRL|ALT",
		action = wezterm.action.MoveTab(i - 1),
	})
end

local is_darwin = wezterm.target_triple:find("darwin") ~= nil

local font_size = 12.0
if is_darwin then
	font_size = 14.0
end

config.font = wezterm.font_with_fallback({
	"UbuntuMono Nerd Font Mono",
	"Ubuntu Mono Nerd Font Mono",
})
config.font_size = font_size

config.initial_rows = 60
config.initial_cols = 140
config.warn_about_missing_glyphs = false
config.scrollback_lines = 10000
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false

local is_wayland = os.getenv("WAYLAND_DISPLAY") ~= nil
local is_gnome = (os.getenv("XDG_CURRENT_DESKTOP") or ""):find("GNOME") ~= nil
if is_wayland then
	config.enable_wayland = true
	if is_gnome then
		-- If we are running under GNOME, we need to set the window decorations ourselves
		config.integrated_title_button_alignment = "Left"
		config.integrated_title_button_style = "Gnome"
		config.integrated_title_buttons = { "Close", "Hide", "Maximize" }
		config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
		config.window_frame = {
			border_left_width = "0.25cell",
			border_right_width = "0.25cell",
			border_bottom_height = "0.25cell",
			border_top_height = "0.25cell",
			border_left_color = "gray",
			border_right_color = "gray",
			border_bottom_color = "gray",
			border_top_color = "gray",
		}
	end
end
return config
