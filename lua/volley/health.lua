-- :checkhealth volley

local M = {}

function M.check()
    local health = vim.health
    local volley = require("volley")
    local config = require("volley.config")
    local git = require("volley.source.git")
    local snapshot = require("volley.source.snapshot")
    local picker = require("volley.ui.picker")

    health.start("volley")

    if vim.fn.has("nvim-0.11") == 1 then
        health.ok("Neovim " .. tostring(vim.version()))
    else
        health.error("Neovim 0.11 or newer is required")
    end

    if volley._did_setup then
        health.ok("setup() has been called")
    else
        health.warn("setup() has not been called: no keymaps and no command", {
            "Call require('volley').setup() (lazy.nvim does this for `opts`)",
        })
    end

    health.ok("picker: " .. picker.kind())

    local cwd = vim.uv.cwd()
    local root = git.root(cwd)
    if root then
        health.ok("changes come from git in " .. root)
    elseif snapshot.exists(cwd) then
        health.ok("changes come from the snapshot of " .. cwd)
    else
        health.warn("no git repo and no snapshot here", {
            "Run :Volley snapshot before the agent starts, so there is a before to compare with",
        })
    end

    local cmd = config.options.agent.cmd[1]
    if vim.fn.executable(cmd) == 1 or vim.fn.filereadable(cmd) == 1 then
        health.ok("agent command: " .. cmd)
    else
        health.error(("agent command not found: %s"):format(cmd), {
            "Set agent.cmd to how you run your agent",
        })
    end
end

return M
