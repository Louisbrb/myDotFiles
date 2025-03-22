-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()


config.front_end = OpenGL
config.max_fps = 144
config.default_cursor_style = BlinkingBlock
config.animation_fps = 1
config.cursor_blink_rate = 500
config.term = "xterm-256color" -- Set the terminal type


config.font = wezterm.font("FiraCode Nerd Font")
-- config.font = wezterm.font(JetBrains Mono Regular)
config.cell_width = 0.9
config.window_background_opacity = 0.7
config.prefer_egl = true
config.font_size = 18.0

wezterm.on('toggle-opacity', function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if overrides.window_background_opacity == 1 then
	  overrides.window_background_opacity = 0.7
	else
	  overrides.window_background_opacity = 1
	end
	window:set_config_overrides(overrides)
  end)

config.window_background_gradient = {
-- Can be "Vertical" or "Horizontal".  Specifies the direction
-- in which the color gradient varies.  The default is "Horizontal",
-- with the gradient going from left-to-right.
-- Linear and Radial gradients are also supported; see the other
-- examples below
orientation = 'Vertical',

colors = {
	'#060512',
	'#29214f',
	'#443570',
},


interpolation = 'Linear',


blend = 'Rgb',

}

config.window_padding = {
	left = 10,
	right = 10,
	top = 10,
	bottom = 10,
}

-- tabs
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
-- The set of schemes that we like and want to put in our rotation

config.color_scheme = '3024 (dark) (terminal.sexy)'


--keymaps
config.keys = {
	{
		key = 'o',
		mods = 'CTRL | ALT',
		action = act.EmitEvent 'toggle-opacity',
	},
}

-- For example, changing the color scheme
config.color_scheme = 'Cloud (terminal.sexy)'

config.window_frame = {
	font = wezterm.font({ family = "FiraCode Nerd Font", weight = Regular }),
	active_titlebar_bg = "#0c0b0f",
	-- active_titlebar_bg = #181616,
}

-- config.window_decorations = INTEGRATED_BUTTONS  RESIZE
config.window_decorations = "NONE | RESIZE"
--config.default_prog = { "powershell.exe", -NoLogo }
config.initial_cols = 80
return config
