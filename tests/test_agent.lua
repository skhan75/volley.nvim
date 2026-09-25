local H = dofile("tests/helpers.lua")
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function agent()
    package.loaded["volley.agent"] = nil
    return require("volley.agent")
end

local function config(opts)
    package.loaded["volley.config"] = nil
    return require("volley.config").setup(opts or {})
end

-- A stand-in for the claude CLI: records its arguments, answers with JSON.
local function fake_cli(dir, body, code)
    local path = dir .. "/fake-claude.sh"
    local lines = {
        "#!/bin/sh",
        'printf "%s" "$*" > ' .. dir .. "/args.txt",
        "cat > " .. dir .. "/stdin.txt", -- proves stdin is closed, or this hangs
        "cat <<'JSON'",
    }
    body = body or '{"result":"1. Fixed it.","session_id":"abc123","total_cost_usd":0.01}'
    vim.list_extend(lines, vim.split(body, "\n", { plain = true }))
    vim.list_extend(lines, { "JSON", "exit " .. (code or 0) })
    H.write(path, lines)
    vim.fn.setfperm(path, "rwxr-xr-x")
    return path
end

-- A process with a name we can look for. `exec -a` is not portable (dash has
-- no such flag), so the name has to come from the file itself.
local function script(name, body)
    local path = H.tmpdir() .. "/" .. name
    H.write(path, vim.list_extend({ "#!/bin/sh" }, body))
    vim.fn.setfperm(path, "rwxr-xr-x")
    return path
end

T["config"] = MiniTest.new_set()

T["config"]["fills in the defaults"] = function()
    local o = config()
    eq(o.picker, "auto")
    eq(o.agent.idle_ms > 0, true)
    eq(o.key, "<leader>v")
end

T["config"]["keeps sibling defaults when you set one thing"] = function()
    local o = config({ agent = { idle_ms = 50 } })
    eq(o.agent.idle_ms, 50)
    eq(type(o.agent.cmd), "table")
end

T["config"]["rejects a picker it does not have"] = function()
    MiniTest.expect.error(function()
        config({ picker = "fzf" })
    end, "picker")
end

T["send()"] = MiniTest.new_set()

T["send()"]["passes the comments to the agent and returns its answer"] = function()
    local dir = H.tmpdir()
    config({ agent = { cmd = { fake_cli(dir) } } })
    local got
    agent().send("1. billing.py line 3\n   > why this way", function(res)
        got = res
    end)
    vim.wait(4000, function()
        return got ~= nil
    end, 20)
    eq(got.ok, true)
    eq(got.reply, "1. Fixed it.")
    eq(got.session, "abc123")
    local args = table.concat(H.read(dir .. "/args.txt"), "\n")
    eq(args:find("why this way", 1, true) ~= nil, true)
end

T["send()"]["reports a failure instead of pretending"] = function()
    local dir = H.tmpdir()
    config({ agent = { cmd = { fake_cli(dir, "boom", 1) } } })
    local got
    agent().send("anything", function(res)
        got = res
    end)
    vim.wait(4000, function()
        return got ~= nil
    end, 20)
    eq(got.ok, false)
    eq(got.error ~= nil, true)
end

T["send()"]["copes with an agent that answers in plain text"] = function()
    local dir = H.tmpdir()
    config({ agent = { cmd = { fake_cli(dir, "just some words") } } })
    local got
    agent().send("anything", function(res)
        got = res
    end)
    vim.wait(4000, function()
        return got ~= nil
    end, 20)
    eq({ got.ok, got.reply }, { true, "just some words" })
end

T["is_idle()"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            _G.child = H.new_child()
            child.start_editor()
        end,
        post_case = function()
            child.stop()
        end,
    },
})

T["is_idle()"]["is true when no agent terminal is around"] = function()
    child.config({ agent = { idle_ms = 100 } })
    eq(child.lua_get("require('volley.agent').is_idle()"), true)
end

T["is_idle()"]["is false while the agent is printing, true once it stops"] = function()
    child.config({ agent = { idle_ms = 300, pattern = "chatter" } })
    local path = script("chatter", {
        "for i in 1 2 3 4 5 6 7 8; do echo working; sleep 0.2; done",
        "sleep 60",
    })
    child.lua(
        [[
        local path = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            vim.fn.jobstart({ path }, { term = true })
        end)
        _G.agent_buf = buf
    ]],
        { path }
    )
    H.sleep(500)
    eq(child.lua_get("require('volley.agent').is_idle()"), false)
    H.wait(child, "require('volley.agent').is_idle() == true", 5000, "the agent to go quiet")
end

T["is_idle()"]["is true the first time we look at a terminal that went quiet earlier"] = function()
    child.config({ agent = { idle_ms = 300, pattern = "chatter" } })
    local path = script("chatter", { "echo ready", "sleep 30" })
    child.lua(
        [[
        local path = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            vim.fn.jobstart({ path }, { term = true })
        end)
        _G.agent_buf = buf
    ]],
        { path }
    )
    -- It stops printing well before volley is ever asked about it.
    H.sleep(900)
    eq(child.lua_get("require('volley.agent').is_idle()"), true)
end

T["is_idle()"]["finds the agent terminal by what it is running"] = function()
    child.config({ agent = { idle_ms = 100, pattern = "claude" } })
    local path = script("claude", { "sleep 30" })
    child.lua(
        [[
        local path = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            vim.fn.jobstart({ path }, { term = true })
        end)
    ]],
        { path }
    )
    H.wait(child, "require('volley.agent').terminal() ~= nil", 5000, "the terminal to be found")
end

T["is_idle()"]["finds the agent started inside the terminal's shell"] = function()
    child.config({ agent = { idle_ms = 100, pattern = "claude" } })
    local path = script("claude", { "sleep 30" })
    child.lua(
        [[
        local path = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            _G.chan = vim.fn.jobstart({ "sh" }, { term = true })
        end)
        vim.fn.chansend(_G.chan, path .. "\n")
    ]],
        { path }
    )
    H.wait(
        child,
        "require('volley.agent').terminal() ~= nil",
        5000,
        "the agent process to be found"
    )
end

T["is_idle()"]["ignores a terminal running something else"] = function()
    child.config({ agent = { idle_ms = 100, pattern = "claude" } })
    local path = script("something-else", { "sleep 30" })
    child.lua(
        [[
        local path = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            vim.fn.jobstart({ path }, { term = true })
        end)
    ]],
        { path }
    )
    H.sleep(600)
    eq(child.lua_get("require('volley.agent').terminal()"), vim.NIL)
end

T["to_terminal()"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            _G.child = H.new_child()
            child.start_editor()
        end,
        post_case = function()
            child.stop()
        end,
    },
})

-- `cat -v` echoes what it is given and makes escape codes visible.
local function agent_terminal(pattern)
    local path = script(pattern or "claude", { "cat -v" })
    child.lua(
        [[
        local path = ...
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            vim.fn.jobstart({ path }, { term = true })
        end)
        _G.agent_buf = buf
    ]],
        { path }
    )
    H.wait(child, "require('volley.agent').terminal() == _G.agent_buf", 5000, "the terminal")
end

local function terminal_text()
    return table.concat(
        child.lua_get("vim.api.nvim_buf_get_lines(_G.agent_buf, 0, -1, false)"),
        "\n"
    )
end

T["to_terminal()"]["types the comments into the agent's terminal"] = function()
    child.config({ agent = { pattern = "claude" } })
    agent_terminal()
    eq(
        child.lua_get([[require("volley.agent").to_terminal("1. a.py line 3\n   > why this way")]]),
        true
    )
    H.wait(
        child,
        [[table.concat(vim.api.nvim_buf_get_lines(_G.agent_buf, 0, -1, false), "\n"):find("why this way", 1, true) ~= nil]],
        3000,
        "the comments to arrive"
    )
end

T["to_terminal()"]["sends it as a paste, so newlines do not submit early"] = function()
    child.config({ agent = { pattern = "claude" } })
    agent_terminal()
    child.lua([[require("volley.agent").to_terminal("first line\nsecond line")]])
    H.wait(
        child,
        [[table.concat(vim.api.nvim_buf_get_lines(_G.agent_buf, 0, -1, false), "\n"):find("second line", 1, true) ~= nil]],
        3000,
        "the comments to arrive"
    )
    local text = terminal_text()
    eq(text:find("[200~", 1, true) ~= nil, true)
    eq(text:find("[201~", 1, true) ~= nil, true)
end

T["to_terminal()"]["says no when there is no agent terminal"] = function()
    child.config({ agent = { pattern = "claude" } })
    eq(child.lua_get([[require("volley.agent").to_terminal("anything")]]), false)
end

return T
