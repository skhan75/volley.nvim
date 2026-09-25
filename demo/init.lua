-- Neovim config for recording the README GIFs (`make demo`). You don't need
-- any of this to use volley.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(root .. "/demo") -- colors/blazer.lua, lua/theme.lua

vim.g.mapleader = " "
vim.o.termguicolors = true
vim.o.number = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.swapfile = false
vim.o.shadafile = "NONE"
vim.o.fillchars = "eob: "
vim.o.autoread = true
vim.cmd.colorscheme("blazer")

vim.api.nvim_create_autocmd("FileType", {
    pattern = "python",
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

require("volley").setup({
    -- A stand-in for the claude CLI, so a recording never calls a real one.
    agent = { cmd = { vim.env.HOME .. "/bin/claude-demo" }, require_idle = false },
})

-- Tell demo/agent.sh the editor is up (see demo/setup.sh).
vim.schedule(function()
    pcall(vim.fn.writefile, {}, vim.env.HOME .. "/app/.ready")
end)

-- Comment count in the statusline, from volley.status().
function _G.volley_status()
    local s = require("volley").status()
    if s.open == 0 then
        return ""
    end
    return ("◍ %d  "):format(s.open)
end
vim.o.statusline =
    "%#GlasstermTitle# %f %*%=%#VolleyMarker#%{v:lua.volley_status()}%*%#GlasstermHint# %l:%c %*"
