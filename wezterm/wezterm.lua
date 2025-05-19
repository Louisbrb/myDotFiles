-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.front_end = OpenGL
config.max_fps = 60
config.default_cursor_style = SteadyBlock
config.animation_fps = 1 --Value other than one are stupid expensive on GPU it seem
config.cursor_blink_rate = 500
config.term = "xterm-256color"

config.font = wezterm.font("FiraCode Nerd Font")
config.cell_width = 0.9
config.window_background_opacity = 0.7
config.prefer_egl = true
config.font_size = 19.0 --value in point and there is no way to find what is the point to pixel ratio

-- disable/enable opacity on trigger
wezterm.on("toggle-opacity", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if overrides.window_background_opacity == 1 then
		overrides.window_background_opacity = 0.7
	else
		overrides.window_background_opacity = 1
	end
	window:set_config_overrides(overrides)
end)

Colors_cold = {
	"#060512",
	"#29214f",
	"#443570",
}

Colors_warm = {
	"#E54400",
	"#500400",
	"#0A0000",
}

config.window_background_gradient = {
	-- Can be "Vertical" or "Horizontal".  Specifies the direction
	-- in which the color gradient varies.  The default is "Horizontal",
	-- with the gradient going from left-to-right.
	orientation = "Vertical",
	colors = Colors_cold,
	interpolation = "Linear",
	blend = "Rgb",
}

config.window_padding = {
	left = 10,
	right = 10,
	top = 10,
	bottom = 5,
}

-- tabs
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true

config.color_scheme = "Later This Evening (Gogh)"

--keymaps
config.keys = {
	{
		key = "o",
		mods = "CTRL | ALT",
		action = act.EmitEvent("toggle-opacity"),
	},
	{
		key = "t",
		mods = "SHIFT|ALT",
		action = act.SpawnTab("CurrentPaneDomain"),
	},
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentTab({ confirm = true }),
	},
}

config.window_frame = {
	font = wezterm.font({ family = "FiraCode Nerd Font", weight = Regular }),
	active_titlebar_bg = "#0c0b0f",
}

config.window_decorations = "NONE | RESIZE"
--config.default_prog = { "powershell.exe", -NoLogo }
config.initial_cols = 80
return config
