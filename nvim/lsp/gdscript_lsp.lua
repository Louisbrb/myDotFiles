return {
    -- Godot ships the LSP server inside the editor; nvim connects to it over TCP.
    -- The Godot editor must be running with the project open. Port is set in
    -- Godot: Editor Settings -> Network -> Language Server (default 6005).
    cmd = vim.lsp.rpc.connect('127.0.0.1', 6005),
    filetypes = { 'gdscript' },
    root_markers = { 'project.godot', '.git' },
}
