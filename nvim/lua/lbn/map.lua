-- Project Logic Map
--
-- Builds a navigable tree of a project's structure (files > classes/structs >
-- functions/methods) plus a call graph (who-calls-what), shown in its own tab.
-- All facts come from the LANGUAGE SERVERS already running via vim.lsp.enable
-- (see lua/config/lsp.lua) -- we write no language-detection logic ourselves:
--   * textDocument/documentSymbol        -> the nested outline
--   * prepareCallHierarchy + outgoingCalls -> the call edges
-- Files in languages without a configured server simply contribute nothing.

local M = {}

local uv = vim.uv or vim.loop

--------------------------------------------------------------------------------
-- Kinds (LSP SymbolKind numbers we care about)
--------------------------------------------------------------------------------
local KIND_FUNCTION, KIND_METHOD, KIND_CONSTRUCTOR = 12, 6, 9
local FN_KINDS = { [KIND_FUNCTION] = true, [KIND_METHOD] = true, [KIND_CONSTRUCTOR] = true }

-- Label prefixes for non-function kinds (SymbolKind -> word).
local KIND_LABEL = {
    [2] = "module",
    [3] = "namespace",
    [4] = "package",
    [5] = "class",
    [10] = "enum",
    [11] = "interface",
    [23] = "struct",
    [24] = "event",
    [26] = "type",
}

--------------------------------------------------------------------------------
-- Project root + file discovery
--------------------------------------------------------------------------------

-- Same marker-walk used by lua/lbn/runner.lua. Kept local so the module stands
-- alone (this codebase already duplicates small helpers across lbn modules).
local function find_root()
    local markers = { ".git", ".nvim-launch.lua", "package.json", "Cargo.toml", "pyproject.toml", "Makefile" }
    local path = vim.fn.getcwd()
    while path ~= "/" do
        for _, marker in ipairs(markers) do
            if vim.fn.filereadable(path .. "/" .. marker) == 1
                or vim.fn.isdirectory(path .. "/" .. marker) == 1
            then
                return path
            end
        end
        path = vim.fn.fnamemodify(path, ":h")
    end
    return vim.fn.getcwd()
end

local IGNORE_DIRS = {
    [".git"] = true, ["node_modules"] = true, ["target"] = true,
    [".cache"] = true, ["dist"] = true, ["build"] = true, ["__pycache__"] = true,
}

-- Recursively collect source files that have a detectable filetype. Skips
-- ignored / hidden directories. Files whose language has no server are dropped
-- later (they just never get a client).
local function discover(root, out)
    local fs = uv.fs_scandir(root)
    if not fs then return end
    while true do
        local name, typ = uv.fs_scandir_next(fs)
        if not name then break end
        local full = root .. "/" .. name
        if typ == "directory" then
            if not IGNORE_DIRS[name] and name:sub(1, 1) ~= "." then
                discover(full, out)
            end
        elseif typ == "file" then
            local ft = vim.filetype.match({ filename = full })
            if ft and ft ~= "" then
                table.insert(out, { path = full, ft = ft })
            end
        end
    end
end

--------------------------------------------------------------------------------
-- LSP helpers
--------------------------------------------------------------------------------

-- First client attached to bufnr whose server has the given capability.
local function client_with(bufnr, capability)
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if c.server_capabilities and c.server_capabilities[capability] then
            return c
        end
    end
    return nil
end

-- Convert an LSP documentSymbol response into our tree nodes. Handles both the
-- hierarchical DocumentSymbol[] shape and the flat SymbolInformation[] shape.
local function convert_symbols(syms, file, bufnr)
    local nodes = {}
    for _, s in ipairs(syms) do
        local sel = s.selectionRange or s.range or (s.location and s.location.range)
        local start = sel and sel.start or { line = 0, character = 0 }
        local node = {
            name = s.name,
            kind = s.kind,
            file = file,
            bufnr = bufnr,
            line = start.line,
            character = start.character,
            children = s.children and convert_symbols(s.children, file, bufnr) or {},
            calls = {},
        }
        table.insert(nodes, node)
    end
    return nodes
end

-- Collect documentSymbols for every discovered file. Buffers are loaded so the
-- server attaches and indexes; we retry with backoff while it warms up. Calls
-- on_complete once every file has either returned symbols or been given up on.
local function collect_symbols(state, on_complete)
    local remaining = #state.files
    if remaining == 0 then return on_complete() end

    local function one_done()
        remaining = remaining - 1
        if remaining == 0 then on_complete() end
    end

    for _, f in ipairs(state.files) do
        local bufnr = vim.fn.bufadd(f.path)
        vim.fn.bufload(bufnr)
        f.bufnr = bufnr

        local attempts = 0
        local function try()
            attempts = attempts + 1
            local client = client_with(bufnr, "documentSymbolProvider")
            if not client then
                if attempts < 12 then
                    vim.defer_fn(try, 150) -- server still attaching/indexing
                else
                    one_done() -- no server for this filetype; skip
                end
                return
            end
            client:request("textDocument/documentSymbol", {
                textDocument = { uri = vim.uri_from_bufnr(bufnr) },
            }, function(err, result)
                if not err and result and #result > 0 then
                    f.symbols = result
                end
                one_done()
            end, bufnr)
        end
        try()
    end
end

-- Build state.tree (file nodes -> symbol hierarchy) from collected symbols.
local function build_tree(state)
    state.tree = {}
    for _, f in ipairs(state.files) do
        if f.symbols then
            table.insert(state.tree, {
                name = f.path:sub(#state.root + 2), -- path relative to root
                is_file = true,
                file = f.path,
                bufnr = f.bufnr,
                line = 0,
                character = 0,
                children = convert_symbols(f.symbols, f.path, f.bufnr),
                calls = {},
            })
        end
    end
    table.sort(state.tree, function(a, b) return a.name < b.name end)
end

-- Flatten all function/method/constructor nodes for call-graph queries.
local function gather_fns(nodes, acc)
    for _, n in ipairs(nodes) do
        if FN_KINDS[n.kind] then table.insert(acc, n) end
        if n.children then gather_fns(n.children, acc) end
    end
end

-- Enrich each function node with its outgoing calls via the LSP call hierarchy.
-- Skipped silently for servers without callHierarchyProvider (outline-only).
local function enrich_calls(state, on_complete)
    local fns = {}
    for _, file_node in ipairs(state.tree) do
        gather_fns(file_node.children, fns)
    end

    local remaining = #fns
    if remaining == 0 then return on_complete() end

    local function one_done()
        remaining = remaining - 1
        if remaining == 0 then on_complete() end
    end

    for _, fn in ipairs(fns) do
        local bufnr = fn.bufnr
        local client = bufnr and client_with(bufnr, "callHierarchyProvider")
        if not client then
            one_done()
        else
            local params = {
                textDocument = { uri = vim.uri_from_bufnr(bufnr) },
                position = { line = fn.line, character = fn.character },
            }
            client:request("textDocument/prepareCallHierarchy", params, function(err, result)
                if err or not result or not result[1] then return one_done() end
                client:request("callHierarchyItem/outgoingCalls", { item = result[1] }, function(err2, calls)
                    if not err2 and calls then
                        for _, c in ipairs(calls) do
                            local r = c.to.selectionRange or c.to.range
                            table.insert(fn.calls, {
                                name = c.to.name,
                                file = vim.uri_to_fname(c.to.uri),
                                line = r and r.start.line or 0,
                                character = r and r.start.character or 0,
                            })
                        end
                    end
                    one_done()
                end, bufnr)
            end, bufnr)
        end
    end
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function format_label(n)
    if FN_KINDS[n.kind] then
        if n.name:find("%(") then return "fn " .. n.name end
        return "fn " .. n.name .. "()"
    end
    local word = KIND_LABEL[n.kind]
    if word then return word .. " " .. n.name end
    return n.name
end

-- Produce { lines, lookup } where lookup[i] = { file, line, character } | nil.
local function build_lines(state)
    local lines, lookup = {}, {}
    local function add(text, loc)
        table.insert(lines, text)
        lookup[#lines] = loc
    end

    add(vim.fn.fnamemodify(state.root, ":t") .. "/", { file = state.root })

    local function render_nodes(nodes, depth)
        local indent = string.rep("  ", depth)
        for _, n in ipairs(nodes) do
            add(indent .. format_label(n), { file = n.file, line = n.line, character = n.character })
            for _, c in ipairs(n.calls or {}) do
                add(indent .. "  → " .. c.name .. "()", { file = c.file, line = c.line, character = c.character })
            end
            if n.children and #n.children > 0 then
                render_nodes(n.children, depth + 1)
            end
        end
    end

    if #state.tree == 0 then
        add("  (no symbols — is a language server running for this project?)", nil)
    else
        for _, file_node in ipairs(state.tree) do
            add("  " .. file_node.name, { file = file_node.file, line = 0, character = 0 })
            render_nodes(file_node.children, 2)
        end
    end

    return lines, lookup
end

-- Jump to a location, reusing another window in the map's tab if present.
local function jump(state, loc)
    if not loc or not loc.file then return end
    local bufnr = vim.fn.bufadd(loc.file)
    vim.fn.bufload(bufnr)

    local map_win = vim.api.nvim_get_current_win()
    local target
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if w ~= map_win then
            target = w
            break
        end
    end
    if not target then
        vim.cmd("vsplit")
        target = vim.api.nvim_get_current_win()
    end
    vim.api.nvim_set_current_win(target)
    vim.api.nvim_win_set_buf(target, bufnr)
    if loc.line then
        vim.api.nvim_win_set_cursor(target, { loc.line + 1, loc.character or 0 })
        vim.cmd("normal! zz")
    end
end

local function render(state)
    -- Create the tab/buffer on first render; reuse it on rebuild.
    if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
        vim.cmd("tabnew")
        local buf = vim.api.nvim_get_current_buf()
        state.buf = buf
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.bo[buf].filetype = "lbn-map"
        pcall(vim.api.nvim_buf_set_name, buf, "LogicMap")

        local win = vim.api.nvim_get_current_win()
        vim.wo[win].number = false
        vim.wo[win].relativenumber = false
        vim.wo[win].wrap = false
        vim.wo[win].list = false
        vim.wo[win].cursorline = true
        vim.wo[win].foldmethod = "indent"
        vim.wo[win].foldlevel = 99

        vim.keymap.set("n", "<CR>", function()
            local lnum = vim.api.nvim_win_get_cursor(0)[1]
            jump(state, state.lookup and state.lookup[lnum])
        end, { buffer = buf, nowait = true, desc = "Map: jump to definition" })

        vim.keymap.set("n", "r", function() M.refresh() end,
            { buffer = buf, nowait = true, desc = "Map: rebuild" })

        for _, key in ipairs({ "q", "<Esc>" }) do
            vim.keymap.set("n", key, function()
                if #vim.api.nvim_list_tabpages() > 1 then
                    vim.cmd("tabclose")
                end
            end, { buffer = buf, nowait = true })
        end
    end

    local lines, lookup = build_lines(state)
    state.lines = lines
    state.lookup = lookup

    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
end

--------------------------------------------------------------------------------
-- Pipeline / entry points
--------------------------------------------------------------------------------

M.current = nil

local function build(reuse_buf)
    local root = find_root()
    local files = {}
    discover(root, files)

    if #files == 0 then
        vim.notify("map: no source files found under " .. root, vim.log.levels.WARN)
        return
    end

    if #files > 400 then
        local choice = vim.fn.confirm(
            ("map: %d files found. Build the map anyway?"):format(#files), "&Yes\n&No", 2)
        if choice ~= 1 then return end
    end

    local state = { root = root, files = files, buf = reuse_buf }
    M.current = state

    vim.notify("map: scanning " .. #files .. " files...")
    collect_symbols(state, function()
        build_tree(state)
        render(state) -- show the outline immediately
        enrich_calls(state, function()
            render(state) -- re-render with call edges
            vim.notify("map: ready")
        end)
    end)
end

-- Open (or focus) the project logic map in a tab.
function M.open()
    build(nil)
end

-- Rebuild into the existing map buffer (bound to `r` inside the map).
function M.refresh()
    local buf = M.current and M.current.buf
    if buf and vim.api.nvim_buf_is_valid(buf) then
        build(buf)
    else
        build(nil)
    end
end

-- Serialize the current map as plain text (foundation for the deferred AI step).
function M.serialize()
    if M.current and M.current.lines then
        return table.concat(M.current.lines, "\n")
    end
    return ""
end

return M
