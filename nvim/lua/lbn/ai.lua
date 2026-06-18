local M = {}

-- Every provider here speaks the OpenAI-compatible "chat/completions" shape,
-- which is the de-facto standard I think (OpenAI, OpenRouter, DeepSeek, Together,
-- local Ollama, Gemini & Anthropic compat endpoints, ...). To swap models just
-- change `provider`, or edit/add an entry below. No other code changes needed.
M.config = {
    provider = "ollama",

    providers = {
        ollama = {
            url = "http://192.168.1.19:11434/v1/chat/completions",
            model = "qwen2.5-coder:3B",
            api_key_env = nil, -- local
        },
        openrouter = {
            url = "https://openrouter.ai/api/v1/chat/completions",
            model = "anthropic/claude-3.5-sonnet",
            api_key_env = "",
        },
        openai = {
            url = "https://api.openai.com/v1/chat/completions",
            model = "gpt-4o",
            api_key_env = ""
        },
    },

    temperature = 0.2,
    system_prompt = table.concat({
        "You are a code completion assistant embedded in an editor.",
        "You are given a single function. Complete or implement it.",
        "Return ONLY the full function as valid source code.",
        "Do NOT add explanations. Do NOT wrap the code in markdown fences.",
        "Indent the code as if the function were written at the top level (no leading indentation on the first line).",
        "You're allowed to rewrite comment but NOT to completelly remove them.",
    }, " "),
}

-- Treesitter: find the function enclosing the cursor
-- Node types that count as "a function" across common languages.
local FUNCTION_TYPES = {
    function_declaration = true, -- js/ts/go
    function_definition = true,  -- python/c/cpp/lua
    function_item = true,        -- rust
    method_declaration = true,   -- java/go
    method_definition = true,    -- js/ts/cpp
    arrow_function = true,       -- js/ts
    function_expression = true,  -- js/ts
    func_literal = true,         -- go
    constructor_declaration = true,
    local_function = true,       -- lua
}

local function enclosing_function()
    local ok, node = pcall(vim.treesitter.get_node)
    if not ok or not node then return nil end
    while node do
        local t = node:type()
        if FUNCTION_TYPES[t] or t:find("function") or t:find("method") then
            return node
        end
        node = node:parent()
    end
    return nil
end

-- Text helpers
-- Strip a leading/trailing ```lang ... ``` fence if the model added one anyway.
local function strip_fences(text)
    local lines = vim.split(text, "\n", { plain = true })
    if lines[1] and lines[1]:match("^%s*```") then
        table.remove(lines, 1)
        if lines[#lines] and lines[#lines]:match("^%s*```%s*$") then
            table.remove(lines, #lines)
        end
    end
    return lines
end

-- Re-indent model output to sit at `base_indent` (the function's own indent).
-- First line is left bare (it lands at start_col on insert); the rest get the
-- base indent prepended so nested lines align inside e.g. a class/impl block.
local function reindent(lines, base_indent)
    if base_indent == "" then return lines end
    local out = {}
    for i, line in ipairs(lines) do
        if i == 1 or line == "" then
            out[i] = line
        else
            out[i] = base_indent .. line
        end
    end
    return out
end

-- Floating preview window
local function open_float(title)
    local width = math.floor(vim.o.columns * 0.7)
    local height = math.floor(vim.o.lines * 0.6)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"

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
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = true

    return buf, win
end

-- HTTP call (curl via jobstart, body over stdin because that it's a mess )
local function request(messages, on_done)
    local p = M.config.providers[M.config.provider]
    if not p then
        vim.notify("ai: unknown provider '" .. tostring(M.config.provider) .. "'", vim.log.levels.ERROR)
        return
    end

    local cmd = {
        "curl", "-sS", "-X", "POST", p.url,
        "-H", "Content-Type: application/json",
    }
    if p.api_key_env then
        local key = os.getenv(p.api_key_env)
        if not key or key == "" then
            vim.notify("ai: env var " .. p.api_key_env .. " is not set", vim.log.levels.ERROR)
            return
        end
        table.insert(cmd, "-H")
        table.insert(cmd, "Authorization: Bearer " .. key)
    end
    table.insert(cmd, "-d")
    table.insert(cmd, "@-")

    local body = vim.json.encode({
        model = p.model,
        temperature = M.config.temperature,
        messages = messages,
        stream = false,
    })

    local out = {}
    local err = {}
    local job = vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data) vim.list_extend(out, data) end,
        on_stderr = function(_, data) vim.list_extend(err, data) end,
        on_exit = function(_, code)
            vim.schedule(function()
                if code ~= 0 then
                    on_done(nil, "curl failed (" .. code .. "): " .. table.concat(err, "\n"))
                    return
                end
                local raw = table.concat(out, "\n")
                local ok, decoded = pcall(vim.json.decode, raw)
                if not ok then
                    on_done(nil, "could not parse response: " .. raw)
                    return
                end
                if decoded.error then
                    on_done(nil, "api error: " .. (decoded.error.message or vim.inspect(decoded.error)))
                    return
                end
                local content = decoded.choices
                    and decoded.choices[1]
                    and decoded.choices[1].message
                    and decoded.choices[1].message.content
                if not content then
                    on_done(nil, "no content in response: " .. raw)
                    return
                end
                on_done(content, nil)
            end)
        end,
    })

    if job <= 0 then
        on_done(nil, "failed to start curl (why the fuck isn't curl installed ?)")
        return
    end
    vim.fn.chansend(job, body)
    vim.fn.chanclose(job, "stdin")
end

-- Main entry point
function M.complete_function()
    local node = enclosing_function()
    if not node then
        vim.notify("ai: cursor is not inside a function", vim.log.levels.WARN)
        return
    end

    local src_buf = vim.api.nvim_get_current_buf()
    local sr, sc, er, ec = node:range()
    local fn_text = vim.treesitter.get_node_text(node, src_buf)
    local filetype = vim.bo[src_buf].filetype

    -- Indentation of the function's first line (the text before start_col).
    local first_line = vim.api.nvim_buf_get_lines(src_buf, sr, sr + 1, false)[1] or ""
    local base_indent = first_line:sub(1, sc)
    if base_indent:match("%S") then base_indent = "" end -- guard: not waste token on pure whitespace

    local messages = {
        { role = "system", content = M.config.system_prompt },
        {
            role = "user",
            content = ("Language: %s\n\nComplete this function:\n\n%s"):format(filetype, fn_text),
        },
    }

    vim.notify("ai: llm is working " ..
        M.config.provider .. " (" .. M.config.providers[M.config.provider].model .. ")...")

    request(messages, function(content, errmsg)
        if errmsg then
            vim.notify("ai: " .. errmsg, vim.log.levels.ERROR)
            return
        end

        local lines = reindent(strip_fences(content), base_indent)

        local buf, win = open_float("AI suggestion  —  <CR> accept   q discard")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = filetype -- syntax highlight the preview
        vim.bo[buf].modifiable = false

        local function close()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end

        -- Accept: replace the original function range with the suggestion.
        vim.keymap.set("n", "<CR>", function()
            close()
            if vim.api.nvim_buf_is_valid(src_buf) then
                vim.api.nvim_buf_set_text(src_buf, sr, sc, er, ec, lines)
            end
        end, { buffer = buf, nowait = true })

        -- Discard.
        for _, key in ipairs({ "q", "<Esc>" }) do
            vim.keymap.set("n", key, close, { buffer = buf, nowait = true })
        end
    end)
end

return M
