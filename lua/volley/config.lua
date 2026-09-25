-- Options: defaults and validation.

local M = {}

M.defaults = {
    key = "<leader>v", -- opens the review
    keys = { -- the rest of the flow; any of them can be false
        annotate = "<leader>va", -- normal and visual mode
        queue = "<leader>vq",
        send = "<leader>vs",
        next = "]v", -- move between the changes in this file
        prev = "[v",
    },
    picker = "auto", -- "auto", "telescope", "snacks", "builtin" or "select"
    source = "auto", -- "auto", "git" or "snapshot"
    signs = true,
    stale = "keep", -- what to do with a comment whose code is gone: "keep" or "drop"
    snapshot = {
        max_files = 5000,
        max_filesize = 1024 * 1024,
        ignore = {}, -- extra directory or file names to leave out
    },
    agent = {
        -- How the comments reach the agent. The payload is appended as one
        -- argument, so nothing goes through a shell.
        cmd = { "claude", "--continue", "--print", "--output-format", "json" },
        pattern = "claude", -- how to spot the agent's terminal
        idle_ms = 1500, -- how long it must be quiet before sending
        require_idle = true,
    },
}

M.options = vim.deepcopy(M.defaults)

local function check(name, value, fn, expected)
    vim.validate(name, value, fn, false, expected)
end

local function one_of(name, value, list)
    check(name, value, function(v)
        return vim.tbl_contains(list, v)
    end, "one of " .. table.concat(list, ", "))
end

local function validate(o)
    check("key", o.key, function(v)
        return v == false or type(v) == "string"
    end, "a key string or false")
    for name, lhs in pairs(o.keys) do
        check("keys." .. name, lhs, function(v)
            return v == false or type(v) == "string"
        end, "a key string or false")
    end
    one_of("picker", o.picker, { "auto", "telescope", "snacks", "builtin", "select" })
    one_of("source", o.source, { "auto", "git", "snapshot" })
    one_of("stale", o.stale, { "keep", "drop" })
    check("signs", o.signs, function(v)
        return type(v) == "boolean"
    end, "a boolean")
    check("agent.cmd", o.agent.cmd, function(v)
        return type(v) == "table" and #v > 0
    end, "a command as a list")
    check("agent.pattern", o.agent.pattern, "string")
    check("agent.idle_ms", o.agent.idle_ms, function(v)
        return type(v) == "number" and v >= 0
    end, "a number >= 0")
    check("agent.require_idle", o.agent.require_idle, "boolean")
    for _, k in ipairs({ "max_files", "max_filesize" }) do
        check("snapshot." .. k, o.snapshot[k], function(v)
            return type(v) == "number" and v > 0
        end, "a positive number")
    end
end

---@param opts table|nil
---@return table
function M.setup(opts)
    local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
    -- Lists replace rather than merge by index.
    for _, path in ipairs({ { "agent", "cmd" }, { "snapshot", "ignore" } }) do
        local given = opts and opts[path[1]] and opts[path[1]][path[2]]
        if given then
            merged[path[1]][path[2]] = given
        end
    end
    local ok, err = pcall(validate, merged)
    if not ok then
        error("volley: " .. tostring(err):gsub("^[^:]*:%d+: ", ""), 0)
    end
    M.options = merged
    return merged
end

return M
