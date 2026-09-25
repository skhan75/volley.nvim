local H = dofile("tests/helpers.lua")
local T = MiniTest.new_set()
local eq = MiniTest.expect.equality

local function git()
    return require("volley.source.git")
end

local BASE = { "def total(items):", "    return 0" }

local function by_path(files)
    local out = {}
    for _, f in ipairs(files) do
        out[f.path] = f
    end
    return out
end

T["root()"] = MiniTest.new_set()

T["root()"]["finds the repo a path is in"] = function()
    local dir = H.git_repo({ ["src/billing.py"] = BASE })
    eq(git().root(dir), dir)
    eq(git().root(dir .. "/src"), dir)
end

T["root()"]["is nil outside a repo"] = function()
    eq(git().root(H.tmpdir()), nil)
end

T["changeset()"] = MiniTest.new_set()

T["changeset()"]["is empty in a clean repo"] = function()
    local dir = H.git_repo({ ["src/billing.py"] = BASE })
    eq(git().changeset(dir).files, {})
end

T["changeset()"]["reports a modified file with its hunks"] = function()
    local dir = H.git_repo({ ["src/billing.py"] = BASE })
    H.write(
        dir .. "/src/billing.py",
        { "def total(items):", "    return sum(items)", "", "def tax(x):" }
    )
    local files = git().changeset(dir).files
    eq(#files, 1)
    local f = files[1]
    eq({ f.path, f.status }, { "src/billing.py", "modified" })
    eq(f.counts, { added = 2, changed = 1, removed = 0 })
    eq(f.hunks[1], { kind = "change", lnum = 2, count = 1, removed = { "    return 0" } })
    eq(f.hunks[2], { kind = "add", lnum = 3, count = 2, removed = {} })
end

T["changeset()"]["counts every line of a new file as added"] = function()
    local dir = H.git_repo({ ["a.txt"] = { "one" } })
    H.write(dir .. "/new.py", { "x = 1", "y = 2" })
    local f = by_path(git().changeset(dir).files)["new.py"]
    eq(f.status, "added")
    eq(f.counts.added, 2)
end

T["changeset()"]["reports a deleted file"] = function()
    local dir = H.git_repo({ ["gone.py"] = { "x = 1" }, ["stay.py"] = { "y = 2" } })
    vim.fn.delete(dir .. "/gone.py")
    local f = by_path(git().changeset(dir).files)["gone.py"]
    eq(f.status, "deleted")
    eq(f.counts.removed, 1)
end

T["changeset()"]["handles paths with spaces"] = function()
    local dir = H.git_repo({ ["my dir/a b.py"] = { "x = 1" } })
    H.write(dir .. "/my dir/a b.py", { "x = 2" })
    local f = by_path(git().changeset(dir).files)["my dir/a b.py"]
    eq(f ~= nil, true)
    eq(f.counts.changed, 1)
end

T["changeset()"]["ignores files that only changed mode"] = function()
    local dir = H.git_repo({ ["run.sh"] = { "echo hi" } })
    H.run({ "chmod", "+x", dir .. "/run.sh" })
    eq(git().changeset(dir).files, {})
end

T["changeset()"]["skips a file bigger than the limit"] = function()
    local dir = H.git_repo({ ["big.txt"] = { "x" } })
    local big = {}
    for i = 1, 500 do
        big[i] = string.rep("y", 100)
    end
    H.write(dir .. "/big.txt", big)
    eq(git().changeset(dir, { max_filesize = 1000 }).files, {})
end

T["changeset()"]["sorts the files that changed most first"] = function()
    local dir = H.git_repo({ ["small.py"] = { "a" }, ["large.py"] = { "a" } })
    H.write(dir .. "/small.py", { "a", "b" })
    H.write(dir .. "/large.py", { "a", "b", "c", "d", "e" })
    local files = git().changeset(dir).files
    eq(files[1].path, "large.py")
end

T["before()"] = MiniTest.new_set()

T["before()"]["gives the committed text of a file"] = function()
    local dir = H.git_repo({ ["src/billing.py"] = BASE })
    H.write(dir .. "/src/billing.py", { "changed" })
    eq(git().before(dir, "src/billing.py"), BASE)
end

T["before()"]["is empty for a file that is new"] = function()
    local dir = H.git_repo({ ["a.txt"] = { "one" } })
    H.write(dir .. "/new.py", { "x" })
    eq(git().before(dir, "new.py"), {})
end

return T
