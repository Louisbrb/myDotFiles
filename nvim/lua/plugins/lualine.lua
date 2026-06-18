-- 🌙 LUNAR ECLIPSE lualine theme — replaces dracula to match the rice
local lunar = require("lbn.lunar")

local lunar_theme = {
    normal = {
        a = { fg = lunar.void, bg = lunar.moonglow, gui = "bold" },
        b = { fg = lunar.stardust, bg = lunar.nebula },
        c = { fg = lunar.crater, bg = lunar.void },
    },
    insert = {
        a = { fg = lunar.void, bg = lunar.comet, gui = "bold" },
        b = { fg = lunar.comet, bg = lunar.nebula },
    },
    visual = {
        a = { fg = lunar.void, bg = lunar.eclipse, gui = "bold" },
        b = { fg = lunar.eclipse, bg = lunar.dusk },
    },
    replace = {
        a = { fg = lunar.void, bg = lunar.supernova, gui = "bold" },
        b = { fg = lunar.supernova, bg = lunar.nebula },
    },
    command = {
        a = { fg = lunar.void, bg = lunar.solar, gui = "bold" },
        b = { fg = lunar.solar, bg = lunar.nebula },
    },
    terminal = {
        a = { fg = lunar.void, bg = lunar.mint, gui = "bold" },
        b = { fg = lunar.mint, bg = lunar.nebula },
    },
    inactive = {
        a = { fg = lunar.crater, bg = lunar.abyss },
        b = { fg = lunar.crater, bg = lunar.abyss },
        c = { fg = lunar.crater, bg = lunar.abyss },
    },
}

return {
    'nvim-lualine/lualine.nvim',
    config = function()
        require("lualine").setup({
            options = {
                theme = lunar_theme,
                component_separators = { left = '|', right = '|' },
                section_separators = { left = '', right = '' },
                icons_enabled = true,
                globalstatus = true, -- Single statusline for all windows
            },
            sections = {
                lualine_a = { 'mode' },
                lualine_b = { 'branch', 'diff', 'diagnostics' },
                lualine_c = { 'filename' },
                lualine_x = { 'encoding', 'fileformat', 'filetype' },
                lualine_y = { 'progress' },
                lualine_z = { 'location' }
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { 'filename' },
                lualine_x = { 'location' },
                lualine_y = {},
                lualine_z = {}
            },
        })
    end,
}
