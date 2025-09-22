--- INDEX LIGNES ---
vim.opt.number = true
vim.opt.relativenumber = true

--- IDENTATION ---
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.expandtab = true -- change les tabulation par des espace
vim.opt.tabstop = 4 -- nombre d'espace dans chaque tabulation
vim.opt.shiftwidth = 4 -- nombre d'espace pour l'auto indentation 
vim.cmd("filetype plugin indent on") -- permet l'indentation dynamique en focntion des type de fichier
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function()
        vim.lsp.buf.format()
    end,
})

