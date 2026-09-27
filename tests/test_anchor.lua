local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function map(base, cur, l1, l2)
    return require("volley.anchor").map(base, cur, l1, l2)
end

-- A six line file with a comment on lines 3 and 4.
local BASE = { "a", "b", "c", "d", "e", "f" }

T["lines inserted above shift the range down"] = function()
    eq({ map(BASE, { "x", "y", "a", "b", "c", "d", "e", "f" }, 3, 4) }, { 5, 6, "same" })
end

T["lines deleted above shift the range up"] = function()
    eq({ map(BASE, { "b", "c", "d", "e", "f" }, 3, 4) }, { 2, 3, "same" })
end

T["lines inserted below leave it alone"] = function()
    eq({ map(BASE, { "a", "b", "c", "d", "e", "f", "g" }, 3, 4) }, { 3, 4, "same" })
end

T["a line inserted right before the range moves it, not into it"] = function()
    eq({ map(BASE, { "a", "b", "z", "c", "d", "e", "f" }, 3, 4) }, { 4, 5, "same" })
end

T["a line inserted right after the range does not grow it"] = function()
    eq({ map(BASE, { "a", "b", "c", "d", "z", "e", "f" }, 3, 4) }, { 3, 4, "same" })
end

T["nothing changed means nothing moved"] = function()
    eq({ map(BASE, BASE, 3, 4) }, { 3, 4, "same" })
end

T["a rewritten line inside the range keeps the place and says so"] = function()
    eq({ map(BASE, { "a", "b", "c", "D", "e", "f" }, 3, 4) }, { 3, 4, "changed" })
end

T["a line inserted inside the range grows it and says so"] = function()
    eq({ map(BASE, { "a", "b", "c", "z", "d", "e", "f" }, 3, 4) }, { 3, 5, "changed" })
end

T["one line of the range deleted shrinks it and says so"] = function()
    eq({ map(BASE, { "a", "b", "d", "e", "f" }, 3, 4) }, { 3, 3, "changed" })
end

T["the whole range deleted is gone"] = function()
    local l1, l2, how = map(BASE, { "a", "b", "e", "f" }, 3, 4)
    eq({ l1, l2, how }, { nil, nil, "gone" })
end

T["an empty file is gone"] = function()
    local _, _, how = map(BASE, {}, 3, 4)
    eq(how, "gone")
end

local function numbered(prefix, n)
    local out = {}
    for i = 1, n do
        out[i] = prefix .. i
    end
    return out
end

T["a rewrite of most of the file is not trusted"] = function()
    local base = numbered("l", 40)
    local _, _, how = map(base, numbered("m", 40), 3, 4)
    eq(how, "unsure")
end

T["a big rewrite elsewhere in the file is fine"] = function()
    local base = numbered("l", 40)
    local cur = {}
    for i = 1, 10 do
        cur[i] = base[i]
    end
    for i = 11, 40 do
        cur[i] = "m" .. i
    end
    eq({ map(base, cur, 3, 4) }, { 3, 4, "same" })
end

-- Edges of the file.

T["a comment on line 1 survives lines added at the very top"] = function()
    eq({ map(BASE, { "x", "a", "b", "c", "d", "e", "f" }, 1, 1) }, { 2, 2, "same" })
end

T["a comment on the last line survives lines appended after it"] = function()
    eq({ map(BASE, { "a", "b", "c", "d", "e", "f", "g", "h" }, 6, 6) }, { 6, 6, "same" })
end

T["a comment on the last line follows a deletion above it"] = function()
    eq({ map(BASE, { "a", "c", "d", "e", "f" }, 6, 6) }, { 5, 5, "same" })
end

T["a comment covering the whole file grows with it"] = function()
    eq({ map(BASE, { "a", "b", "z", "c", "d", "e", "f" }, 1, 6) }, { 1, 7, "changed" })
end

-- Single lines.

T["a single line with a line added right after it stays where it is"] = function()
    eq({ map(BASE, { "a", "b", "c", "z", "d", "e", "f" }, 3, 3) }, { 3, 3, "same" })
end

T["a single line rewritten is changed in place"] = function()
    eq({ map(BASE, { "a", "b", "C", "d", "e", "f" }, 3, 3) }, { 3, 3, "changed" })
end

T["a single line deleted is gone"] = function()
    local _, _, how = map(BASE, { "a", "b", "d", "e", "f" }, 3, 3)
    eq(how, "gone")
end

-- Several edits at once.

T["edits above add up"] = function()
    -- one line added after a, b deleted, two lines added after e
    eq({ map(BASE, { "a", "x", "c", "d", "e", "y", "z", "f" }, 3, 4) }, { 3, 4, "same" })
end

T["a change that overlaps the start of the range is changed, not gone"] = function()
    -- b and c replaced by three lines; the range was c and d
    eq({ map(BASE, { "a", "X", "Y", "Z", "d", "e", "f" }, 3, 4) }, { 4, 5, "changed" })
end

T["a change that overlaps the end of the range is changed, not gone"] = function()
    -- d and e replaced by one line; the range was c and d
    eq({ map(BASE, { "a", "b", "c", "W", "f" }, 3, 4) }, { 3, 4, "changed" })
end

-- Whitespace. Formatters do this to whole files, and a formatter run is not
-- an edit worth flagging.

T["reindenting the whole file moves nothing and changes nothing"] = function()
    local base = { "def f():", "  x = 1", "  if x:", "    y = 2", "  return y" }
    local cur = { "def f():", "    x = 1", "    if x:", "        y = 2", "    return y" }
    eq({ map(base, cur, 3, 4) }, { 3, 4, "same" })
end

T["trailing whitespace added under a comment is not a change"] = function()
    eq({ map(BASE, { "a", "b", "c   ", "d", "e", "f" }, 3, 4) }, { 3, 4, "same" })
end

T["a real edit inside a reindented file is still seen"] = function()
    local base = { "def f():", "  x = 1", "  if x:", "    y = 2", "  return y" }
    local cur = { "def f():", "    x = 1", "    if x:", "        y = 3", "    return y" }
    eq({ map(base, cur, 3, 4) }, { 3, 4, "changed" })
end

-- Blank lines are code too.

T["a comment on a blank line follows it"] = function()
    local base = { "a", "", "b", "", "c" }
    -- a text search for "" would grab line 2; the comment was on line 4
    eq({ map(base, { "x", "a", "", "b", "", "c" }, 4, 4) }, { 5, 5, "same" })
end

-- Bad input does not escape the file.

T["a range past the end of the baseline is clamped rather than crashing"] = function()
    local l1, l2, how = map(BASE, { "a", "b", "c" }, 5, 9)
    eq(how, "gone")
    eq({ l1, l2 }, { nil, nil })
end

return T
