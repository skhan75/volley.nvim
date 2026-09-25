local H = dofile("tests/helpers.lua")
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function snap()
    return require("volley.source.snapshot")
end

local function project(files)
    local dir = H.tmpdir()
    for name, lines in pairs(files) do
        H.write(dir .. "/" .. name, lines)
    end
    return dir
end

local function by_path(files)
    local out = {}
    for _, f in ipairs(files) do
        out[f.path] = f
    end
    return out
end

T["take() and exists()"] = MiniTest.new_set()

T["take() and exists()"]["a project has no snapshot until you take one"] = function()
    local dir = project({ ["a.py"] = { "x = 1" } })
    eq(snap().exists(dir), false)
    snap().take(dir)
    eq(snap().exists(dir), true)
    snap().clear(dir)
    eq(snap().exists(dir), false)
end

T["take() and exists()"]["reports how much it stored"] = function()
    local dir = project({ ["a.py"] = { "x = 1" }, ["b/c.py"] = { "y = 2" } })
    local info = snap().take(dir)
    eq(info.files, 2)
end

T["changeset()"] = MiniTest.new_set()

T["changeset()"]["is empty right after a snapshot"] = function()
    local dir = project({ ["a.py"] = { "x = 1" } })
    snap().take(dir)
    eq(snap().changeset(dir).files, {})
end

T["changeset()"]["reports an edited file with its hunks"] = function()
    local dir = project({ ["a.py"] = { "x = 1", "y = 2" } })
    snap().take(dir)
    H.write(dir .. "/a.py", { "x = 99", "y = 2", "z = 3" })
    local f = snap().changeset(dir).files[1]
    eq({ f.path, f.status }, { "a.py", "modified" })
    eq(f.counts, { added = 1, changed = 1, removed = 0 })
    eq(f.before, { "x = 1", "y = 2" })
end

T["changeset()"]["reports a file the agent created"] = function()
    local dir = project({ ["a.py"] = { "x = 1" } })
    snap().take(dir)
    H.write(dir .. "/new.py", { "n = 1" })
    local f = by_path(snap().changeset(dir).files)["new.py"]
    eq({ f.status, f.counts.added }, { "added", 1 })
end

T["changeset()"]["reports a file that went away"] = function()
    local dir = project({ ["a.py"] = { "x = 1" }, ["b.py"] = { "y = 2" } })
    snap().take(dir)
    vim.fn.delete(dir .. "/b.py")
    local f = by_path(snap().changeset(dir).files)["b.py"]
    eq({ f.status, f.counts.removed }, { "deleted", 1 })
end

T["what it stores"] = MiniTest.new_set()

T["what it stores"]["skips directories nobody wants to diff"] = function()
    local dir = project({
        ["a.py"] = { "x = 1" },
        ["node_modules/dep/index.js"] = { "junk" },
        [".git/config"] = { "junk" },
        ["dist/bundle.js"] = { "junk" },
    })
    eq(snap().take(dir).files, 1)
end

T["what it stores"]["skips files that are too big"] = function()
    local big = {}
    for i = 1, 300 do
        big[i] = string.rep("y", 100)
    end
    local dir = project({ ["a.py"] = { "x = 1" }, ["big.txt"] = big })
    eq(snap().take(dir, { max_filesize = 1000 }).files, 1)
end

T["what it stores"]["skips binary files"] = function()
    local dir = project({ ["a.py"] = { "x = 1" } })
    local f = assert(io.open(dir .. "/logo.png", "wb"))
    f:write("\137PNG\r\n\26\n\0\0\0\rIHDR\0\0")
    f:close()
    eq(snap().take(dir).files, 1)
end

T["what it stores"]["honours extra ignore patterns"] = function()
    local dir = project({ ["a.py"] = { "x = 1" }, ["vendor/lib.py"] = { "y = 2" } })
    eq(snap().take(dir, { ignore = { "vendor" } }).files, 1)
end

T["what it stores"]["stops at the file limit and says so"] = function()
    local files = {}
    for i = 1, 12 do
        files["f" .. i .. ".py"] = { "x" }
    end
    local dir = project(files)
    local info = snap().take(dir, { max_files = 5 })
    eq(info.files, 5)
    eq(info.truncated, true)
end

T["what it stores"]["keeps projects apart"] = function()
    local a = project({ ["a.py"] = { "1" } })
    local b = project({ ["a.py"] = { "2" } })
    snap().take(a)
    snap().take(b)
    H.write(a .. "/a.py", { "1", "extra" })
    eq(#snap().changeset(a).files, 1)
    eq(#snap().changeset(b).files, 0)
end

return T
