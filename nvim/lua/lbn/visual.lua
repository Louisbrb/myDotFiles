--- INDEX LIGNES ---
vim.opt.number = true
vim.opt.relativenumber = true
--- Split ---
vim.opt.splitright = true
vim.opt.splitbelow = true
--- IDENTATION ---
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.expandtab = true             -- change les tabulation par des espace
vim.opt.tabstop = 4                  -- nombre d'espace dans chaque tabulation
vim.opt.shiftwidth = 4               -- nombre d'espace pour l'auto indentation
vim.cmd("filetype plugin indent on") -- permet l'indentation dynamique en focntion des type de fichier
vim.opt.cmdheight = 1                -- command line height
vim.opt.cursorline = true
vim.opt.scrolloff = 8
--- LISTCHARS ---
vim.opt.list = true
vim.opt.listchars = { space = '·' }
-- vim.api.nvim_set_hl(0, 'Whitespace', { fg = '#111111' })
-- Format-on-save is handled per-LSP in config/lsp.lua (only for buffers
-- whose server supports formatting), so no global hook is needed here.
