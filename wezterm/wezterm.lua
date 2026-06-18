-- ~/.config/wezterm/wezterm.lua

local function reverse(tbl)
    local reversed = {}
    for i = #tbl, 1, -1 do
        table.insert(reversed, tbl[i])
    end
    return reversed
end

-- Pull in the wezterm API
local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.enable_wayland = false
config.front_end = "OpenGL"                 -- FIX: was bare OpenGL (nil), setting never applied
config.max_fps = 60
config.default_cursor_style = "SteadyBlock" -- FIX: was bare SteadyBlock (nil)
config.animation_fps = 1                    --Value other than one are stupid expensive on GPU it seem
config.cursor_blink_rate = 500
config.term = "xterm-256color"
config.enable_tab_bar = false -- make the tab bar invisible but doesnt disable it

config.cell_width = 0.9
config.window_background_opacity = 0.7
config.prefer_egl = true
config.line_height = 1.0 --always make sure this value can be divided by two or it trunk the top of chars
config.font_size = 19.0  --value in point and there is no way to find what is the point to pixel ratio
config.font = wezterm.font_with_fallback({
    "FiraCode Nerd Font",
    "DengXian",
    "Noto Color Emoji",
    "Symbols Nerd Font Mono",
})

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

Colors_lunar = {
    "#070912",
    "#0b0e1a",
    "#120e26",
    "#1a1530",
}

config.window_background_gradient = {
    orientation = "Horizontal",
    colors = Colors_lunar,
    interpolation = "Linear",
    blend = "Rgb",
}

config.colors = {
    foreground = "#e2e4f3",
    background = "#0b0e1a",

    cursor_bg = "#c4b5fd",
    cursor_fg = "#0b0e1a",
    cursor_border = "#c4b5fd",

    selection_bg = "#484565", -- moonglow pre-blended over the void (old wezterm can't parse #RRGGBBAA)
    selection_fg = "none",

    split = "#c4b5fd", -- pane split lines glow lavender
    scrollbar_thumb = "#151a2e",

    ansi = {
        "#151a2e", -- black   → nebula
        "#f87171", -- red     → supernova
        "#6ee7b7", -- green   → moonlit mint
        "#fbbf24", -- yellow  → solar
        "#7dd3fc", -- blue    → comet
        "#c4b5fd", -- magenta → moonglow
        "#99e6f0", -- cyan    → ice
        "#c5c9e0", -- white   → dim stardust
    },
    brights = {
        "#6b7194", -- bright black → crater
        "#fca5a5", -- bright red
        "#a7f3d0", -- bright green
        "#fcd34d", -- bright yellow
        "#a5e3fd", -- bright blue
        "#ddd6fe", -- bright magenta
        "#c3f0f7", -- bright cyan
        "#f4f5fb", -- bright white → full moonlight
    },

    -- quick-select / copy-mode accents
    copy_mode_active_highlight_bg = { Color = "#c4b5fd" },
    copy_mode_active_highlight_fg = { Color = "#0b0e1a" },
    copy_mode_inactive_highlight_bg = { Color = "#151a2e" },
    copy_mode_inactive_highlight_fg = { Color = "#e2e4f3" },
}

-- unfocused panes sink into the void
config.inactive_pane_hsb = {
    saturation = 0.8,
    brightness = 0.55,
}

-- silent moonglow flash instead of an audible bell
config.audible_bell = "Disabled"
config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 150,
    target = "CursorColor",
}
config.colors.visual_bell = "#f0abfc" -- eclipse pink blink

config.window_padding = {
    left = 10,
    right = 10,
    top = 10,
    bottom = 5,
}

-- tabs
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true

--keymaps
config.keys = {
    {
        key = "+",
        mods = "ALT | SHIFT",
        action = wezterm.action.IncreaseFontSize,
    },
    {
        key = "-",
        mods = "ALT | SHIFT",
        action = wezterm.action.DecreaseFontSize,
    },
    {
        key = "o",
        mods = "ALT | SHIFT",
        action = act.EmitEvent("toggle-opacity"),
    },
    {
        key = "h",
        mods = "ALT | SHIFT",
        action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    {
        key = "v",
        mods = "ALT | SHIFT",
        action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    {
        key = "w",
        mods = "ALT | SHIFT",
        action = wezterm.action.CloseCurrentPane { confirm = false },
    },
    {
        key = "LeftArrow",
        mods = "ALT | SHIFT",
        action = wezterm.action.ActivatePaneDirection 'Left',
    },
    {
        key = "RightArrow",
        mods = "ALT | SHIFT",
        action = wezterm.action.ActivatePaneDirection 'Right',
    },
    {
        key = "DownArrow",
        mods = "ALT | SHIFT",
        action = wezterm.action.ActivatePaneDirection 'Down',
    },
    {
        key = "UpArrow",
        mods = "ALT | SHIFT",
        action = wezterm.action.ActivatePaneDirection 'Up',
    },
}

config.window_frame = {
    font = wezterm.font({ family = "FiraCode Nerd Font", weight = "Regular" }), -- FIX: was bare Regular (nil)
    active_titlebar_bg = "#120e26",                                             -- dusk instead of the old magenta
    inactive_titlebar_bg = "#070912",
}

config.harfbuzz_features = { "zero" } --turn the bar of 0 into a dot. no idea how this can work and if it's dependant on font. I like it on fira
config.window_decorations = "NONE | RESIZE"
--config.default_prog = { "powershell.exe", -NoLogo } -- this is a mess on windows unfortunatly
config.initial_cols = 80

return config
