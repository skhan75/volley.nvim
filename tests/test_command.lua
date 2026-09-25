local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child = H.new_child()
local dir

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            dir = H.git_repo({ ["a.py"] = { "x = 1" } })
            child.start_editor()
            child.lua("vim.fn.chdir(...)", { dir })
            child.cmd("runtime plugin/volley.lua")
            child.lua([[
                vim.ui.select = function(items, opts, on_choice) _G.picked = items end
                vim.ui.input = function(_, on_confirm) on_confirm("a comment") end
            ]])
        end,
        post_once = child.stop,
    },
})

T[":Volley"] = MiniTest.new_set()

T[":Volley"]["with no arguments opens the review"] = function()
    child.setup({ picker = "builtin" })
    child.cmd("Volley")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('nothing') ~= nil"), true)
end

T[":Volley"]["snapshot takes a baseline"] = function()
    child.setup({ picker = "builtin" })
    child.cmd("Volley snapshot")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('snapshot taken') ~= nil"), true)
end

T[":Volley"]["send says when there is nothing queued"] = function()
    child.setup({ picker = "builtin" })
    child.cmd("Volley send")
    eq(child.lua_get("_G.notes[#_G.notes].msg:lower():find('nothing to send') ~= nil"), true)
end

T[":Volley"]["clear throws the comments away"] = function()
    child.setup({ picker = "builtin" })
    child.cmd("edit " .. dir .. "/a.py")
    child.lua("v().annotate()")
    eq(child.lua_get("v().status().open"), 1)
    child.cmd("Volley clear")
    eq(child.lua_get("v().status().open"), 0)
end

T[":Volley"]["reports an unknown subcommand"] = function()
    child.setup({ picker = "builtin" })
    child.cmd("Volley wat")
    eq(child.lua_get("_G.notes[#_G.notes].msg:find('wat') ~= nil"), true)
end

T[":Volley"]["completes its subcommands"] = function()
    eq(child.lua_get("vim.fn.getcompletion('Volley ', 'cmdline')"), {
        "annotate",
        "clear",
        "next",
        "open",
        "prev",
        "queue",
        "send",
        "snapshot",
        "status",
    })
end

T["keys"] = MiniTest.new_set()

T["keys"]["maps opening and annotating out of the box"] = function()
    child.setup({})
    eq(child.lua_get("vim.fn.maparg('<leader>v', 'n') ~= ''"), true)
    eq(child.lua_get("vim.fn.maparg('<leader>va', 'x') ~= ''"), true)
end

T["keys"]["maps nothing you turned off"] = function()
    child.setup({ key = false, keys = { annotate = false, queue = false, send = false } })
    eq(child.lua_get("vim.fn.maparg('<leader>v', 'n')"), "")
    eq(child.lua_get("vim.fn.maparg('<leader>va', 'x')"), "")
end

T["checkhealth"] = MiniTest.new_set()

local function health()
    child.cmd("checkhealth volley")
    return table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

T["checkhealth"]["warns when setup() was never called"] = function()
    eq(health():match("WARNING setup%(%) has not been called") ~= nil, true)
end

T["checkhealth"]["reports the picker and the source it will use"] = function()
    child.setup({ picker = "builtin" })
    local out = health()
    eq(out:match("OK picker: builtin") ~= nil, true)
    eq(out:match("OK changes come from git") ~= nil, true)
end

T["checkhealth"]["says when the agent command is missing"] = function()
    child.setup({ agent = { cmd = { "definitely-not-installed-xyz" } } })
    eq(health():match("ERROR .*definitely%-not%-installed%-xyz") ~= nil, true)
end

return T
