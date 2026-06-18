vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { noremap = true })

-- Task runner (launch.json equivalent)
vim.keymap.set("n", "<leader>rl", function() require("lbn.runner").pick() end, { desc = "Run: pick task" })

-- AI: complete the function under the cursor
vim.keymap.set("n", "<leader>ai", function() require("lbn.ai").complete_function() end, { desc = "AI: complete function" })

-- Project logic map (LSP-driven treeview in a tab)
vim.keymap.set("n", "<leader>m", function() require("lbn.map").open() end, { desc = "Map: project logic tree" })

vim.keymap.set("n", "<leader>sf", vim.cmd.w, { desc = "Save file" })
vim.api.nvim_create_user_command("SS", "mksession! ~/.nvim-session.vim", {})
