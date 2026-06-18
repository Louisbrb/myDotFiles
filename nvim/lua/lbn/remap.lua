vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { noremap = true })

-- Task runner (launch.json equivalent)
vim.keymap.set("n", "<leader>rl", function() require("lbn.runner").pick() end, { desc = "Run: pick task" })

vim.keymap.set("n", "<leader>sf", vim.cmd.w, { desc = "Save file" })
vim.api.nvim_create_user_command("SS", "mksession! ~/.nvim-session.vim", {})
