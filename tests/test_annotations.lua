local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
    hooks = {
        -- Options are global, so every case starts from the defaults.
        pre_case = function()
            require("volley.config").setup({})
        end,
    },
})

local function ann()
    package.loaded["volley.annotations"] = nil
    return require("volley.annotations")
end

local CODE = { 'if code == "WELCOME":', '    return amount * Decimal("0.1")' }

local function add(a, over)
    return a.add(vim.tbl_extend("force", {
        path = "src/billing.py",
        abs = "/proj/src/billing.py",
        lnum = 22,
        end_lnum = 23,
        comment = "why is this hardcoded",
        code = CODE,
    }, over or {}))
end

T["add and list"] = MiniTest.new_set()

T["add and list"]["keeps what you wrote, where you wrote it"] = function()
    local a = ann()
    local id = add(a)
    local item = a.get(id)
    eq({ item.path, item.lnum, item.end_lnum, item.comment, item.status }, {
        "src/billing.py",
        22,
        23,
        "why is this hardcoded",
        "open",
    })
    eq(item.code, CODE)
end

T["add and list"]["lists by file, then by line"] = function()
    local a = ann()
    add(a, { path = "z.py", lnum = 5, end_lnum = 5 })
    add(a, { path = "a.py", lnum = 90, end_lnum = 90 })
    add(a, { path = "a.py", lnum = 12, end_lnum = 12 })
    local order = vim.tbl_map(function(i)
        return i.path .. ":" .. i.lnum
    end, a.list())
    eq(order, { "a.py:12", "a.py:90", "z.py:5" })
end

T["add and list"]["can drop one or all of them"] = function()
    local a = ann()
    local id = add(a)
    add(a, { lnum = 40, end_lnum = 40 })
    a.remove(id)
    eq(#a.list(), 1)
    a.clear()
    eq(#a.list(), 0)
end

T["add and list"]["counts what is open"] = function()
    local a = ann()
    add(a)
    local id = add(a, { lnum = 40, end_lnum = 40 })
    a.mark_sent({ id })
    eq(a.counts(), { open = 1, sent = 1, stale = 0 })
end

T["reanchor"] = MiniTest.new_set()

T["reanchor"]["follows the code when lines move"] = function()
    local a = ann()
    local id = add(a)
    -- two lines inserted above, so the code now starts at 24
    local lines = {}
    for i = 1, 23 do
        lines[i] = "filler " .. i
    end
    lines[24], lines[25] = CODE[1], CODE[2]
    a.reanchor("/proj/src/billing.py", lines)
    local item = a.get(id)
    eq({ item.lnum, item.end_lnum, item.status }, { 24, 25, "open" })
end

T["reanchor"]["still finds it when a line inside was rewritten"] = function()
    local a = ann()
    local id = add(a)
    local lines = {}
    for i = 1, 21 do
        lines[i] = "filler " .. i
    end
    lines[22] = CODE[1]
    lines[23] = "    return amount * Decimal(DISCOUNT)" -- agent rewrote this line
    a.reanchor("/proj/src/billing.py", lines)
    eq(a.get(id).lnum, 22)
    eq(a.get(id).status, "open")
end

T["reanchor"]["marks it stale when the code is gone"] = function()
    local a = ann()
    local id = add(a)
    a.reanchor("/proj/src/billing.py", { "nothing", "like", "the original" })
    eq(a.get(id).status, "stale")
end

T["reanchor"]["drops it instead when you asked for that"] = function()
    require("volley.config").setup({ stale = "drop" })
    local a = ann()
    local id = add(a)
    add(a, { path = "other.py", abs = "/proj/other.py", comment = "somewhere else" })
    a.reanchor("/proj/src/billing.py", { "nothing", "like", "the original" })
    eq(a.get(id), nil)
    eq(#a.list(), 1)
end

T["reanchor"]["leaves other files alone"] = function()
    local a = ann()
    local id = add(a)
    a.reanchor("/proj/other.py", { "unrelated" })
    eq(a.get(id).status, "open")
end

T["reanchor"]["a stale comment comes back if its code returns"] = function()
    local a = ann()
    local id = add(a)
    a.reanchor("/proj/src/billing.py", { "gone" })
    eq(a.get(id).status, "stale")
    local lines = { CODE[1], CODE[2] }
    a.reanchor("/proj/src/billing.py", lines)
    eq({ a.get(id).status, a.get(id).lnum }, { "open", 1 })
end

T["payload"] = MiniTest.new_set()

T["payload"]["numbers the comments and says where each one is"] = function()
    local a = ann()
    add(a)
    add(a, {
        path = "src/routes.py",
        lnum = 40,
        end_lnum = 40,
        comment = "add a test",
        code = { "def route():" },
    })
    local text = a.payload()
    eq(text:match("1%. src/billing%.py lines 22%-23") ~= nil, true)
    eq(text:match("2%. src/routes%.py line 40") ~= nil, true)
    eq(text:find("why is this hardcoded", 1, true) ~= nil, true)
    eq(text:find("add a test", 1, true) ~= nil, true)
end

T["payload"]["includes the code each comment points at"] = function()
    local a = ann()
    add(a)
    eq(a.payload():find('return amount * Decimal("0.1")', 1, true) ~= nil, true)
end

T["payload"]["says when a comment's code has moved on"] = function()
    local a = ann()
    add(a)
    a.reanchor("/proj/src/billing.py", { "gone" })
    eq(a.payload():lower():find("moved or gone", 1, true) ~= nil, true)
end

T["payload"]["only sends what is still open"] = function()
    local a = ann()
    local sent = add(a)
    add(a, { lnum = 40, end_lnum = 40, comment = "second one" })
    a.mark_sent({ sent })
    local text = a.payload()
    eq(text:find("why is this hardcoded", 1, true), nil)
    eq(text:find("second one", 1, true) ~= nil, true)
end

T["payload"]["is nil when nothing is queued"] = function()
    eq(ann().payload(), nil)
end

return T
