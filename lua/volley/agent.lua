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

    -- What is running beats what a buffer is called. A chat sidebar named
    -- after your agent is not the agent, and it would otherwise win just by
    -- being called the right thing.
    local cmd, kids = processes()
    for _, buf in ipairs(terminals) do
        if running_here(vim.b[buf].terminal_job_pid, pattern, cmd, kids, 0) then
            return buf
        end
    end

    -- No process said so, which happens when ps is unavailable or the agent
    -- runs somewhere we cannot see. Fall back to the name.
    for _, buf in ipairs(terminals) do
        local name = vim.api.nvim_buf_get_name(buf)
        local title = vim.b[buf].term_title or ""
        if (name .. " " .. title):find(pattern, 1, true) then
            return buf
        end
    end
    return nil
end

-- Terminals keep changing while the agent prints. Quiet means it is waiting.
local last = {}

-- How long to watch a terminal we have never seen before. A terminal we have
-- no history for may have been quiet for an hour, and guessing "busy" would
-- refuse the first send of every session.
local FIRST_LOOK_MS = 200

local function now_ms()
    return vim.uv.hrtime() / 1e6
end

---Has the agent stopped printing? True when we cannot see its terminal.
function M.is_idle()
    local buf = M.terminal()
    if not buf then
        return true
    end
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local seen = last[buf]
    if not seen then
        -- Nothing to compare against, so watch it for a moment instead.
        vim.wait(FIRST_LOOK_MS, function()
            return vim.api.nvim_buf_get_changedtick(buf) ~= tick
        end, 20)
        local after = vim.api.nvim_buf_get_changedtick(buf)
        last[buf] = { tick = after, at = now_ms() }
        return after == tick
    end
    if seen.tick ~= tick then
        last[buf] = { tick = tick, at = now_ms() }
        return false
    end
    return (now_ms() - seen.at) >= opts().idle_ms
end

---How long the agent has been quiet, in milliseconds.
function M.quiet_for()
    local buf = M.terminal()
    if not buf or not last[buf] then
        return math.huge
    end
    return now_ms() - last[buf].at
end

-- A terminal in the middle of a line would treat our newlines as "send this
-- now", so the comments go in the way a paste does, between these markers.
local PASTE_START, PASTE_END = "\27[200~", "\27[201~"

---Type the comments into the agent's own terminal and press enter, so it
---answers where it is running, with the approvals it normally asks for.
---@param payload string
---@return boolean sent
function M.to_terminal(payload)
    local buf = M.terminal()
    local chan = buf and vim.b[buf].terminal_job_id
    if not chan then
        return false
    end
    local ok = pcall(vim.fn.chansend, chan, PASTE_START .. payload .. PASTE_END)
    if not ok then
        return false
    end
    -- Enter goes separately, after the paste has been read as one piece.
    vim.defer_fn(function()
        pcall(vim.fn.chansend, chan, "\r")
    end, 60)
    return true
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
