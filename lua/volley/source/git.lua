-- What changed, according to git. Compares your working tree with the last
-- commit, so files you never opened are included.

local diff = require("volley.diff")

local M = {}

local function run(args, cwd)
    local res = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
    if res.code ~= 0 then
        return nil, (res.stderr or ""):gsub("%s+$", "")
    end
    return res.stdout or ""
end

---The repo a path belongs to, or nil.
---@param path string
---@return string|nil
function M.root(path)
    local out = run({ "rev-parse", "--show-toplevel" }, path)
    if not out or out == "" then
        return nil
    end
    return vim.uv.fs_realpath((out:gsub("%s+$", "")))
end

---The committed text of a file, or {} when git has never seen it.
---@return string[]
function M.before(root, path)
    local out = run({ "show", "HEAD:" .. path }, root)
    if not out then
        return {}
    end
    return vim.split(out:gsub("\n$", ""), "\n", { plain = true })
end

local function current(abs)
    if vim.fn.filereadable(abs) ~= 1 then
        return {}
    end
    return vim.fn.readfile(abs)
end

-- "XY path" records from --porcelain, NUL separated so spaces are safe.
local function entries(root)
    local out = run({ "status", "--porcelain=v1", "-z", "--untracked-files=all" }, root)
    if not out then
        return {}
    end
    local list = {}
    local parts = vim.split(out, "\0", { plain = true })
    local i = 1
    while i <= #parts do
        local rec = parts[i]
        if rec ~= "" then
            local xy, path = rec:sub(1, 2), rec:sub(4)
            if xy:sub(1, 1) == "R" then
                -- A rename is followed by its old path; treat the new one as added.
                i = i + 1
            end
            list[#list + 1] = { xy = xy, path = path }
        end
        i = i + 1
    end
    return list
end

local function status_of(xy)
    if xy:find("D") then
        return "deleted"
    elseif xy == "??" or xy:find("A") or xy:find("R") then
        return "added"
    end
    return "modified"
end

---Everything that changed in `root`.
---@param root string
---@param opts { max_filesize: integer|nil }|nil
---@return { root: string, source: string, files: table[] }
function M.changeset(root, opts)
    opts = opts or {}
    local max = opts.max_filesize or 1024 * 1024
    local files = {}
    for _, e in ipairs(entries(root)) do
        local abs = root .. "/" .. e.path
        local stat = vim.uv.fs_stat(abs)
        local too_big = stat and stat.size > max
        if not too_big and (not stat or stat.type == "file") then
            local status = status_of(e.xy)
            local before = status == "added" and {} or M.before(root, e.path)
            local after = current(abs)
            local hunks = diff.hunks(before, after)
            if #hunks > 0 then
                local counts = diff.counts(hunks)
                files[#files + 1] = {
                    path = e.path,
                    abs = abs,
                    status = status,
                    hunks = hunks,
                    counts = counts,
                    before = before,
                }
            end
        end
    end
    -- Biggest change first: that is usually what you want to look at.
    table.sort(files, function(a, b)
        local ca = a.counts.added + a.counts.changed + a.counts.removed
        local cb = b.counts.added + b.counts.changed + b.counts.removed
        if ca ~= cb then
            return ca > cb
        end
        return a.path < b.path
    end)
    return { root = root, source = "git", files = files }
end

return M
