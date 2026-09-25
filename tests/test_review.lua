local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child = H.new_child()
local dir

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            dir = H.git_repo({
                ["src/billing.py"] = {
                    "def total(items):",
                    "    return 0",
                    "",
                    "def tax(x):",
                    "    return 0",
                },
                ["README.md"] = { "# app" },
            })
            child.start_editor()
            child.lua("vim.fn.chdir(...)", { dir })
            -- Pickers and prompts are stubbed so tests can drive them.
            child.lua([[
                _G.picked = nil
                _G.answer = "why is this hardcoded"
                vim.ui.select = function(items, opts, on_choice)
                    _G.picked = { items = items, prompt = opts and opts.prompt }
                    if _G.choose then on_choice(items[_G.choose], _G.choose) end
                end
                vim.ui.input = function(opts, on_confirm) on_confirm(_G.answer) end
            ]])
        end,
        post_once = child.stop,
    },
})

-- A stand-in for the claude CLI. It lives outside the project, or volley
-- would rightly report the script itself as a new file.
local bin
local function fake_cli(reply)
    bin = bin or H.tmpdir()
    local path = bin .. "/fake-claude.sh"
    H.write(path, {
        "#!/bin/sh",
        'printf "%s" "$*" > ' .. bin .. "/args.txt",
        "cat <<'JSON'",
        ('{"result":"%s","session_id":"s1","total_cost_usd":0.02}'):format(reply or "1. Done."),
        "JSON",
    })
    vim.fn.setfperm(path, "rwxr-xr-x")
    return path
end

local function setup(extra)
    child.setup(vim.tbl_deep_extend("force", {
        picker = "select",
        agent = { cmd = { fake_cli() }, require_idle = false },
    }, extra or {}))
end

local function edit_file()
    H.write(dir .. "/src/billing.py", {
        "def total(items):",
        "    return sum(items)",
        "",
        "def tax(x):",
        "    return x * 0.2",
        "",
        "def discount(x):",
        "    return x * 0.1",
    })
end

T["open()"] = MiniTest.new_set()

T["open()"]["says so when nothing has changed"] = function()
    setup()
    child.lua("v().open()")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('nothing') ~= nil"), true)
end

T["open()"]["lists the files the agent touched, with counts"] = function()
    setup()
    edit_file()
    child.lua("v().open()")
    local items = child.lua_get("vim.tbl_map(function(i) return i.text end, _G.picked.items)")
    eq(#items, 1)
    eq(items[1]:find("src/billing.py", 1, true) ~= nil, true)
    eq(items[1]:find("+3", 1, true) ~= nil, true)
end

T["open()"]["opens the file you pick at its first change"] = function()
    setup()
    edit_file()
    child.lua("_G.choose = 1")
    child.lua("v().open()")
    eq(child.lua_get("vim.fn.expand('%:t')"), "billing.py")
    eq(child.api.nvim_win_get_cursor(0)[1], 2)
end

T["open()"]["shows the changed lines beside the list, with no picker installed"] = function()
    setup({ picker = "builtin" })
    edit_file()
    child.lua("v().open()")
    local panes = child.lua_get([[
        (function()
            local wins = vim.tbl_filter(function(w)
                return vim.api.nvim_win_get_config(w).relative ~= ""
            end, vim.api.nvim_list_wins())
            table.sort(wins, function(a, b)
                return vim.api.nvim_win_get_config(a).col < vim.api.nvim_win_get_config(b).col
            end)
            return vim.tbl_map(function(w)
                return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false), "\n")
            end, wins)
        end)()
    ]])
    eq(#panes, 2)
    eq(panes[1]:find("src/billing.py", 1, true) ~= nil, true)
    -- the right pane shows what the agent wrote, not the whole file
    eq(panes[2]:find("return sum(items)", 1, true) ~= nil, true)
    eq(panes[2]:find("def discount(x):", 1, true) ~= nil, true)
    eq(panes[2]:find("return 0", 1, true) ~= nil, true) -- and what it replaced
    eq(panes[2]:find("def total(items):", 1, true), nil) -- untouched lines stay out
end

T["annotate()"] = MiniTest.new_set()

T["annotate()"]["stores the comment with the code it points at"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.api.nvim_win_set_cursor(0, { 7, 0 })
    child.type_keys("Vj", "<Esc>")
    child.lua("v().annotate()")
    local list = child.lua_get("require('volley.annotations').list()")
    eq(#list, 1)
    eq({ list[1].path, list[1].lnum, list[1].end_lnum }, { "src/billing.py", 7, 8 })
    eq(list[1].code, { "def discount(x):", "    return x * 0.1" })
    eq(list[1].comment, "why is this hardcoded")
end

T["annotate()"]["takes just the line the cursor is on"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.api.nvim_win_set_cursor(0, { 2, 0 })
    child.lua("v().annotate()")
    local list = child.lua_get("require('volley.annotations').list()")
    eq({ list[1].lnum, list[1].end_lnum, list[1].code[1] }, { 2, 2, "    return sum(items)" })
end

T["annotate()"]["shows the comment in the file"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.api.nvim_win_set_cursor(0, { 2, 0 })
    child.lua("v().annotate()")
    local marks = child.lua_get([[
        vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("volley"), 0, -1, { details = true })
    ]])
    eq(#marks > 0, true)
    local text = vim.inspect(marks)
    eq(text:find("why is this hardcoded", 1, true) ~= nil, true)
end

T["annotate()"]["forgets a selection once you have moved away from it"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.api.nvim_win_set_cursor(0, { 7, 0 })
    child.type_keys("Vj", "<Esc>")
    child.lua("v().annotate()")
    -- a second comment, somewhere else entirely
    child.api.nvim_win_set_cursor(0, { 2, 0 })
    child.lua("v().annotate()")
    local list = child.lua_get("require('volley.annotations').list()")
    eq(#list, 2)
    eq({ list[1].lnum, list[1].end_lnum }, { 2, 2 })
    eq({ list[2].lnum, list[2].end_lnum }, { 7, 8 })
end

T["annotate()"]["writes nothing when you cancel the prompt"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.lua("_G.answer = nil")
    child.lua("v().annotate()")
    eq(child.lua_get("#require('volley.annotations').list()"), 0)
end

T["annotate()"]["follows its code when the agent edits the file again"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.api.nvim_win_set_cursor(0, { 7, 0 })
    child.lua("v().annotate()")
    -- the agent inserts two lines at the top, so the code moves down
    child.lua([[
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { "import math", "" })
        v().refresh()
    ]])
    eq(child.lua_get("require('volley.annotations').list()[1].lnum"), 9)
end

T["queue()"] = MiniTest.new_set()

T["queue()"]["lists what you have written so far"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.lua("v().annotate()")
    child.lua("v().queue()")
    local items = child.lua_get("vim.tbl_map(function(i) return i.text end, _G.picked.items)")
    eq(#items, 1)
    eq(items[1]:find("why is this hardcoded", 1, true) ~= nil, true)
end

T["send()"] = MiniTest.new_set()

T["send()"]["says so when there is nothing queued"] = function()
    setup()
    child.lua("v().send()")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('nothing') ~= nil"), true)
end

T["send()"]["sends the comments and shows the answer"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.lua("v().annotate()")
    child.lua("v().send()")
    H.wait(
        child,
        "require('volley.annotations').counts().sent == 1",
        6000,
        "the comment to be sent"
    )
    local args = table.concat(H.read(bin .. "/args.txt"), "\n")
    eq(args:find("why is this hardcoded", 1, true) ~= nil, true)
    -- the answer lands in a window you can read
    local shown = child.lua_get([[
        (function()
            for _, w in ipairs(vim.api.nvim_list_wins()) do
                local b = vim.api.nvim_win_get_buf(w)
                local txt = table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
                if txt:find("1. Done.", 1, true) then return true end
            end
            return false
        end)()
    ]])
    eq(shown, true)
end

T["send()"]["waits while the agent is still working"] = function()
    setup({ agent = { require_idle = true, idle_ms = 5000, pattern = "chatter" } })
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.lua("v().annotate()")
    child.lua([[
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_call(buf, function()
            vim.fn.jobstart({ "sh", "-c", "exec -a chatter sh -c 'while true; do echo working; sleep 0.2; done'" }, { term = true })
        end)
    ]])
    H.sleep(400)
    child.lua("v().send()")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('busy') ~= nil"), true)
    eq(child.lua_get("require('volley.annotations').counts().sent"), 0)
end

T["hunks"] = MiniTest.new_set()

T["hunks"]["next and prev move between the agent's changes"] = function()
    setup()
    edit_file()
    child.cmd("edit " .. dir .. "/src/billing.py")
    child.api.nvim_win_set_cursor(0, { 1, 0 })
    child.lua("v().next_hunk()")
    eq(child.api.nvim_win_get_cursor(0)[1], 2)
    child.lua("v().next_hunk()")
    eq(child.api.nvim_win_get_cursor(0)[1], 5)
    child.lua("v().prev_hunk()")
    eq(child.api.nvim_win_get_cursor(0)[1], 2)
end

T["without git"] = MiniTest.new_set()

T["without git"]["uses a snapshot you took earlier"] = function()
    local plain = H.tmpdir()
    H.write(plain .. "/a.py", { "x = 1" })
    child.lua("vim.fn.chdir(...)", { plain })
    setup()
    child.lua("v().snapshot()")
    H.write(plain .. "/a.py", { "x = 1", "y = 2" })
    child.lua("v().open()")
    local items = child.lua_get("vim.tbl_map(function(i) return i.text end, _G.picked.items)")
    eq(#items, 1)
    eq(items[1]:find("a.py", 1, true) ~= nil, true)
end

T["without git"]["asks you to take one when there is none"] = function()
    local plain = H.tmpdir()
    H.write(plain .. "/a.py", { "x = 1" })
    child.lua("vim.fn.chdir(...)", { plain })
    setup()
    child.lua("v().open()")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('snapshot') ~= nil"), true)
end

return T
