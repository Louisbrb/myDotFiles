vim.opt.clipboard = "unnamedplus"

vim.api.nvim_create_autocmd("TermOpen", {
    callback = function()
        vim.cmd("file term")
    end,
})
