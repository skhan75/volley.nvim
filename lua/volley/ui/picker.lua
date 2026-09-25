-- Picking things, with whatever picker you already have.
--
-- Callers pass plain items { text = "...", value = ... } and a callback.
-- Telescope and snacks are used when present; otherwise volley draws its own
-- list, and vim.ui.select is there for anyone who wants it.

local config = require("volley.config")

local M = {}

local function have(mod)
    local ok = pcall(require, mod)
    return ok
end

---Which picker will actually be used.
---@return "telescope"|"snacks"|"builtin"|"select"
function M.kind()
    local want = config.options.picker
    if want ~= "auto" then
        return want
    end
    if have("telescope") then
        return "telescope"
    elseif have("snacks") then
        return "snacks"
    end
    return "builtin"
end

local function builtin(items, opts, on_pick)
    require("volley.ui.float").pick(items, opts, on_pick)
end

local function ui_select(items, opts, on_pick)
    vim.ui.select(items, {
        prompt = opts.prompt,
        format_item = function(item)
            return item.text
        end,
    }, function(item)
        if item then
            on_pick(item)
        end
    end)
end

local function telescope(items, opts, on_pick)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local state = require("telescope.actions.state")

    pickers
        .new({}, {
            prompt_title = opts.prompt,
            finder = finders.new_table({
                results = items,
                entry_maker = function(item)
                    return {
                        value = item,
                        display = item.text,
                        ordinal = item.text,
                        path = item.file,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            previewer = opts.preview ~= false and conf.file_previewer({}) or nil,
            attach_mappings = function(bufnr)
                actions.select_default:replace(function()
                    local entry = state.get_selected_entry()
                    actions.close(bufnr)
                    if entry then
                        on_pick(entry.value)
                    end
                end)
                return true
            end,
        })
        :find()
end

local function snacks(items, opts, on_pick)
    require("snacks").picker.pick({
        title = opts.prompt,
        items = vim.tbl_map(function(item)
            return vim.tbl_extend("force", { text = item.text, file = item.file }, { item = item })
        end, items),
        format = "text",
        confirm = function(picker, choice)
            picker:close()
            if choice then
                on_pick(choice.item)
            end
        end,
    })
end

---@param items table[] each { text = string, file = string|nil, ... }
---@param opts { prompt: string, preview: boolean|nil }
---@param on_pick fun(item: table)
function M.pick(items, opts, on_pick)
    if #items == 0 then
        return
    end
    local kind = M.kind()
    local ok, err = pcall(function()
        if kind == "telescope" then
            telescope(items, opts, on_pick)
        elseif kind == "snacks" then
            snacks(items, opts, on_pick)
        elseif kind == "select" then
            ui_select(items, opts, on_pick)
        else
            builtin(items, opts, on_pick)
        end
    end)
    if not ok then
        -- A picker that is present but unhappy should not lose your review.
        vim.notify("volley: " .. tostring(err) .. " (falling back)", vim.log.levels.WARN)
        ui_select(items, opts, on_pick)
    end
end

return M
