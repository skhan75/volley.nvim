-- What changed, for projects without git. volley copies the project's text
-- files once, when a review starts, and diffs against that copy.

local diff = require("volley.diff")

local M = {}

M.IGNORE = {
    ".git",
    ".hg",
    ".svn",
    "node_modules",
    ".venv",
    "venv",
    "__pycache__",
    ".mypy_cache",
    ".pytest_cache",
    "target",
    "dist",
    "build",
    ".next",
    ".cache",
    ".terraform",
    "vendor/bundle",
}

local function cache_root()
    return vim.fn.stdpath("cache") .. "/volley/snapshots"
end

---Where a project's snapshot lives.
function M.dir(root)
    -- The path itself keeps projects apart; the hash keeps the name short.
    local key = vim.fn.sha256 and vim.fn.sha256(root) or vim.fn.fnamemodify(root, ":t")
    return ("%s/%s"):format(cache_root(), key:sub(1, 24))
end

function M.exists(root)
    return vim.fn.isdirectory(M.dir(root) .. "/files") == 1
end

function M.clear(root)
    vim.fn.delete(M.dir(root), "rf")
end

local function ignored(name, extra)
    for _, pat in ipairs(M.IGNORE) do
        if name == pat then
            return true
        end
    end
    for _, pat in ipairs(extra or {}) do
        if name == pat then
            return true
        end
    end
    return false
end

local function is_binary(path)
    local f = io.open(path, "rb")
    if not f then
        return true
    end
    local head = f:read(1024) or ""
    f:close()
    return head:find("\0", 1, true) ~= nil
end

---Every text file worth diffing, as paths relative to `root`.
local function walk(root, opts)
    local max_size = opts.max_filesize or 1024 * 1024
    local max_files = opts.max_files or 5000
    local out, truncated = {}, false

    local function scan(dir, rel, depth)
        if truncated or depth > 20 then
            return
        end
        local handle = vim.uv.fs_scandir(dir)
        if not handle then
            return
        end
        while true do
            local name, kind = vim.uv.fs_scandir_next(handle)
            if not name then
                return
            end
            local path = dir .. "/" .. name
            local relpath = rel == "" and name or (rel .. "/" .. name)
            if kind == "directory" then
                if not ignored(name, opts.ignore) then
                    scan(path, relpath, depth + 1)
                end
            elseif kind == "file" and not ignored(name, opts.ignore) then
                local stat = vim.uv.fs_stat(path)
                if stat and stat.size <= max_size and not is_binary(path) then
                    if #out >= max_files then
                        truncated = true
                        return
                    end
                    out[#out + 1] = relpath
                end
            end
        end
    end

    scan(root, "", 1)
    return out, truncated
end

---Copy the project's text files so there is a "before" to compare with.
---@param root string
---@param opts { max_filesize: integer|nil, max_files: integer|nil, ignore: string[]|nil }|nil
---@return { files: integer, truncated: boolean }
function M.take(root, opts)
    opts = opts or {}
    M.clear(root)
    local dir = M.dir(root)
    vim.fn.mkdir(dir .. "/files", "p")
    local paths, truncated = walk(root, opts)
    for _, rel in ipairs(paths) do
        local dest = dir .. "/files/" .. rel
        vim.fn.mkdir(vim.fs.dirname(dest), "p")
        vim.uv.fs_copyfile(root .. "/" .. rel, dest)
    end
    vim.fn.writefile(
        { vim.json.encode({ root = root, files = #paths, truncated = truncated }) },
        dir .. "/meta.json"
    )
    return { files = #paths, truncated = truncated }
end

local function read(path)
    if vim.fn.filereadable(path) ~= 1 then
        return nil
    end
    return vim.fn.readfile(path)
end

---Everything that changed since the snapshot.
---@param root string
---@param opts table|nil
function M.changeset(root, opts)
    opts = opts or {}
    local snap = M.dir(root) .. "/files"
    if vim.fn.isdirectory(snap) ~= 1 then
        return { root = root, source = "snapshot", files = {}, missing = true }
    end

    local files, seen = {}, {}
    local function add(rel, before, after, status)
        local hunks = diff.hunks(before or {}, after or {})
        if #hunks > 0 then
            files[#files + 1] = {
                path = rel,
                abs = root .. "/" .. rel,
                status = status,
                hunks = hunks,
                counts = diff.counts(hunks),
                before = before or {},
            }
        end
    end

    for _, rel in ipairs((walk(root, opts))) do
        seen[rel] = true
        local before = read(snap .. "/" .. rel)
        add(rel, before, read(root .. "/" .. rel), before and "modified" or "added")
    end
    for _, rel in ipairs((walk(snap, opts))) do
        if not seen[rel] then
            add(rel, read(snap .. "/" .. rel), {}, "deleted")
        end
    end

    table.sort(files, function(a, b)
        local ca = a.counts.added + a.counts.changed + a.counts.removed
        local cb = b.counts.added + b.counts.changed + b.counts.removed
        if ca ~= cb then
            return ca > cb
        end
        return a.path < b.path
    end)
    return { root = root, source = "snapshot", files = files }
end

return M
