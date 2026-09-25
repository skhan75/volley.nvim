-- Turning "text before" and "text now" into hunks. Pure: no buffers, no
-- windows, so the mapping is testable on plain tables.
--
-- Same shape as tailf.nvim's diff module, by the same author, so a hunk means
-- the same thing in both plugins.
--
-- A hunk is { kind, lnum, count, removed }:
--   kind    "add" | "change" | "delete"
--   lnum    1-based line in the CURRENT text (0 for a deletion above line 1)
--   count   how many current lines the hunk covers (0 for a deletion)
--   removed the lines that are gone, for showing under/over the anchor

local M = {}

local function text(lines)
    return #lines == 0 and "" or (table.concat(lines, "\n") .. "\n")
end

---@param base string[] lines as they were
---@param cur string[] lines as they are now
---@return table[] hunks
function M.hunks(base, cur)
    local out = {}
    local indices = vim.diff(text(base), text(cur), {
        result_type = "indices",
        algorithm = "histogram",
    })
    for _, h in ipairs(indices or {}) do
        local start_a, count_a, start_b, count_b = h[1], h[2], h[3], h[4]
        local removed = {}
        for i = start_a, start_a + count_a - 1 do
            removed[#removed + 1] = base[i]
        end
        if count_a == 0 then
            out[#out + 1] = { kind = "add", lnum = start_b, count = count_b, removed = {} }
        elseif count_b == 0 then
            -- vim.diff gives the line the deletion follows (0 = above line 1).
            out[#out + 1] = { kind = "delete", lnum = start_b, count = 0, removed = removed }
        else
            -- A hunk that rewrites lines AND adds more reads better split:
            -- the rewritten lines are a change, the surplus lines are new.
            local changed = math.min(count_a, count_b)
            out[#out + 1] = { kind = "change", lnum = start_b, count = changed, removed = removed }
            if count_b > changed then
                out[#out + 1] = {
                    kind = "add",
                    lnum = start_b + changed,
                    count = count_b - changed,
                    removed = {},
                }
            end
        end
    end
    return out
end

---@param hunks table[]
---@return { added: integer, changed: integer, removed: integer }
function M.counts(hunks)
    local c = { added = 0, changed = 0, removed = 0 }
    for _, h in ipairs(hunks) do
        if h.kind == "add" then
            c.added = c.added + h.count
        elseif h.kind == "change" then
            c.changed = c.changed + h.count
            c.removed = c.removed + math.max(#h.removed - h.count, 0)
        else
            c.removed = c.removed + #h.removed
        end
    end
    return c
end

return M
