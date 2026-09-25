local H = dofile("tests/helpers.lua")
local eq = MiniTest.expect.equality

local child = H.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.start_editor()
            child.lua("require('volley.config').setup({ picker = 'builtin' })")
        end,
        post_once = child.stop,
    },
})

local ITEMS = [[{
  { text = "src/billing.py   +14 ~2 -0", file = "/p/src/billing.py", preview = { "18 def total():", "19 +   return 1" } },
  { text = "src/routes.py     +3 ~1 -0", file = "/p/src/routes.py", preview = { "40 + def route():" } },
  { text = "README.md         +2 ~0 -0", file = "/p/README.md", preview = { "1 # app" } },
}]]

local function open(extra)
    child.lua(([[
        _G.chosen = nil
        require("volley.ui.float").pick(%s, { prompt = "volley  3 files changed"%s }, function(item)
            _G.chosen = item.text
        end)
    ]]):format(ITEMS, extra or ""))
end

-- The list is the left pane, the preview the right one.
local function floats()
    return child.lua_get([[
        (function()
            local wins = vim.tbl_filter(function(w)
                return vim.api.nvim_win_get_config(w).relative ~= ""
            end, vim.api.nvim_list_wins())
            table.sort(wins, function(a, b)
                return vim.api.nvim_win_get_config(a).col < vim.api.nvim_win_get_config(b).col
            end)
            return wins
        end)()
    ]])
end

local function lines_of(win)
    return child.lua_get(
        "vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(" .. win .. "), 0, -1, false)"
    )
end

T["shows the list and a preview beside it"] = function()
    open()
    local wins = floats()
    eq(#wins, 2)
    local list = table.concat(lines_of(wins[1]), "\n")
    eq(list:find("src/billing.py", 1, true) ~= nil, true)
    eq(list:find("README.md", 1, true) ~= nil, true)
    local preview = table.concat(lines_of(wins[2]), "\n")
    eq(preview:find("return 1", 1, true) ~= nil, true)
end

T["pins the counts to the right edge and never wraps"] = function()
    child.lua([[
        local wide = string.rep("src/very/deep/", 8) .. "billing.py"
        require("volley.ui.float").pick(
            { { left = wide, right = "+14 ~2 -0", text = wide .. " +14 ~2 -0", file = "/p/a.py" } },
            { prompt = "volley", preview = false },
            function() end
        )
    ]])
    local win = floats()[1]
    local width = child.lua_get("vim.api.nvim_win_get_width(" .. win .. ")")
    local line = lines_of(win)[1]
    eq(vim.fn.strdisplaywidth(line), width)
    eq(line:sub(-9), "+14 ~2 -0")
    eq(line:find("billing.py", 1, true) ~= nil, true) -- the useful end of the path survives
    eq(child.lua_get("vim.wo[" .. win .. "].wrap"), false)
end

T["puts the title on the window"] = function()
    open()
    local title = child.lua_get([[
        (function()
            local cfg = vim.api.nvim_win_get_config(vim.api.nvim_get_current_win())
            return type(cfg.title) == "table" and cfg.title[1][1] or cfg.title
        end)()
    ]])
    eq(tostring(title):find("3 files changed", 1, true) ~= nil, true)
end

T["moving down follows the preview"] = function()
    open()
    child.type_keys("j")
    local wins = floats()
    local preview = table.concat(lines_of(wins[2]), "\n")
    eq(preview:find("def route", 1, true) ~= nil, true)
end

T["enter picks the row you are on"] = function()
    open()
    child.type_keys("j", "<CR>")
    eq(child.lua_get("_G.chosen"), "src/routes.py     +3 ~1 -0")
    eq(#floats(), 0)
end

T["q closes without picking"] = function()
    open()
    child.type_keys("q")
    eq(child.lua_get("_G.chosen"), vim.NIL)
    eq(#floats(), 0)
end

T["escape closes it too"] = function()
    open()
    child.type_keys("<Esc>")
    eq(#floats(), 0)
end

T["works without a preview"] = function()
    child.lua([[
        _G.chosen = nil
        require("volley.ui.float").pick(
            { { text = "one comment", file = "/p/a.py" } },
            { prompt = "queue", preview = false },
            function(item) _G.chosen = item.text end
        )
    ]])
    eq(#floats(), 1)
    child.type_keys("<CR>")
    eq(child.lua_get("_G.chosen"), "one comment")
end

T["says so when there is nothing to show"] = function()
    child.lua([[
        require("volley.ui.float").pick({}, { prompt = "empty" }, function() end)
    ]])
    eq(#floats(), 0)
end

return T
