return {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_marker = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
    settings = {
        Lua = {
            runtime = {
                version = 'LuaJIT',
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = { 'vim' },
            },
        }
    }
}
