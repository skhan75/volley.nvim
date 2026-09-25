-- Drawing comments into the file they point at.

local annotations = require("volley.annotations")
local config = require("volley.config")

local M = {}

M.ns = vim.api.nvim_create_namespace("volley")

function M.clear(buf)
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    end
end

---Show this buffer's comments, after re-pointing them at their code.
---@param buf integer
function M.draw(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
        return
    end
    local abs = vim.api.nvim_buf_get_name(buf)
    if abs == "" then
        return
    end
    annotations.reanchor(abs, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    M.clear(buf)

    local last = vim.api.nvim_buf_line_count(buf)
    for n, it in ipairs(annotations.list()) do
        if it.abs == abs and it.status ~= "sent" then
            local stale = it.status == "stale"
            local row = math.min(math.max(it.lnum, 1), last) - 1
            local label = ("▌%d %s%s"):format(
                n,
                it.comment,
                stale and "   (code moved or gone)" or ""
            )
            pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, row, 0, {
                sign_text = config.options.signs and "▌" or nil,
                sign_hl_group = config.options.signs and "VolleySign" or nil,
                virt_lines = { { { label, stale and "VolleyStale" or "VolleyComment" } } },
                virt_lines_above = false,
            })
            if not stale then
                for l = it.lnum, math.min(it.end_lnum, last) do
                    pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, l - 1, 0, {
                        line_hl_group = "VolleyChange",
                    })
                end
            end
        end
    end
end

---Redraw every loaded buffer that has comments.
function M.draw_all()
    local files = {}
    for _, it in ipairs(annotations.list()) do
        files[it.abs] = true
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and files[vim.api.nvim_buf_get_name(buf)] then
            M.draw(buf)
        end
    end
end

return M
