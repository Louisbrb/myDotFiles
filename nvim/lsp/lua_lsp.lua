return {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
    settings = {
        Lua = {
            runtime = {
                version = 'LuaJIT',
            },
            diagnostics = {
                globals = { 'vim' },
            },
            workspace = {
                -- Expose the Neovim runtime so the vim.* API (vim.api,
                -- vim.fn, vim.keymap, ...) actually autocompletes.
                library = vim.api.nvim_get_runtime_file('', true),
                checkThirdParty = false, -- don't nag about third-party libs
            },
            completion = {
                -- Complete a function call with its argument placeholders.
                callSnippet = 'Replace',
                keywordSnippet = 'Replace',
            },
            telemetry = { enable = false },
        }
    }
}
