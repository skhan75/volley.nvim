-- Talking to the coding agent: is it busy, and here are my comments.

local config = require("volley.config")

local M = {}

local function opts()
    return config.options.agent
end

---The terminal buffer the agent is running in, if we can see one.
---Marked buffers win; otherwise we look at what each terminal is running.
---@return integer|nil
function M.terminal()
    local fallback
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
            if vim.b[buf].volley_agent then
                return buf
            end
            local name = vim.api.nvim_buf_get_name(buf)
            local title = vim.b[buf].term_title or ""
            local pid = vim.b[buf].terminal_job_pid
            local cmd = ""
            if pid then
                local res = vim.system(
                    { "ps", "-o", "command=", "-p", tostring(pid) },
                    { text = true }
                )
                    :wait()
                cmd = res.stdout or ""
            end
            if (name .. " " .. title .. " " .. cmd):find(opts().pattern, 1, true) then
                fallback = fallback or buf
            end
        end
    end
    return fallback
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
