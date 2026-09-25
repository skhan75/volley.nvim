-- The queue of comments you wrote on the agent's changes.
--
-- A comment remembers the code it points at, not just a line number. The
-- agent keeps editing, so lines move; the remembered text is what lets a
-- comment follow its code, and what tells us when that code is gone.

local M = {}

local items, next_id = {}, 1

---@param a { path: string, abs: string, lnum: integer, end_lnum: integer, comment: string, code: string[] }
---@return integer id
function M.add(a)
    local id = next_id
    next_id = next_id + 1
    items[id] = {
        id = id,
        path = a.path,
        abs = a.abs,
        lnum = a.lnum,
        end_lnum = a.end_lnum or a.lnum,
        comment = a.comment,
        code = a.code or {},
        status = "open",
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
    local c = { open = 0, sent = 0, stale = 0 }
    for _, it in pairs(items) do
        c[it.status] = (c[it.status] or 0) + 1
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

-- Find the remembered code in `lines`: the whole block first, then just its
-- first line, which survives the agent rewriting something inside the block.
local function find(code, lines)
    if #code == 0 then
        return nil
    end
    for start = 1, math.max(#lines - #code + 1, 0) do
        local all = true
        for i, want in ipairs(code) do
            if lines[start + i - 1] ~= want then
                all = false
                break
            end
        end
        if all then
            return start, start + #code - 1
        end
    end
    for i, line in ipairs(lines) do
        if line == code[1] then
            return i, i + #code - 1
        end
    end
    return nil
end

---Re-point every comment on `abs` at where its code is now.
---@param abs string
---@param lines string[] the file's current lines
function M.reanchor(abs, lines)
    local drop = require("volley.config").options.stale == "drop"
    for id, it in pairs(items) do
        if it.abs == abs and it.status ~= "sent" then
            local first, last = find(it.code, lines)
            if first then
                it.lnum, it.end_lnum, it.status = first, math.min(last, #lines), "open"
            elseif drop then
                items[id] = nil
            else
                it.status = "stale"
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
        local stale = it.status == "stale" and "  (the code this pointed at has moved or gone)"
            or ""
        out[#out + 1] = ("%d. %s%s"):format(n, where(it), stale)
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
