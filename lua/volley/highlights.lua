-- Highlight groups. Each links to a standard group, so any colorscheme works.

local M = {}

M.links = {
    VolleyAdd = "DiffAdd",
    VolleyChange = "DiffChange",
    VolleyRemoved = "DiffDelete",
    VolleyComment = "Comment",
    VolleyMarker = "WarningMsg",
    VolleyStale = "ErrorMsg",
    VolleySign = "WarningMsg",
    VolleyFloat = "NormalFloat",
    VolleyBorder = "FloatBorder",
    VolleyTitle = "FloatTitle",
    VolleySelected = "Visual",
}

function M.setup()
    for group, target in pairs(M.links) do
        vim.api.nvim_set_hl(0, group, { link = target, default = true })
    end
end

return M
