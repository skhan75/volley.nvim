-- Blazer: navy + muted pastels, matching ghostty's built-in "Blazer" theme
-- (/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Blazer).
--
-- Ghostty's ANSI palette is tuned for shell output on a black-ish bg: the
-- normal slots (#7ab8b8, #7a7ab8, ...) are too dim for syntax on navy and the
-- bright slots (#bddbdb, ...) too washed out to tell apart. Accents here sit
-- between the two, keeping each slot's hue.
--
-- Transparency: ON by default so ghostty's background-opacity + blur show
-- through. Set `vim.g.blazer_transparent = false` before loading to get the
-- solid #0d1926 background instead.
--
-- Groups live in lua/theme.lua; this file is only the palette. Keys keep the
-- hack role names (teal_hi = hero accent, amber = strings, ...).

local c = {
    -- ── Backgrounds ───────────────────────────────────────────────────
    bg = "#0d1926", -- ghostty background
    bg_dark = "#09131d", -- floats, deeper panels
    bg_alt = "#122133", -- slightly raised surfaces
    bg_surface = "#172a3f", -- pmenu, telescope prompts
    bg_highlight = "#142539", -- cursorline
    bg_selection = "#2b4a6e", -- visual selection (ghostty's #c1ddff, dimmed for text on top)
    bg_grid = "#24384f", -- borders, splits
    bg_indent = "#1a2c40", -- indent guides

    -- ── Foregrounds ───────────────────────────────────────────────────
    fg = "#d9e6f2", -- ghostty foreground
    fg_bright = "#f2f7fc",
    fg_muted = "#8d9db0",
    fg_dim = "#627488", -- comments
    fg_subtle = "#38495d", -- line numbers, gutters

    -- ── Accent ladder: blue -> cyan -> ghostty selection blue ────────
    teal_1 = "#3a5572",
    teal_2 = "#4a6886", -- float borders
    teal_3 = "#5d7d9e",
    teal_4 = "#8cc4c4", -- operators (ghostty cyan, lifted)
    teal_5 = "#aad3d3", -- properties, fields
    teal_6 = "#9ea4dc", -- keywords (ghostty blue, lifted)
    teal_hi = "#c1ddff", -- functions, hero accent (ghostty selection)

    -- ── Accents (ghostty slots 1/3/2/5, between normal and bright) ───
    amber = "#cbcb95", -- strings (yellow)
    amber_dim = "#a8a878",
    coral = "#d69696", -- errors (red)
    rose = "#cc9ccc", -- numbers, constants (magenta)
    sage = "#9ccc9c", -- booleans, additions (green)
    lavender = "#b8b8e6", -- types (bright blue)
    lavender_dim = "#9494c2",

    -- ── Diff ──────────────────────────────────────────────────────────
    diff_add = "#152e24",
    diff_change = "#15293f",
    diff_delete = "#33191f",
    diff_text = "#1f3b5a",

    -- ── Markdown heading bars (dim tints of each heading fg) ──────────
    h1_bg = "#1c2e45",
    h2_bg = "#1a2440",
    h3_bg = "#16293a",
    h4_bg = "#1d1f3a",
    h5_bg = "#23261f",
    h6_bg = "#271f30",
}

require("theme").apply("blazer", c, { transparent = vim.g.blazer_transparent ~= false })
