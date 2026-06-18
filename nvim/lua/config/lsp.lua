vim.lsp.enable('lua_lsp')
vim.lsp.enable('rust_lsp')
vim.lsp.enable('gdscript_lsp')
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        local bufnr = ev.buf
        if client:supports_method('textDocument/completion') then
            vim.opt.completeopt = { 'menu', 'menuone', 'noinsert', 'fuzzy', 'popup' }
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
            vim.keymap.set('i', '<C-Space>', function()
                vim.lsp.completion.get()
            end)
        end
        if client:supports_method("textDocument/formatting") then
            local group = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = false })

            vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })

            vim.api.nvim_create_autocmd("BufWritePre", {
                group = group,
                buffer = bufnr,
                callback = function()
                    vim.lsp.buf.format({ bufnr = bufnr })
                end,
            })
        end
    end,
})
-- Diagnostics
vim.diagnostic.config({
    -- Use the default configuration
    -- virtual_lines = true

    -- Alternatively, customize specific options
    virtual_lines = {
        -- Only show virtual line diagnostics for the current cursor line
        current_line = true,
    },
})
