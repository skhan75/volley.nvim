-- The picker you get when telescope and snacks are not around.
--
-- A list on the left, the lines it points at on the right. Move with j and k,
-- open with enter, leave with q.

local M = {}

local NS = vim.api.nvim_create_namespace("volley.float")

local function scratch()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    return buf
end

local function width_of(items)
    local w = 30
    for _, item in ipairs(items) do
        local own = vim.fn.strdisplaywidth(item.left or item.text)
        if item.right then
            own = own + vim.fn.strdisplaywidth(item.right) + 2
        end
        w = math.max(w, own)
    end
    return w
end

---One row. An item with a right half keeps it against the right edge, and a
---path too long for the window loses its front, not its name.
local function row_text(item, width)
    if not item.right then
        return item.text
    end
    local left, right = item.left or item.text, item.right
    local room = width - vim.fn.strdisplaywidth(right) - 1
    while vim.fn.strdisplaywidth(left) > room and #left > 1 do
        left = "…" .. left:sub(-(room - 1))
    end
    local pad = width - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right)
    return left .. string.rep(" ", math.max(pad, 1)) .. right
end

---Lines to show for an item: what the caller gave us, or the file itself.
---A caller with expensive lines can pass a function, called only when shown.
local function preview_lines(item)
    if type(item.preview) == "function" then
        local ok, lines = pcall(item.preview)
        return (ok and lines) or { "(could not read this one)" }, item.ft
    end
    if item.preview then
        return item.preview, item.ft
    end
    if item.file and vim.fn.filereadable(item.file) == 1 then
        local lines = vim.fn.readfile(item.file, "", 300)
        return lines, vim.filetype.match({ filename = item.file })
    end
    return { "(nothing to show)" }, nil
end

-- Hunk previews come in as "  18 + text". Colour them like a diff.
local function paint(buf, lines)
    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    for i, line in ipairs(lines) do
        local mark = line:match("^%s*%d*%s*([+-])")
        local group = (mark == "+" and "VolleyAdd") or (mark == "-" and "VolleyRemoved")
        if group then
            vim.api.nvim_buf_set_extmark(buf, NS, i - 1, 0, { line_hl_group = group })
        end
    end
end

---@param items table[] each { text = string, file = string|nil, preview = string[]|nil }
---@param opts { prompt: string, preview: boolean|nil }
---@param on_pick fun(item: table)
function M.pick(items, opts, on_pick)
    if #items == 0 then
        return
    end
    local want_preview = opts.preview ~= false
    local columns, lines_total = vim.o.columns, vim.o.lines

    local total_w = math.max(30, math.min(columns - 8, want_preview and 120 or 60))
    local list_w = math.min(width_of(items), want_preview and math.floor(total_w * 0.5) or total_w)
    local prev_w = want_preview and (total_w - list_w - 2) or 0
    total_w = list_w + (want_preview and prev_w + 2 or 0)
    local height = math.max(1, math.min(#items, math.floor(lines_total * 0.6)))
    local row = math.max(0, math.floor((lines_total - height) / 2) - 2)
    local col = math.max(0, math.floor((columns - total_w) / 2))

    local list_buf = scratch()
    vim.api.nvim_buf_set_lines(
        list_buf,
        0,
        -1,
        false,
        vim.tbl_map(function(i)
            return row_text(i, list_w)
        end, items)
    )
    vim.bo[list_buf].modifiable = false
    pcall(vim.api.nvim_buf_set_name, list_buf, "volley")

    local list_win = vim.api.nvim_open_win(list_buf, true, {
        relative = "editor",
        width = list_w,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = { { " " .. opts.prompt .. " ", "VolleyTitle" } },
        title_pos = "left",
        footer = { { " ↵ open   q close ", "VolleyComment" } },
        footer_pos = "right",
    })
    vim.wo[list_win].cursorline = true
    vim.wo[list_win].wrap = false
    vim.wo[list_win].winhighlight =
        "Normal:VolleyFloat,FloatBorder:VolleyBorder,CursorLine:VolleySelected"

    local prev_buf, prev_win
    if want_preview then
        prev_buf = scratch()
        prev_win = vim.api.nvim_open_win(prev_buf, false, {
            relative = "editor",
            width = prev_w,
            height = height,
            row = row,
            col = col + list_w + 2,
            style = "minimal",
            border = "rounded",
            focusable = false,
        })
        vim.wo[prev_win].winhighlight = "Normal:VolleyFloat,FloatBorder:VolleyBorder"
        vim.wo[prev_win].wrap = false
    end

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        pcall(vim.api.nvim_win_close, prev_win, true)
        pcall(vim.api.nvim_win_close, list_win, true)
    end

    local function show_preview()
        if not prev_win or not vim.api.nvim_win_is_valid(prev_win) then
            return
        end
        local item = items[vim.api.nvim_win_get_cursor(list_win)[1]]
        if not item then
            return
        end
        local text, ft = preview_lines(item)
        vim.api.nvim_buf_set_lines(prev_buf, 0, -1, false, text)
        if ft and ft ~= vim.bo[prev_buf].filetype then
            vim.bo[prev_buf].filetype = ft
        end
        paint(prev_buf, text)
        local title = item.file and vim.fn.fnamemodify(item.file, ":t") or ""
        pcall(vim.api.nvim_win_set_config, prev_win, {
            title = { { " " .. title .. " ", "VolleyComment" } },
            title_pos = "left",
        })
    end

    local function choose()
        local item = items[vim.api.nvim_win_get_cursor(list_win)[1]]
        close()
        if item then
            on_pick(item)
        end
    end

    local map = function(lhs, fn)
        vim.keymap.set("n", lhs, fn, { buffer = list_buf, nowait = true, silent = true })
    end
    map("<CR>", choose)
    map("q", close)
    map("<Esc>", close)
    map("<C-c>", close)

    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = list_buf,
        callback = show_preview,
    })
    vim.api.nvim_create_autocmd({ "WinClosed", "BufLeave" }, {
        buffer = list_buf,
        once = true,
        callback = close,
    })

    show_preview()
    return list_win
end

return M
