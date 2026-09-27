-- Where did these lines go?
--
-- A comment is written against a file as it was. The agent then rewrites
-- the file, and the buffer reloads whole, so nothing tracks the edit as it
-- happens. But we still have both versions, so we can diff them and carry the
-- comment's line range through the hunks. That is arithmetic, not a search,
-- and it cannot be fooled by another block of code that looks the same.

local M = {}

-- A single hunk that replaces this much of the file is a rewrite, not an
-- edit, and carrying a range through it would be a guess. Half the file, or
-- all of a tiny one.
local REWRITE_SHARE = 0.5
local REWRITE_MIN = 3

local function rewrite_threshold(n)
    return math.min(n, math.max(REWRITE_MIN, math.floor(n * REWRITE_SHARE)))
end

local function text(lines)
    return #lines == 0 and "" or (table.concat(lines, "\n") .. "\n")
end

-- One old line number to its new one. vim.diff "indices" hunks are
-- { start_a, count_a, start_b, count_b }; with count_a 0 the insertion sits
-- after old line start_a, with count_b 0 the deletion sits after new line
-- start_b.
local function map_line(hunks, n, rewrite_at)
    local delta = 0
    for _, h in ipairs(hunks) do
        local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
        if ca == 0 then
            if n <= sa then
                break
            end
            delta = delta + cb
        else
            if n < sa then
                break
            end
            local ea = sa + ca - 1
            if n <= ea then
                -- Deleted outright is gone, however much went with it. Only a
                -- replacement big enough to be a rewrite is a guess.
                if cb == 0 then
                    return nil, "gone"
                end
                if ca >= rewrite_at then
                    return nil, "unsure"
                end
                -- Inside a rewritten block the old line has no true home, so
                -- it keeps its distance from whichever edge of the block is
                -- nearer, since the intact code past that edge is what it
                -- was next to.
                local from_start, from_end = n - sa, ea - n
                if from_start <= from_end then
                    return sb + math.min(from_start, cb - 1), "changed"
                end
                return (sb + cb - 1) - math.min(from_end, cb - 1), "changed"
            end
            delta = delta + (cb - ca)
        end
    end
    return n + delta, "same"
end

---Carry lines l1..l2 of `base` through to `cur`.
---@param base string[] the file when the comment was written
---@param cur string[] the file now
---@param l1 integer
---@param l2 integer
---@return integer|nil first, integer|nil last, "same"|"changed"|"gone"|"unsure" how
function M.map(base, cur, l1, l2)
    -- A range that was never inside the file has nowhere to go.
    l1, l2 = math.max(l1, 1), math.min(l2, #base)
    if l1 > l2 then
        return nil, nil, "gone"
    end
    -- Whitespace-only changes are what formatters make, and a comment should
    -- ride through a formatter run untouched.
    local hunks = vim.diff(text(base), text(cur), {
        result_type = "indices",
        algorithm = "histogram",
        ignore_whitespace_change = true,
    }) or {}
    local rewrite_at = rewrite_threshold(#base)

    local first, last, changed = nil, nil, false
    for n = l1, l2 do
        local m, how = map_line(hunks, n, rewrite_at)
        if how == "unsure" then
            return nil, nil, "unsure"
        end
        if m then
            first = first and math.min(first, m) or m
            last = last and math.max(last, m) or m
        end
        if how ~= "same" then
            changed = true
        end
    end
    if not first then
        return nil, nil, "gone"
    end
    -- A line inserted inside the range makes it longer than it was.
    if last - first ~= l2 - l1 then
        changed = true
    end
    return first, last, changed and "changed" or "same"
end

return M
