-- 🌙 LUNAR ECLIPSE — catppuccin re-skinned with the waybar/wezterm palette
local lunar = require("lbn.lunar")

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- load before other plugins
    config = function()
      require("catppuccin").setup({
        flavour = "mocha", -- latte, frappe, macchiato, mocha
        transparent_background = true, -- let the wezterm void gradient show through
        integrations = {
          treesitter = true,
          native_lsp = {
            enabled = true,
          },
          neotree = true,
          which_key = true,
        },
        color_overrides = {
          mocha = {
            rosewater = lunar.bright_magenta,
            flamingo = lunar.bright_red,
            pink = lunar.eclipse,
            mauve = lunar.moonglow,
            red = lunar.supernova,
            maroon = lunar.bright_red,
            peach = lunar.bright_yellow,
            yellow = lunar.solar,
            green = lunar.mint,
            teal = lunar.ice,
            sky = lunar.bright_blue,
            sapphire = lunar.comet,
            blue = lunar.comet,
            lavender = lunar.moonglow,
            text = lunar.stardust,
            subtext1 = lunar.dim_stardust,
            subtext0 = "#b3b8d4",
            overlay2 = "#8b91b3",
            overlay1 = lunar.crater,
            overlay0 = "#565c7d",
            surface2 = "#343a5c",
            surface1 = "#232846",
            surface0 = lunar.nebula,
            base = lunar.void,
            mantle = lunar.abyss,
            crust = lunar.abyss,
          },
        },
        custom_highlights = function()
          return {
            -- moonglow rims, like the waybar pills and wezterm splits
            FloatBorder = { fg = lunar.moonglow },
            WinSeparator = { fg = lunar.moonglow },
            -- selection matches wezterm's selection_bg
            Visual = { bg = lunar.selection },
            -- cursor line: a faint nebula pill
            CursorLine = { bg = lunar.nebula },
            CursorLineNr = { fg = lunar.moonglow, style = { "bold" } },
            -- listchars space dots stay barely-there
            Whitespace = { fg = "#232846" },
          }
        end,
      })

      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
