-- Talking to the coding agent: is it busy, and here are my comments.

local config = require("volley.config")

local M = {}

local function opts()
    return config.options.agent
end

-- Every running process, as { command by pid } and { children by pid }. The
-- agent is usually not the terminal's own process but something you started
-- in the shell it runs, so we need the whole tree to find it.
local function processes()
    local ok, res = pcall(function()
        return vim.system({ "ps", "-eo", "pid=,ppid=,command=" }, { text = true }):wait()
    end)
    local cmd, kids = {}, {}
    if not ok or res.code ~= 0 then
        return cmd, kids
    end
    for line in (res.stdout or ""):gmatch("[^\n]+") do
        local pid, ppid, command = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
        if pid then
            pid, ppid = tonumber(pid), tonumber(ppid)
            cmd[pid] = command
            kids[ppid] = kids[ppid] or {}
            table.insert(kids[ppid], pid)
        end
    end
    return cmd, kids
end

local MAX_DEPTH = 8

local function running_here(pid, pattern, cmd, kids, depth)
    if not pid or (depth or 0) > MAX_DEPTH then
        return false
    end
    if cmd[pid] and cmd[pid]:find(pattern, 1, true) then
        return true
    end
    for _, kid in ipairs(kids[pid] or {}) do
        if running_here(kid, pattern, cmd, kids, (depth or 0) + 1) then
            return true
        end
    end
    return false
end

---The terminal buffer the agent is running in, if we can see one.
---A buffer you marked yourself wins. Otherwise we look at what each terminal
---is called, and at what is running inside it.
---@return integer|nil
function M.terminal()
    local terminals = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
            if vim.b[buf].volley_agent then
                return buf
            end
            terminals[#terminals + 1] = buf
        end
    end
    if #terminals == 0 then
        return nil
    end

    local pattern = opts().pattern
    local unmatched = {}
    for _, buf in ipairs(terminals) do
        local name = vim.api.nvim_buf_get_name(buf)
        local title = vim.b[buf].term_title or ""
        if (name .. " " .. title):find(pattern, 1, true) then
            return buf
        end
        unmatched[#unmatched + 1] = buf
    end

    -- Nothing obvious, so ask the system what these terminals are running.
    local cmd, kids = processes()
    for _, buf in ipairs(unmatched) do
        if running_here(vim.b[buf].terminal_job_pid, pattern, cmd, kids, 0) then
            return buf
        end
    end
    return nil
end

-- Terminals keep changing while the agent prints. Quiet means it is waiting.
local last = {}

---Has the agent stopped printing? True when we cannot see its terminal.
function M.is_idle()
    local buf = M.terminal()
    if not buf then
        return true
    end
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local now = vim.uv.hrtime() / 1e6
    local seen = last[buf]
    if not seen or seen.tick ~= tick then
        last[buf] = { tick = tick, at = now }
        return false
    end
    return (now - seen.at) >= opts().idle_ms
end

---How long the agent has been quiet, in milliseconds.
function M.quiet_for()
    local buf = M.terminal()
    if not buf or not last[buf] then
        return math.huge
    end
    return (vim.uv.hrtime() / 1e6) - last[buf].at
end

local function parse(stdout)
    local ok, decoded = pcall(vim.json.decode, stdout)
    if ok and type(decoded) == "table" then
        return {
            ok = not decoded.is_error,
            reply = decoded.result or "",
            session = decoded.session_id,
            cost = decoded.total_cost_usd,
        }
    end
    return { ok = true, reply = (stdout:gsub("%s+$", "")) }
end

---Send the comments. The payload goes as one argument, never through a shell.
---@param payload string
---@param cb fun(res: { ok: boolean, reply: string|nil, session: string|nil, cost: number|nil, error: string|nil })
function M.send(payload, cb)
    local cmd = vim.list_extend(vim.deepcopy(opts().cmd), { payload })
    vim.system(cmd, { text = true, stdin = false }, function(res)
        vim.schedule(function()
            if res.code ~= 0 then
                local err = (res.stderr or res.stdout or ""):gsub("%s+$", "")
                return cb({ ok = false, error = err ~= "" and err or ("exit " .. res.code) })
            end
            cb(parse(res.stdout or ""))
        end)
    end)
end

return M
