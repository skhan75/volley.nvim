-- Test init: this repo and mini.nvim (for mini.test) on the runtimepath.
-- Used both by the test runner and by every child Neovim it starts.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.getcwd() .. "/deps/mini.nvim")

-- Keep children quiet and deterministic.
vim.o.swapfile = false
vim.o.shadafile = "NONE"

require("mini.test").setup()
