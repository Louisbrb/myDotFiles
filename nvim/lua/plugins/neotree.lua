return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    config = function()
        require("neo-tree").setup({
            close_if_last_window = true, -- Close Neo-tree if it's the last window
            enable_git_status = true,
            enable_diagnostics = true,

            window = {
                position = "left",
                width = 40,
            },

            filesystem = {
                filtered_items = {
                    hide_dotfiles = false,
                    hide_gitignored = true
                },
                follow_current_file = {
                    enabled = true,                     -- Focus on current file
                },
                hijack_netrw_behavior = "open_current", -- Use neo-tree instead of netrw
                use_libuv_file_watcher = true,          -- Auto-refresh on file changes
            },
        })

        -- Keybinding to toggle neo-tree
        vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { silent = true, desc = "Toggle Neo-tree" })
    end,
}
