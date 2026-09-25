-- volley.nvim: review what an agent changed, comment on it, send it back.

local annotations = require("volley.annotations")
local agent = require("volley.agent")
local config = require("volley.config")
local git = require("volley.source.git")
local highlights = require("volley.highlights")
local picker = require("volley.ui.picker")
local render = require("volley.ui.render")
local snapshot = require("volley.source.snapshot")

local M = {}

local group
local cache = { changeset = nil }

local function opts()
    return config.options
end

local function plural(n, word)
    return ("%d %s%s"):format(n, word, n == 1 and "" or "s")
end

local function notify(msg, level)
    vim.notify("volley: " .. msg, level or vim.log.levels.INFO, { title = "volley" })
end

local function project()
    local cwd = vim.uv.cwd()
    local buf = vim.api.nvim_buf_get_name(0)
    return (buf ~= "" and vim.fs.dirname(buf)) or cwd, cwd
end

---What changed, from git or from a snapshot.
---@return table|nil changeset, string|nil why_not
function M.changeset()
    local from, cwd = project()
    local want = opts().source
    if want ~= "snapshot" then
        local root = git.root(from) or git.root(cwd)
        if root then
            local cs = git.changeset(root, { max_filesize = opts().snapshot.max_filesize })
            cache.changeset = cs
            return cs
        end
        if want == "git" then
            return nil, "this is not a git repo, and source is set to git"
        end
    end
    if not snapshot.exists(cwd) then
        local where = vim.fn.fnamemodify(cwd, ":~")
        if want == "snapshot" then
            return nil,
                ("no snapshot of %s yet, run :Volley snapshot before the agent starts"):format(
                    where
                )
        end
        return nil,
            ("%s is not a git repo and has no snapshot yet, run :Volley snapshot before the agent starts"):format(
                where
            )
    end
    local cs = snapshot.changeset(cwd, opts().snapshot)
    cache.changeset = cs
    return cs
end

---Take the baseline a non-git project needs.
function M.snapshot()
    local _, cwd = project()
    local info = snapshot.take(cwd, opts().snapshot)
    notify(
        ("snapshot taken, %s%s"):format(
            plural(info.files, "file"),
            info.truncated and " (hit the file limit)" or ""
        )
    )
    return info
end

local PREVIEW_MAX = 200

---The agent's edits, old lines then new ones. Read only when you look at it.
local function hunk_preview(f)
    return function()
        local now = vim.fn.filereadable(f.abs) == 1 and vim.fn.readfile(f.abs) or {}
        local out = {}
        for i, h in ipairs(f.hunks) do
            if i > 1 then
                out[#out + 1] = ""
            end
            for _, line in ipairs(h.removed) do
                out[#out + 1] = ("%5s - %s"):format("", line)
            end
            for n = h.lnum, h.lnum + h.count - 1 do
                out[#out + 1] = ("%5d + %s"):format(n, now[n] or "")
            end
            if #out >= PREVIEW_MAX then
                out[#out + 1] = ("   … %d more changes"):format(#f.hunks - i)
                break
            end
        end
        return out
    end
end

local function file_item(f)
    local c = f.counts
    local counts = ("+%d ~%d -%d"):format(c.added, c.changed, c.removed)
    if f.status ~= "modified" then
        counts = counts .. "  " .. f.status
    end
    return {
        text = ("%-44s %s"):format(f.path, counts),
        left = f.path,
        right = counts,
        file = f.abs,
        preview = hunk_preview(f),
        value = f,
    }
end

local function first_hunk_line(f)
    for _, h in ipairs(f.hunks) do
        return math.max(h.lnum, 1)
    end
    return 1
end

---Open the review: the files the agent touched.
function M.open()
    local cs, why = M.changeset()
    if not cs then
        return notify(why, vim.log.levels.WARN)
    end
    if #cs.files == 0 then
        return notify(
            "nothing has changed" .. (cs.source == "snapshot" and " since the snapshot" or "")
        )
    end
    local items = vim.tbl_map(file_item, cs.files)
    local title = ("volley  %s changed"):format(plural(#cs.files, "file"))
    picker.pick(items, { prompt = title }, function(item)
        vim.cmd.edit(vim.fn.fnameescape(item.file))
        pcall(vim.api.nvim_win_set_cursor, 0, { first_hunk_line(item.value), 0 })
        render.draw(vim.api.nvim_get_current_buf())
    end)
end

local function selection()
    local mode = vim.fn.mode()
    local buf = vim.api.nvim_get_current_buf()
    local l1, l2
    if mode:find("[vV\22]") then
        l1, l2 = vim.fn.line("v"), vim.fn.line(".")
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    else
        -- After leaving visual mode the marks still hold the last selection,
        -- which is what `:Volley annotate` sees. It counts only while the
        -- cursor is still inside it, and only once.
        local cur = vim.api.nvim_win_get_cursor(0)[1]
        local m1, m2 = vim.fn.line("'<"), vim.fn.line("'>")
        local fresh = vim.b[buf].volley_visual and m1 > 0 and m2 >= m1 and cur >= m1 and cur <= m2
        vim.b[buf].volley_visual = false
        if fresh then
            l1, l2 = m1, m2
        else
            l1, l2 = cur, cur
        end
    end
    if l1 > l2 then
        l1, l2 = l2, l1
    end
    return l1, l2
end

---Write a comment on the selected lines, or the current line.
function M.annotate()
    local buf = vim.api.nvim_get_current_buf()
    local abs = vim.api.nvim_buf_get_name(buf)
    if abs == "" or vim.bo[buf].buftype ~= "" then
        return notify("nothing to comment on here", vim.log.levels.WARN)
    end
    local l1, l2 = selection()
    local code = vim.api.nvim_buf_get_lines(buf, l1 - 1, l2, false)
    local cs = cache.changeset
    local root = cs and cs.root or vim.uv.cwd()
    local rel = abs:sub(1, #root + 1) == root .. "/" and abs:sub(#root + 2) or abs

    vim.ui.input(
        { prompt = ("comment on %s %s: "):format(rel, l1 == l2 and l1 or (l1 .. "-" .. l2)) },
        function(text)
            if not text or text:gsub("%s", "") == "" then
                return
            end
            annotations.add({
                path = rel,
                abs = abs,
                lnum = l1,
                end_lnum = l2,
                comment = text,
                code = code,
            })
            render.draw(buf)
            local c = annotations.counts()
            notify(("comment added, %s waiting"):format(plural(c.open, "comment")))
        end
    )
end

---Show everything you have written so far.
function M.queue()
    local list = annotations.pending()
    if #list == 0 then
        return notify("no comments yet")
    end
    local items = vim.tbl_map(function(it)
        local where = it.lnum == it.end_lnum and tostring(it.lnum)
            or (it.lnum .. "-" .. it.end_lnum)
        local at = ("%s:%s%s"):format(it.path, where, it.status == "stale" and " (stale)" or "")
        return {
            text = ("%-30s %s"):format(at, it.comment),
            left = it.comment,
            right = at,
            file = it.abs,
            value = it,
        }
    end, list)
    picker.pick(
        items,
        { prompt = "volley queue  " .. plural(#list, "comment"), preview = false },
        function(item)
            vim.cmd.edit(vim.fn.fnameescape(item.file))
            pcall(vim.api.nvim_win_set_cursor, 0, { item.value.lnum, 0 })
            render.draw(vim.api.nvim_get_current_buf())
        end
    )
end

local function show_reply(res)
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = vim.split(res.reply or "", "\n", { plain = true })
    if res.cost then
        table.insert(lines, "")
        table.insert(lines, ("%s, $%.3f"):format(res.session or "session", res.cost))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_name(buf, "volley://reply")
    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_win_set_height(0, math.min(#lines + 2, 20))
    vim.wo.wrap = true
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
end

---Send the queue to the agent.
function M.send()
    local pending = annotations.pending()
    if #pending == 0 then
        return notify("nothing to send")
    end
    if opts().agent.require_idle and not agent.is_idle() then
        return notify("the agent is busy, try again when it stops", vim.log.levels.WARN)
    end
    local payload = annotations.payload()
    local ids = vim.tbl_map(function(it)
        return it.id
    end, pending)
    notify("sending " .. plural(#pending, "comment"))
    agent.send(payload, function(res)
        if not res.ok then
            return notify(
                "the agent could not answer: " .. (res.error or "unknown"),
                vim.log.levels.ERROR
            )
        end
        annotations.mark_sent(ids)
        render.draw_all()
        show_reply(res)
    end)
end

---Re-point comments at their code and redraw.
function M.refresh()
    render.draw(vim.api.nvim_get_current_buf())
end

function M.clear()
    annotations.clear()
    render.draw_all()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        render.clear(buf)
    end
    notify("comments cleared")
end

local function hunks_for_buffer()
    local cs = cache.changeset
    if not cs then
        cs = M.changeset()
    end
    if not cs then
        return {}
    end
    local abs = vim.api.nvim_buf_get_name(0)
    for _, f in ipairs(cs.files) do
        if f.abs == abs then
            return f.hunks
        end
    end
    return {}
end

local function jump(dir)
    local hunks = hunks_for_buffer()
    if #hunks == 0 then
        return notify("no changes in this file")
    end
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local lines = vim.tbl_map(function(h)
        return math.max(h.lnum, 1)
    end, hunks)
    table.sort(lines)
    local target
    if dir > 0 then
        for _, l in ipairs(lines) do
            if l > cur then
                target = l
                break
            end
        end
        target = target or lines[1]
    else
        for i = #lines, 1, -1 do
            if lines[i] < cur then
                target = lines[i]
                break
            end
        end
        target = target or lines[#lines]
    end
    pcall(vim.api.nvim_win_set_cursor, 0, { math.min(target, vim.api.nvim_buf_line_count(0)), 0 })
end

function M.next_hunk()
    jump(1)
end

function M.prev_hunk()
    jump(-1)
end

function M.status()
    return annotations.counts()
end

---@param user_opts table|nil see :help volley-config
function M.setup(user_opts)
    config.setup(user_opts)
    highlights.setup()

    group = vim.api.nvim_create_augroup("volley", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights.setup })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = group,
        callback = function(args)
            render.draw(args.buf)
        end,
    })
    -- Remember that a visual selection just ended, so annotate() uses it.
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = group,
        pattern = "[vV\22]*:*",
        callback = function(args)
            vim.b[args.buf].volley_visual = true
        end,
    })
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = group,
        pattern = "*:[vV\22]*",
        callback = function(args)
            vim.b[args.buf].volley_visual = false
        end,
    })

    local map = function(modes, lhs, fn, desc)
        if lhs then
            vim.keymap.set(modes, lhs, fn, { desc = "volley: " .. desc, silent = true })
        end
    end
    map("n", opts().key, M.open, "review the agent's changes")
    map({ "n", "x" }, opts().keys.annotate, M.annotate, "comment on these lines")
    map("n", opts().keys.queue, M.queue, "show the comment queue")
    map("n", opts().keys.send, M.send, "send the comments")
    map("n", opts().keys.next, M.next_hunk, "next change in this file")
    map("n", opts().keys.prev, M.prev_hunk, "previous change in this file")

    M._did_setup = true
end

return M
