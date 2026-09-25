-- Shared highlight definitions for the local colorschemes (colors/hack.lua,
-- colors/blazer.lua). Each scheme only supplies a palette; the group -> role
-- mapping lives here once so the schemes can't drift apart.
--
-- Palette keys are named after the original hack roles (teal_*, amber, coral,
-- ...). In another scheme they mean the same *role* -- teal_hi is "the hero
-- accent", amber is "strings" -- not literally that hue.
--
-- Transparency clears every large surface (editor, floats, statusline, tabs,
-- sidebars) so the terminal's own opacity/blur shows through evenly. Small
-- overlays (Pmenu, selection, cursorline, code blocks) keep a tint so they
-- stay legible. Floats all have borders (winborder = "rounded"), so they keep
-- their edges without a fill.

local M = {}

function M.apply(name, c, opts)
    opts = opts or {}
    vim.cmd("hi clear")
    if vim.fn.exists("syntax_on") then
        vim.cmd("syntax reset")
    end
    vim.o.background = "dark"
    vim.g.colors_name = name

    local transparent = opts.transparent == true
    local main_bg = transparent and "NONE" or c.bg
    local float_bg = transparent and "NONE" or c.bg_dark
    local bar_bg = transparent and "NONE" or c.bg_alt

    -- lualine builds its theme from this table.
    c.bar_bg = bar_bg
    vim.g.hack_palette = c
    _G.HackPalette = c

    local function hi(group, opts)
        vim.api.nvim_set_hl(0, group, opts)
    end

    -- ── Editor & UI ──────────────────────────────────────────────────────
    hi("Normal", { fg = c.fg, bg = main_bg })
    hi("NormalFloat", { fg = c.fg, bg = float_bg })
    hi("NormalNC", { fg = c.fg, bg = main_bg })
    hi("SignColumn", { bg = main_bg })
    hi("ColorColumn", { bg = c.bg_alt })
    hi("CursorLine", { bg = c.bg_highlight })
    hi("CursorColumn", { bg = c.bg_highlight })
    hi("LineNr", { fg = c.fg_subtle, bg = main_bg })
    hi("CursorLineNr", { fg = c.teal_hi, bold = true, bg = main_bg })
    hi("Folded", { fg = c.fg_muted, bg = c.bg_alt })
    hi("FoldColumn", { fg = c.fg_subtle, bg = main_bg })
    hi("VertSplit", { fg = c.bg_grid, bg = main_bg })
    hi("WinSeparator", { fg = c.bg_grid, bg = main_bg })
    hi("EndOfBuffer", { fg = main_bg, bg = main_bg }) -- eob fillchar is a space
    hi("Cursor", { fg = c.bg, bg = c.teal_hi })
    hi("lCursor", { fg = c.bg, bg = c.teal_hi })
    hi("TermCursor", { fg = c.bg, bg = c.teal_hi })

    -- ── Selection & Search ───────────────────────────────────────────────
    -- Matches ghostty selection: bright cyan bg, dark fg
    hi("Visual", { bg = c.bg_selection })
    hi("VisualNOS", { fg = c.bg, bg = c.fg_bright })
    hi("Search", { fg = c.bg, bg = c.amber, bold = true })
    hi("IncSearch", { fg = c.bg, bg = c.teal_hi, bold = true })
    hi("CurSearch", { fg = c.bg, bg = c.coral, bold = true })
    hi("Substitute", { fg = c.bg, bg = c.coral })

    -- ── Popup / Float ────────────────────────────────────────────────────
    hi("Pmenu", { fg = c.fg, bg = c.bg_surface })
    hi("PmenuSel", { fg = c.bg, bg = c.teal_hi, bold = true })
    hi("PmenuSbar", { bg = c.bg_alt })
    hi("PmenuThumb", { bg = c.bg_grid })
    hi("WildMenu", { fg = c.bg, bg = c.teal_hi })
    hi("FloatBorder", { fg = c.teal_2, bg = float_bg })
    hi("FloatTitle", { fg = c.teal_hi, bg = float_bg, bold = true })

    -- ── Statusline / Tabs ────────────────────────────────────────────────
    hi("StatusLine", { fg = c.fg, bg = bar_bg })
    hi("StatusLineNC", { fg = c.fg_muted, bg = float_bg })
    hi("TabLine", { fg = c.fg_muted, bg = bar_bg })
    hi("TabLineSel", { fg = c.teal_hi, bg = main_bg, bold = true })
    hi("TabLineFill", { bg = bar_bg })
    hi("MsgArea", { fg = c.fg, bg = main_bg })
    hi("MsgSeparator", { fg = c.bg_grid, bg = main_bg })

    -- ── Diagnostics ──────────────────────────────────────────────────────
    hi("DiagnosticError", { fg = c.coral })
    hi("DiagnosticWarn", { fg = c.amber })
    hi("DiagnosticInfo", { fg = c.teal_6 })
    hi("DiagnosticHint", { fg = c.lavender })
    hi("DiagnosticOk", { fg = c.sage })
    hi("DiagnosticVirtualTextError", { fg = c.coral, italic = true })
    hi("DiagnosticVirtualTextWarn", { fg = c.amber, italic = true })
    hi("DiagnosticVirtualTextInfo", { fg = c.teal_6, italic = true })
    hi("DiagnosticVirtualTextHint", { fg = c.lavender, italic = true })
    hi("DiagnosticUnderlineError", { undercurl = true, sp = c.coral })
    hi("DiagnosticUnderlineWarn", { undercurl = true, sp = c.amber })
    hi("DiagnosticUnderlineInfo", { undercurl = true, sp = c.teal_6 })
    hi("DiagnosticUnderlineHint", { undercurl = true, sp = c.lavender })
    hi("DiagnosticSignError", { fg = c.coral, bg = main_bg })
    hi("DiagnosticSignWarn", { fg = c.amber, bg = main_bg })
    hi("DiagnosticSignInfo", { fg = c.teal_6, bg = main_bg })
    hi("DiagnosticSignHint", { fg = c.lavender, bg = main_bg })

    -- ── Diff ─────────────────────────────────────────────────────────────
    hi("DiffAdd", { fg = c.sage, bg = c.diff_add })
    hi("DiffChange", { fg = c.teal_6, bg = c.diff_change })
    hi("DiffDelete", { fg = c.coral, bg = c.diff_delete })
    hi("DiffText", { fg = c.amber, bg = c.diff_text, bold = true })

    -- ── Misc ─────────────────────────────────────────────────────────────
    hi("MatchParen", { fg = c.teal_hi, bold = true, underline = true })
    hi("Conceal", { fg = c.fg_dim })
    hi("NonText", { fg = c.fg_subtle })
    hi("Whitespace", { fg = c.fg_subtle })
    hi("SpecialKey", { fg = c.fg_subtle })
    hi("Title", { fg = c.teal_hi, bold = true })
    hi("Directory", { fg = c.teal_6 })
    hi("ErrorMsg", { fg = c.coral, bold = true })
    hi("WarningMsg", { fg = c.amber, bold = true })
    hi("Question", { fg = c.teal_6, bold = true })
    hi("MoreMsg", { fg = c.teal_hi })
    hi("ModeMsg", { fg = c.fg, bold = true })
    hi("SpellBad", { undercurl = true, sp = c.coral })
    hi("SpellCap", { undercurl = true, sp = c.amber })
    hi("SpellRare", { undercurl = true, sp = c.lavender })
    hi("SpellLocal", { undercurl = true, sp = c.teal_6 })

    -- ── Standard syntax (fallback for non-Treesitter) ────────────────────
    hi("Comment", { fg = c.fg_dim, italic = true })
    hi("Constant", { fg = c.rose })
    hi("String", { fg = c.amber })
    hi("Character", { fg = c.amber })
    hi("Number", { fg = c.rose })
    hi("Float", { fg = c.rose })
    hi("Boolean", { fg = c.sage, italic = true })
    hi("Identifier", { fg = c.fg })
    hi("Function", { fg = c.teal_hi })
    hi("Statement", { fg = c.teal_6 })
    hi("Conditional", { fg = c.teal_6 })
    hi("Repeat", { fg = c.teal_6 })
    hi("Label", { fg = c.teal_5 })
    hi("Operator", { fg = c.teal_4 })
    hi("Keyword", { fg = c.teal_6 })
    hi("Exception", { fg = c.coral, bold = true })
    hi("PreProc", { fg = c.lavender })
    hi("Include", { fg = c.lavender })
    hi("Define", { fg = c.lavender })
    hi("Macro", { fg = c.lavender_dim })
    hi("PreCondit", { fg = c.lavender })
    hi("Type", { fg = c.lavender })
    hi("StorageClass", { fg = c.teal_6, italic = true })
    hi("Structure", { fg = c.lavender })
    hi("Typedef", { fg = c.lavender })
    hi("Special", { fg = c.amber_dim })
    hi("SpecialChar", { fg = c.amber_dim, bold = true })
    hi("SpecialComment", { fg = c.teal_5, italic = true })
    hi("Tag", { fg = c.teal_6 })
    hi("Delimiter", { fg = c.fg_muted })
    hi("Debug", { fg = c.coral })
    hi("Underlined", { underline = true, fg = c.teal_6 })
    hi("Error", { fg = c.coral, bold = true })
    hi("Todo", { fg = c.amber, bold = true })

    -- ── Treesitter ───────────────────────────────────────────────────────
    hi("@comment", { fg = c.fg_dim, italic = true })
    hi("@comment.documentation", { fg = c.fg_muted, italic = true })
    hi("@comment.todo", { fg = c.teal_6, bold = true })
    hi("@comment.warning", { fg = c.amber, bold = true })
    hi("@comment.error", { fg = c.coral, bold = true })
    hi("@comment.note", { fg = c.teal_5, bold = true })

    hi("@keyword", { fg = c.teal_6 })
    hi("@keyword.return", { fg = c.coral })
    hi("@keyword.conditional", { fg = c.teal_6 })
    hi("@keyword.repeat", { fg = c.teal_6 })
    hi("@keyword.import", { fg = c.lavender })
    hi("@keyword.modifier", { fg = c.teal_5, italic = true })
    hi("@keyword.function", { fg = c.teal_6 })
    hi("@keyword.operator", { fg = c.teal_4 })
    hi("@keyword.exception", { fg = c.coral, bold = true })
    hi("@keyword.coroutine", { fg = c.teal_6, italic = true })

    hi("@function", { fg = c.teal_hi })
    hi("@function.call", { fg = c.teal_6 })
    hi("@function.builtin", { fg = c.teal_hi, italic = true })
    hi("@function.macro", { fg = c.lavender_dim })
    hi("@function.method", { fg = c.teal_hi })
    hi("@function.method.call", { fg = c.teal_6 })
    hi("@method", { fg = c.teal_hi })
    hi("@method.call", { fg = c.teal_6 })

    hi("@parameter", { fg = c.fg, italic = true })
    hi("@variable", { fg = c.fg })
    hi("@variable.builtin", { fg = c.coral, italic = true })
    hi("@variable.parameter", { fg = c.fg, italic = true })
    hi("@variable.member", { fg = c.teal_5 })

    hi("@type", { fg = c.lavender })
    hi("@type.builtin", { fg = c.lavender, italic = true })
    hi("@type.definition", { fg = c.lavender })
    hi("@type.qualifier", { fg = c.teal_5, italic = true })
    hi("@constructor", { fg = c.lavender })

    hi("@namespace", { fg = c.lavender_dim })
    hi("@module", { fg = c.lavender_dim })
    hi("@module.builtin", { fg = c.lavender, italic = true })
    hi("@attribute", { fg = c.teal_6, italic = true })
    hi("@attribute.builtin", { fg = c.teal_6, bold = true, italic = true })

    hi("@string", { fg = c.amber })
    hi("@string.documentation", { fg = c.amber_dim, italic = true })
    hi("@string.escape", { fg = c.coral, bold = true })
    hi("@string.regexp", { fg = c.rose })
    hi("@string.special", { fg = c.amber_dim })
    hi("@string.special.url", { fg = c.teal_6, underline = true })
    hi("@character", { fg = c.amber })
    hi("@character.special", { fg = c.coral, bold = true })

    hi("@number", { fg = c.rose })
    hi("@number.float", { fg = c.rose })
    hi("@boolean", { fg = c.sage, italic = true })
    hi("@constant", { fg = c.rose })
    hi("@constant.builtin", { fg = c.sage, italic = true })
    hi("@constant.macro", { fg = c.lavender_dim })

    hi("@operator", { fg = c.teal_4 })
    hi("@punctuation.delimiter", { fg = c.fg_muted })
    hi("@punctuation.bracket", { fg = c.fg_muted })
    hi("@punctuation.special", { fg = c.coral })

    hi("@tag", { fg = c.teal_6 })
    hi("@tag.attribute", { fg = c.amber, italic = true })
    hi("@tag.delimiter", { fg = c.fg_muted })
    hi("@tag.builtin", { fg = c.teal_6, italic = true })

    hi("@label", { fg = c.teal_5 })
    hi("@property", { fg = c.teal_5 })
    hi("@field", { fg = c.teal_5 })

    -- Markup (markdown, RST, etc.)
    hi("@markup", { fg = c.fg })
    hi("@markup.strong", { fg = c.teal_hi, bold = true })
    hi("@markup.italic", { fg = c.teal_6, italic = true })
    hi("@markup.strikethrough", { strikethrough = true })
    hi("@markup.underline", { underline = true })
    hi("@markup.heading", { fg = c.teal_hi, bold = true })
    hi("@markup.heading.1", { fg = c.teal_hi, bold = true })
    hi("@markup.heading.2", { fg = c.teal_6, bold = true })
    hi("@markup.heading.3", { fg = c.teal_5, bold = true })
    hi("@markup.heading.4", { fg = c.lavender, bold = true })
    hi("@markup.heading.5", { fg = c.amber, bold = true })
    hi("@markup.heading.6", { fg = c.rose, bold = true })
    hi("@markup.quote", { fg = c.fg_muted, italic = true })
    hi("@markup.math", { fg = c.lavender })
    hi("@markup.environment", { fg = c.lavender })
    hi("@markup.link", { fg = c.teal_6 })
    hi("@markup.link.label", { fg = c.teal_hi, underline = true })
    hi("@markup.link.url", { fg = c.amber, underline = true, italic = true })
    hi("@markup.raw", { fg = c.amber, bg = c.bg_alt })
    hi("@markup.raw.block", { bg = c.bg_alt })
    hi("@markup.list", { fg = c.coral })
    hi("@markup.list.checked", { fg = c.sage })
    hi("@markup.list.unchecked", { fg = c.fg_muted })

    -- Diff in treesitter
    hi("@diff.plus", { fg = c.sage })
    hi("@diff.minus", { fg = c.coral })
    hi("@diff.delta", { fg = c.amber })

    -- Legacy/compat aliases
    hi("@text", { fg = c.fg })
    hi("@text.strong", { bold = true })
    hi("@text.emphasis", { italic = true })
    hi("@text.underline", { underline = true })
    hi("@text.strike", { strikethrough = true })
    hi("@text.title", { fg = c.teal_hi, bold = true })
    hi("@text.uri", { fg = c.teal_6, underline = true })
    hi("@text.todo", { fg = c.bg, bg = c.teal_6, bold = true })
    hi("@text.note", { fg = c.teal_5, bold = true })
    hi("@text.warning", { fg = c.amber, bold = true })
    hi("@text.danger", { fg = c.coral, bold = true })

    -- ── LSP Semantic Tokens ──────────────────────────────────────────────
    hi("@lsp.type.function", { fg = c.teal_hi })
    hi("@lsp.type.method", { fg = c.teal_hi })
    hi("@lsp.type.variable", { fg = c.fg })
    hi("@lsp.type.parameter", { fg = c.fg, italic = true })
    hi("@lsp.type.type", { fg = c.lavender })
    hi("@lsp.type.class", { fg = c.lavender, bold = true })
    hi("@lsp.type.interface", { fg = c.lavender })
    hi("@lsp.type.struct", { fg = c.lavender })
    hi("@lsp.type.enum", { fg = c.lavender })
    hi("@lsp.type.enumMember", { fg = c.rose })
    hi("@lsp.type.keyword", { fg = c.teal_6 })
    hi("@lsp.type.comment", { fg = c.fg_dim, italic = true })
    hi("@lsp.type.string", { fg = c.amber })
    hi("@lsp.type.number", { fg = c.rose })
    hi("@lsp.type.operator", { fg = c.teal_4 })
    hi("@lsp.type.namespace", { fg = c.lavender_dim })
    hi("@lsp.type.macro", { fg = c.lavender_dim })
    hi("@lsp.type.decorator", { fg = c.teal_6, italic = true })
    hi("@lsp.type.property", { fg = c.teal_5 })
    hi("@lsp.type.event", { fg = c.coral })
    hi("@lsp.mod.deprecated", { strikethrough = true, fg = c.fg_muted })
    hi("@lsp.mod.readonly", { italic = true })
    hi("@lsp.mod.defaultLibrary", { italic = true })

    -- ── Telescope ────────────────────────────────────────────────────────
    hi("TelescopeNormal", { fg = c.fg, bg = float_bg })
    hi("TelescopeBorder", { fg = c.teal_2, bg = float_bg })
    hi("TelescopePromptNormal", { fg = c.fg, bg = c.bg_surface })
    hi("TelescopePromptBorder", { fg = c.teal_3, bg = c.bg_surface })
    hi("TelescopePromptTitle", { fg = c.bg, bg = c.teal_hi, bold = true })
    hi("TelescopePreviewNormal", { bg = float_bg })
    hi("TelescopePreviewBorder", { fg = c.teal_2, bg = float_bg })
    hi("TelescopePreviewTitle", { fg = c.bg, bg = c.lavender, bold = true })
    hi("TelescopeResultsNormal", { bg = float_bg })
    hi("TelescopeResultsBorder", { fg = c.teal_2, bg = float_bg })
    hi("TelescopeResultsTitle", { fg = c.bg, bg = c.amber, bold = true })
    hi("TelescopeSelection", { fg = c.fg_bright, bg = c.bg_selection, bold = true })
    hi("TelescopeSelectionCaret", { fg = c.teal_hi, bg = c.bg_selection })
    hi("TelescopeMultiSelection", { fg = c.amber })
    hi("TelescopePromptPrefix", { fg = c.teal_hi })
    hi("TelescopeMatching", { fg = c.amber, bold = true })

    -- ── NvimTree ─────────────────────────────────────────────────────────
    hi("NvimTreeNormal", { fg = c.fg, bg = main_bg })
    hi("NvimTreeNormalNC", { fg = c.fg, bg = main_bg })
    hi("NvimTreeRootFolder", { fg = c.teal_hi, bold = true })
    hi("NvimTreeFolderIcon", { fg = c.teal_6 })
    hi("NvimTreeFolderName", { fg = c.teal_6 })
    hi("NvimTreeOpenedFolderName", { fg = c.teal_hi, bold = true })
    hi("NvimTreeEmptyFolderName", { fg = c.fg_muted })
    hi("NvimTreeOpenedFile", { fg = c.teal_hi, bold = true })
    hi("NvimTreeFileIcon", { fg = c.fg })
    hi("NvimTreeGitDirty", { fg = c.amber })
    hi("NvimTreeGitNew", { fg = c.sage })
    hi("NvimTreeGitDeleted", { fg = c.coral })
    hi("NvimTreeGitStaged", { fg = c.teal_6 })
    hi("NvimTreeGitMerge", { fg = c.coral })
    hi("NvimTreeGitRenamed", { fg = c.lavender })
    hi("NvimTreeGitIgnored", { fg = c.fg_dim })
    hi("NvimTreeIndentMarker", { fg = c.bg_indent })
    hi("NvimTreeSpecialFile", { fg = c.amber, underline = true })
    hi("NvimTreeSymlink", { fg = c.lavender, italic = true })
    hi("NvimTreeWinSeparator", { fg = c.bg_grid, bg = main_bg })
    hi("NvimTreeCursorLine", { bg = c.bg_highlight })

    -- ── Gitsigns ─────────────────────────────────────────────────────────
    hi("GitSignsAdd", { fg = c.sage })
    hi("GitSignsChange", { fg = c.amber })
    hi("GitSignsDelete", { fg = c.coral })
    hi("GitSignsAddNr", { fg = c.sage })
    hi("GitSignsChangeNr", { fg = c.amber })
    hi("GitSignsDeleteNr", { fg = c.coral })
    hi("GitSignsAddLn", { bg = c.diff_add })
    hi("GitSignsChangeLn", { bg = c.diff_change })
    hi("GitSignsDeleteLn", { bg = c.diff_delete })
    hi("GitSignsCurrentLineBlame", { fg = c.fg_dim, italic = true })

    -- ── Barbar (buffer tabs) ─────────────────────────────────────────────
    hi("BufferCurrent", { fg = c.fg_bright, bg = main_bg, bold = true })
    hi("BufferCurrentMod", { fg = c.amber, bg = main_bg, bold = true })
    hi("BufferCurrentSign", { fg = c.teal_hi, bg = main_bg })
    hi("BufferCurrentIcon", { bg = main_bg })
    hi("BufferVisible", { fg = c.fg_muted, bg = bar_bg })
    hi("BufferVisibleMod", { fg = c.amber, bg = bar_bg })
    hi("BufferVisibleSign", { fg = c.fg_muted, bg = bar_bg })
    hi("BufferInactive", { fg = c.fg_muted, bg = bar_bg })
    hi("BufferInactiveMod", { fg = c.amber, bg = bar_bg })
    hi("BufferInactiveSign", { fg = c.bg_grid, bg = bar_bg })
    hi("BufferTabpageFill", { bg = bar_bg })

    -- ── Which-key ────────────────────────────────────────────────────────
    hi("WhichKey", { fg = c.teal_hi })
    hi("WhichKeyGroup", { fg = c.lavender })
    hi("WhichKeyDesc", { fg = c.fg })
    hi("WhichKeySeparator", { fg = c.fg_muted })
    hi("WhichKeyFloat", { bg = float_bg })
    hi("WhichKeyBorder", { fg = c.teal_2 })
    hi("WhichKeyValue", { fg = c.fg_muted })

    -- ── Indent Blankline ─────────────────────────────────────────────────
    hi("IblIndent", { fg = c.bg_indent })
    hi("IblScope", { fg = c.teal_3 })

    -- ── Notify ───────────────────────────────────────────────────────────
    hi("NotifyERRORBorder", { fg = c.coral })
    hi("NotifyWARNBorder", { fg = c.amber })
    hi("NotifyINFOBorder", { fg = c.teal_6 })
    hi("NotifyDEBUGBorder", { fg = c.fg_muted })
    hi("NotifyTRACEBorder", { fg = c.lavender })
    hi("NotifyERRORTitle", { fg = c.coral })
    hi("NotifyWARNTitle", { fg = c.amber })
    hi("NotifyINFOTitle", { fg = c.teal_6 })
    hi("NotifyDEBUGTitle", { fg = c.fg_muted })
    hi("NotifyTRACETitle", { fg = c.lavender })
    hi("NotifyERRORIcon", { fg = c.coral })
    hi("NotifyWARNIcon", { fg = c.amber })
    hi("NotifyINFOIcon", { fg = c.teal_6 })
    hi("NotifyDEBUGIcon", { fg = c.fg_muted })
    hi("NotifyTRACEIcon", { fg = c.lavender })

    -- ── Leap ─────────────────────────────────────────────────────────────
    hi("LeapMatch", { fg = c.teal_hi, bold = true, underline = true })
    hi("LeapLabelPrimary", { fg = c.bg, bg = c.teal_hi, bold = true })
    hi("LeapLabelSecondary", { fg = c.bg, bg = c.amber, bold = true })

    -- ── Todo Comments ────────────────────────────────────────────────────
    hi("TodoBgTODO", { fg = c.bg, bg = c.teal_6, bold = true })
    hi("TodoBgFIX", { fg = c.bg, bg = c.coral, bold = true })
    hi("TodoBgWARN", { fg = c.bg, bg = c.amber, bold = true })
    hi("TodoBgNOTE", { fg = c.bg, bg = c.lavender, bold = true })
    hi("TodoBgHACK", { fg = c.bg, bg = c.sage, bold = true })
    hi("TodoFgTODO", { fg = c.teal_6 })
    hi("TodoFgFIX", { fg = c.coral })
    hi("TodoFgWARN", { fg = c.amber })
    hi("TodoFgNOTE", { fg = c.lavender })
    hi("TodoFgHACK", { fg = c.sage })

    -- ── Diffview ─────────────────────────────────────────────────────────
    hi("DiffviewDiffAddAsDelete", { fg = c.coral, bg = c.diff_delete })
    hi("DiffviewDiffDelete", { fg = c.bg_grid })
    hi("DiffviewFilePanelTitle", { fg = c.teal_hi, bold = true })
    hi("DiffviewFilePanelCounter", { fg = c.amber, bold = true })

    -- ── nvim-cmp ─────────────────────────────────────────────────────────
    hi("CmpItemAbbr", { fg = c.fg })
    hi("CmpItemAbbrDeprecated", { fg = c.fg_dim, strikethrough = true })
    hi("CmpItemAbbrMatch", { fg = c.teal_hi, bold = true })
    hi("CmpItemAbbrMatchFuzzy", { fg = c.teal_6 })
    hi("CmpItemMenu", { fg = c.fg_muted, italic = true })
    hi("CmpItemKindFunction", { fg = c.teal_hi })
    hi("CmpItemKindMethod", { fg = c.teal_hi })
    hi("CmpItemKindVariable", { fg = c.fg })
    hi("CmpItemKindKeyword", { fg = c.teal_6 })
    hi("CmpItemKindText", { fg = c.fg_muted })
    hi("CmpItemKindClass", { fg = c.lavender })
    hi("CmpItemKindInterface", { fg = c.lavender })
    hi("CmpItemKindStruct", { fg = c.lavender })
    hi("CmpItemKindModule", { fg = c.lavender_dim })
    hi("CmpItemKindSnippet", { fg = c.amber })
    hi("CmpItemKindField", { fg = c.teal_5 })
    hi("CmpItemKindProperty", { fg = c.teal_5 })
    hi("CmpItemKindConstant", { fg = c.rose })
    hi("CmpItemKindEnum", { fg = c.lavender })
    hi("CmpItemKindEnumMember", { fg = c.rose })
    hi("CmpItemKindValue", { fg = c.amber })
    hi("CmpItemKindUnit", { fg = c.rose })
    hi("CmpItemKindFile", { fg = c.fg })
    hi("CmpItemKindFolder", { fg = c.teal_6 })
    hi("CmpItemKindColor", { fg = c.coral })

    -- ── Mason ────────────────────────────────────────────────────────────
    hi("MasonNormal", { bg = float_bg })
    hi("MasonHeader", { fg = c.bg, bg = c.teal_hi, bold = true })
    hi("MasonHighlight", { fg = c.teal_hi })
    hi("MasonHighlightBlock", { fg = c.bg, bg = c.teal_6 })
    hi("MasonHighlightBlockBold", { fg = c.bg, bg = c.teal_hi, bold = true })
    hi("MasonMuted", { fg = c.fg_muted })
    hi("MasonMutedBlock", { fg = c.fg_muted, bg = c.bg_alt })

    -- ── Claude sidebar ───────────────────────────────────────────────────
    hi("ClaudeTitle", { fg = c.teal_hi, bg = float_bg, bold = true })
    hi("ClaudeBorder", { fg = c.teal_2, bg = float_bg })

    -- ── Alpha dashboard ──────────────────────────────────────────────────
    hi("AlphaHeader", { fg = c.teal_hi })
    hi("AlphaButtons", { fg = c.teal_6 })
    hi("AlphaShortcut", { fg = c.amber, italic = true, bold = true })
    hi("AlphaFooter", { fg = c.fg_muted, italic = true })

    -- ── Render-markdown / markdown ───────────────────────────────────────
    hi("RenderMarkdownH1", { fg = c.teal_hi, bold = true })
    hi("RenderMarkdownH2", { fg = c.teal_6, bold = true })
    hi("RenderMarkdownH3", { fg = c.teal_5, bold = true })
    hi("RenderMarkdownH4", { fg = c.lavender, bold = true })
    hi("RenderMarkdownH5", { fg = c.amber, bold = true })
    hi("RenderMarkdownH6", { fg = c.rose, bold = true })

    -- Heading backgrounds. The plugin's own defaults link these to DiffText,
    -- DiffAdd, DiffChange, DiffDelete, Visual and CursorColumn -- i.e. it paints
    -- diff and selection colours behind every heading. These are dim tints of the
    -- matching foreground instead, so the level reads from the hue and the bar
    -- never competes with the text.
    hi("RenderMarkdownH1Bg", { bg = c.h1_bg })
    hi("RenderMarkdownH2Bg", { bg = c.h2_bg })
    hi("RenderMarkdownH3Bg", { bg = c.h3_bg })
    hi("RenderMarkdownH4Bg", { bg = c.h4_bg })
    hi("RenderMarkdownH5Bg", { bg = c.h5_bg })
    hi("RenderMarkdownH6Bg", { bg = c.h6_bg })

    hi("RenderMarkdownCode", { bg = c.bg_alt })
    hi("RenderMarkdownCodeInline", { fg = c.amber, bg = c.bg_alt })
    hi("RenderMarkdownCodeInfo", { fg = c.fg_muted, bg = c.bg_alt, italic = true })
    hi("RenderMarkdownCodeBorder", { fg = c.bg_alt, bg = c.bg_alt })
    hi("RenderMarkdownCodeFallback", { fg = c.fg_muted, bg = c.bg_alt })

    -- Lists, rules and quotes.
    hi("RenderMarkdownBullet", { fg = c.teal_4 })
    hi("RenderMarkdownDash", { fg = c.bg_grid })
    hi("RenderMarkdownQuote", { fg = c.teal_2 })
    hi("RenderMarkdownSign", { fg = c.fg_subtle })
    hi("RenderMarkdownIndent", { fg = c.bg_indent })

    -- Checkboxes: unchecked is quiet, checked is clearly "done", and the custom
    -- `[~]` in-progress / `[!]` blocked states get their own accents.
    hi("RenderMarkdownUnchecked", { fg = c.fg_dim })
    hi("RenderMarkdownChecked", { fg = c.sage })
    hi("RenderMarkdownTodo", { fg = c.amber })

    -- Links.
    hi("RenderMarkdownLink", { fg = c.teal_6, underline = true })
    hi("RenderMarkdownLinkTitle", { fg = c.teal_5 })
    hi("RenderMarkdownWikiLink", { fg = c.lavender, underline = true })

    -- Pipe tables.
    hi("RenderMarkdownTableHead", { fg = c.teal_6, bold = true })
    hi("RenderMarkdownTableRow", { fg = c.fg })
    hi("RenderMarkdownTableFill", { fg = c.bg })

    -- ── Snacks (indent / notifier / dashboard / dim / statuscolumn) ──────
    -- These replaced indent-blankline, nvim-notify, dressing and alpha, and had no
    -- groups defined here, so they were rendering against fallbacks.
    hi("SnacksIndent", { fg = c.bg_indent })
    hi("SnacksIndentScope", { fg = c.teal_2 })
    hi("SnacksNotifierInfo", { fg = c.teal_6, bg = float_bg })
    hi("SnacksNotifierWarn", { fg = c.amber, bg = float_bg })
    hi("SnacksNotifierError", { fg = c.coral, bg = float_bg })
    hi("SnacksNotifierDebug", { fg = c.fg_dim, bg = float_bg })
    hi("SnacksNotifierTrace", { fg = c.lavender, bg = float_bg })
    hi("SnacksNotifierBorderInfo", { fg = c.teal_2, bg = float_bg })
    hi("SnacksNotifierBorderWarn", { fg = c.amber_dim, bg = float_bg })
    hi("SnacksNotifierBorderError", { fg = c.coral, bg = float_bg })
    -- Dashboard: one colour, no gradient. The old alpha header used cyberdream's
    -- cyan->magenta->orange ramp, which appeared nowhere else on screen.
    hi("SnacksDashboardHeader", { fg = c.teal_hi })
    hi("SnacksDashboardIcon", { fg = c.teal_5 })
    hi("SnacksDashboardKey", { fg = c.amber })
    hi("SnacksDashboardDesc", { fg = c.fg_muted })
    hi("SnacksDashboardFooter", { fg = c.fg_dim, italic = true })
    hi("SnacksDashboardTitle", { fg = c.teal_6 })
    hi("SnacksDim", { fg = c.fg_subtle })
    hi("SnacksInputBorder", { fg = c.teal_2, bg = float_bg })
    hi("SnacksInputTitle", { fg = c.teal_hi, bg = float_bg })

    -- ── Which-key ────────────────────────────────────────────────────────
    hi("WhichKeyNormal", { bg = float_bg })
    hi("WhichKeyBorder", { fg = c.teal_2, bg = float_bg })
    hi("WhichKeyTitle", { fg = c.teal_hi, bg = float_bg })
    hi("WhichKeyGroup", { fg = c.lavender })
    hi("WhichKeyDesc", { fg = c.fg })
    hi("WhichKey", { fg = c.amber })
    hi("WhichKeySeparator", { fg = c.fg_subtle })

    -- ── Winbar / Trouble / yank flash ────────────────────────────────────
    hi("WinBar", { fg = c.fg_muted, bg = main_bg })
    hi("WinBarNC", { fg = c.fg_subtle, bg = main_bg })
    hi("ClaudeTitle", { fg = c.teal_hi, bold = true })
    hi("TroubleNormal", { bg = bar_bg })
    hi("TroubleText", { fg = c.fg })
    hi("TroubleCount", { fg = c.lavender, bg = c.bg_surface })
    -- ── glassterm (floating terminal) ─────────────────────────────────
    -- The float shares the editor's background, so with transparency on it
    -- is the same Ghostty glass as the code around it.
    hi("GlasstermNormal", { fg = c.fg, bg = main_bg })
    hi("GlasstermBorder", { fg = c.teal_2 })
    hi("GlasstermAccent", { fg = c.teal_hi })
    hi("GlasstermTitle", { fg = c.teal_hi, bold = true })
    hi("GlasstermHint", { fg = c.fg_muted })
    hi("GlasstermError", { fg = c.coral })
    hi("GlasstermErrorChip", { fg = c.bg, bg = c.coral, bold = true })
    hi("GlasstermTab", { fg = c.fg_dim })
    hi("GlasstermTabActive", { fg = c.bg, bg = c.teal_hi, bold = true })

    -- Dedicated yank highlight. This used IncSearch (dark-on-#66FFFF, bold), which
    -- strobed the whole line on every yank.
    hi("YankFlash", { bg = c.bg_selection })
end

return M
