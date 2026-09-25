-- Shared test helpers: temp projects, real git repos, and a child Neovim.
local H = {}

function H.tmpdir()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    return vim.uv.fs_realpath(dir)
end

function H.write(path, lines)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(lines, path)
end

function H.read(path)
    return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or nil
end

function H.run(cmd, cwd)
    local res = vim.system(cmd, { cwd = cwd, text = true }):wait()
    assert(res.code == 0, ("%s failed: %s"):format(table.concat(cmd, " "), res.stderr or ""))
    return res.stdout or ""
end

---A git repo with `files` committed.
---@param files table<string, string[]>
---@return string dir
function H.git_repo(files)
    local dir = H.tmpdir()
    H.run({ "git", "init", "-q", "-b", "main" }, dir)
    for name, lines in pairs(files or {}) do
        H.write(dir .. "/" .. name, lines)
    end
    H.run({ "git", "add", "-A" }, dir)
    H.run({
        "git",
        "-c",
        "user.name=test",
        "-c",
        "user.email=test@example.com",
        "commit",
        "-qm",
        "init",
    }, dir)
    return dir
end

function H.now()
    return vim.uv.hrtime() / 1e6
end

function H.sleep(ms)
    vim.uv.sleep(ms)
end

---@return MiniTest.child
function H.new_child()
    local child = MiniTest.new_child_neovim()

    child.setup = function(opts)
        child.lua("require('volley').setup(...)", { opts or {} })
    end

    -- Options only, for tests that exercise one module.
    child.config = function(opts)
        child.lua("require('volley.config').setup(...)", { opts or {} })
    end

    child.start_editor = function()
        child.restart({ "-u", "tests/minimal_init.lua" })
        child.o.lines, child.o.columns = 36, 120
        child.lua([[
            _G.v = function() return require("volley") end
            _G.notes = {}
            vim.notify = function(msg, level) table.insert(_G.notes, { msg = msg, level = level }) end
        ]])
    end

    return child
end

function H.wait(child, expr, timeout_ms, what, args)
    local deadline = H.now() + (timeout_ms or 3000)
    while H.now() < deadline do
        local v = child.lua_get(expr, args)
        if v and v ~= vim.NIL then
            return
        end
        vim.uv.sleep(20)
    end
    error(("timed out after %dms waiting for %s"):format(timeout_ms or 3000, what or expr), 2)
end

return H
