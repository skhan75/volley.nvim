-- The queue of comments you wrote on the agent's changes.
--
-- A comment remembers the file it was written on, not just a line number.
-- When the agent edits again, the two versions are diffed and the comment's
-- lines are carried through the hunks, so it lands where its code went even
-- when another block looks identical. Without a baseline, or when the diff
-- says the code is gone, the remembered text is searched for instead, which
-- is what finds a block the agent moved somewhere else.

local anchor = require("volley.anchor")

local M = {}

local items, next_id = {}, 1

---@param a { path: string, abs: string, lnum: integer, end_lnum: integer, comment: string, code: string[], baseline: string[]|nil }
---@return integer id
function M.add(a)
    local id = next_id
    next_id = next_id + 1
    local end_lnum = a.end_lnum or a.lnum
    items[id] = {
        id = id,
        path = a.path,
        abs = a.abs,
        lnum = a.lnum,
        end_lnum = end_lnum,
        comment = a.comment,
        code = a.code or {},
        status = "open",
        changed = false,
        -- the file as it was, and where the comment sat in it
        anchor = a.baseline and { lines = a.baseline, lnum = a.lnum, end_lnum = end_lnum } or nil,
    }
    return id
end

function M.get(id)
    return items[id]
end

---All comments, by file then line.
function M.list()
    local out = vim.tbl_values(items)
    table.sort(out, function(x, y)
        if x.path ~= y.path then
            return x.path < y.path
        end
        return x.lnum < y.lnum
    end)
    return out
end

function M.remove(id)
    items[id] = nil
end

function M.clear()
    items, next_id = {}, 1
end

function M.counts()
    local c = { open = 0, sent = 0, stale = 0, changed = 0 }
    for _, it in pairs(items) do
        c[it.status] = (c[it.status] or 0) + 1
        if it.status == "open" and it.changed then
            c.changed = c.changed + 1
        end
    end
    return c
end

function M.mark_sent(ids)
    for _, id in ipairs(ids) do
        if items[id] then
            items[id].status = "sent"
        end
    end
end

-- Two lines are the same code if they differ only in how much whitespace
-- sits between the words, which is the change a formatter makes.
local function norm(line)
    return (line:gsub("%s+", " "):gsub(" $", ""))
end

local function same_line(a, b)
    return a == b or norm(a) == norm(b)
end

-- Find the remembered code in `lines`: the whole block first, then just its
-- first line. Says which of the two matched, since a first line match means
-- the rest of the block is not what was commented on.
local function find(code, lines)
    if #code == 0 then
        return nil
    end
    for start = 1, math.max(#lines - #code + 1, 0) do
        local all = true
        for i, want in ipairs(code) do
            if not same_line(lines[start + i - 1] or "", want) then
                all = false
                break
            end
        end
        if all then
            return start, start + #code - 1, "block"
        end
    end
    for i, line in ipairs(lines) do
        if same_line(line, code[1]) then
            return i, i + #code - 1, "line"
        end
    end
    return nil
end

local function same_text(lines, first, last, code)
    if last - first + 1 ~= #code then
        return false
    end
    for i, want in ipairs(code) do
        if not same_line(lines[first + i - 1] or "", want) then
            return false
        end
    end
    return true
end

local function settle(it, first, last, changed, n)
    it.lnum, it.end_lnum = math.max(1, math.min(first, n)), math.max(1, math.min(last, n))
    it.status, it.changed = "open", changed
    return true
end

-- Carry one comment through to `lines`. Diff first, because it cannot pick
-- the wrong lookalike; text search second, because it is what finds a block
-- the agent moved; stale last.
local function place(it, lines)
    if it.anchor then
        local first, last, how =
            anchor.map(it.anchor.lines, lines, it.anchor.lnum, it.anchor.end_lnum)
        if how == "changed" then
            return settle(it, first, last, true, #lines)
        end
        -- "same" is only believed when the text really is the same; a baseline
        -- that has drifted from the file falls through to the search.
        if how == "same" and (it.changed or same_text(lines, first, last, it.code)) then
            return settle(it, first, last, it.changed, #lines)
        end
    end
    local first, last, by = find(it.code, lines)
    if not first then
        return false
    end
    settle(it, first, last, by == "line", #lines)
    -- The search found it where the diff could not, so the diff starts
    -- again from here.
    it.anchor = { lines = lines, lnum = it.lnum, end_lnum = it.end_lnum }
    return true
end

---Re-point every comment on `abs` at where its code is now.
---@param abs string
---@param lines string[] the file's current lines
function M.reanchor(abs, lines)
    local drop = require("volley.config").options.stale == "drop"
    for id, it in pairs(items) do
        if it.abs == abs and it.status ~= "sent" then
            if not place(it, lines) then
                if drop then
                    items[id] = nil
                else
                    it.status = "stale"
                end
            end
        end
    end
end

local function where(it)
    if it.lnum == it.end_lnum then
        return ("%s line %d"):format(it.path, it.lnum)
    end
    return ("%s lines %d-%d"):format(it.path, it.lnum, it.end_lnum)
end

---The message for the agent, or nil when nothing is waiting.
---@return string|nil
function M.payload()
    local open = vim.tbl_filter(function(it)
        return it.status ~= "sent"
    end, M.list())
    if #open == 0 then
        return nil
    end

    local out = {
        "I reviewed the changes you just made. Answer each comment below.",
        "Where you agree with one, make the change. Keep each answer short and",
        "start it with the comment's number.",
        "",
    }
    for n, it in ipairs(open) do
        local note = ""
        if it.status == "stale" then
            note = "  (the code this pointed at has moved or gone)"
        elseif it.changed then
            note = "  (the code under this comment has changed since it was written)"
        end
        out[#out + 1] = ("%d. %s%s"):format(n, where(it), note)
        for _, line in ipairs(it.code) do
            out[#out + 1] = "       " .. line
        end
        out[#out + 1] = "   > " .. it.comment
        out[#out + 1] = ""
    end
    return table.concat(out, "\n")
end

---The comments that a payload would send.
function M.pending()
    return vim.tbl_filter(function(it)
        return it.status ~= "sent"
    end, M.list())
end

return M
