local M = {}

-- Find the project root by walking up from cwd looking for markers
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

-- Open a floating window and return { buf, win }
local function open_float(title)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.6)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "runner-output"

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "center",
    })

    vim.wo[win].wrap = true
    vim.wo[win].cursorline = true

    -- Close mappings
    for _, key in ipairs({ "q", "<Esc>" }) do
        vim.keymap.set("n", key, function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end, { buffer = buf, nowait = true })
    end

    return buf, win
end

-- Run a shell command and stream output into a floating window
local function run_command(task)
    local buf, win = open_float(task.name)
    local lines = { "$ " .. task.cmd, "" }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local function append(data)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        for _, line in ipairs(data) do
            if line ~= "" then
                local count = vim.api.nvim_buf_line_count(buf)
                vim.api.nvim_buf_set_lines(buf, count, count, false, { line })
                -- scroll to bottom if window still open
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
                end
            end
        end
    end

    local cwd = task.cwd or find_root()

    vim.fn.jobstart(task.cmd, {
        cwd = cwd,
        stdout_buffered = false,
        stderr_buffered = false,
        on_stdout = function(_, data) append(data) end,
        on_stderr = function(_, data) append(data) end,
        on_exit = function(_, code)
            if not vim.api.nvim_buf_is_valid(buf) then return end
            local count = vim.api.nvim_buf_line_count(buf)
            local status = code == 0 and "✓ Done (exit 0)" or ("✗ Failed (exit " .. code .. ")")
            vim.api.nvim_buf_set_lines(buf, count, count, false, { "", status })
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
            end
        end,
    })
end

-- Load tasks from .nvim-launch.lua at project root
local function load_tasks()
    local root = find_root()
    local config_path = root .. "/.nvim-launch.lua"
    if vim.fn.filereadable(config_path) == 0 then
        return nil, config_path
    end
    local ok, tasks = pcall(dofile, config_path)
    if not ok or type(tasks) ~= "table" then
        vim.notify("runner: failed to load " .. config_path, vim.log.levels.ERROR)
        return nil, config_path
    end
    return tasks, config_path
end

-- Main entry point: show picker then run selected task
function M.pick()
    local tasks, config_path = load_tasks()
    if not tasks then
        vim.notify("No .nvim-launch.lua found. Expected at: " .. config_path, vim.log.levels.WARN)
        return
    end

    if #tasks == 0 then
        vim.notify("runner: .nvim-launch.lua returned an empty table", vim.log.levels.WARN)
        return
    end

    vim.ui.select(tasks, {
        prompt = "Run task:",
        format_item = function(t) return t.name end,
    }, function(task)
        if task then run_command(task) end
    end)
end

-- Run a task by name directly (useful for keybindings)
function M.run(name)
    local tasks = load_tasks()
    if not tasks then return end
    for _, t in ipairs(tasks) do
        if t.name == name then
            run_command(t)
            return
        end
    end
    vim.notify("runner: no task named '" .. name .. "'", vim.log.levels.WARN)
end

return M
