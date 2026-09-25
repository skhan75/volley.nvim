-- :Volley command. Everything else loads on first use.
if vim.g.loaded_volley then
    return
end
vim.g.loaded_volley = true

if vim.fn.has("nvim-0.11") == 0 then
    vim.api.nvim_echo({ { "volley.nvim needs Neovim 0.11 or newer", "ErrorMsg" } }, true, {})
    return
end

local function v()
    return require("volley")
end

local subcommands = {
    open = function()
        v().open()
    end,
    annotate = function()
        v().annotate()
    end,
    queue = function()
        v().queue()
    end,
    send = function()
        v().send()
    end,
    clear = function()
        v().clear()
    end,
    snapshot = function()
        v().snapshot()
    end,
    next = function()
        v().next_hunk()
    end,
    prev = function()
        v().prev_hunk()
    end,
    status = function()
        local s = v().status()
        vim.notify(("volley: %d waiting, %d sent, %d stale"):format(s.open, s.sent, s.stale))
    end,
}

local names = vim.tbl_keys(subcommands)
table.sort(names)

vim.api.nvim_create_user_command("Volley", function(a)
    local name = a.fargs[1] or "open"
    local fn = subcommands[name]
    if not fn then
        return vim.notify(("volley: unknown subcommand %q"):format(name), vim.log.levels.ERROR)
    end
    local ok, err = pcall(fn)
    if not ok then
        vim.notify(tostring(err), vim.log.levels.ERROR)
    end
end, {
    nargs = "?",
    range = true,
    desc = "volley: review the agent's changes",
    complete = function(lead)
        return vim.tbl_filter(function(s)
            return vim.startswith(s, lead)
        end, names)
    end,
})
