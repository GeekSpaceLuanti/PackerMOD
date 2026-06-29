-- pmui: HTML/CSS 風 UI ライブラリ for PackerMOD。
-- 詳細は docs/decisions or mainmenu/lib/pmui/ の各ファイルを参照。
--
-- 公開 API:
--   pmui.build_formspec(opts) -> string
--     opts = {
--         html       = string?,        -- YAML テキスト (or html_path)
--         html_path  = string?,        -- ファイルパス
--         css        = string?,
--         css_path   = string?,
--         ctx        = table,          -- ${var} / for: 用の context
--         page_w     = number,         -- formspec の size[w,h] (省略時 13.0)
--         page_h     = number,         --                       (省略時 8.5)
--         hover_ids  = { [id]=true },  -- :hover マッチ対象
--         active_ids = { [id]=true },  -- :active マッチ対象
--     }
--
--   pmui.parse_html(text, ctx)  -> Element
--   pmui.parse_css(text)        -> Stylesheet
--   pmui.compute(root, sheet, opts)  -- cascade + box_model

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")

local M = {}

M.dom         = dofile(SELF_DIR .. "dom.lua")
M.stylesheet  = dofile(SELF_DIR .. "stylesheet.lua")
M.parser_html = dofile(SELF_DIR .. "parser_html.lua")
M.parser_css  = dofile(SELF_DIR .. "parser_css.lua")
M.cascade     = dofile(SELF_DIR .. "cascade.lua")
M.box_model   = dofile(SELF_DIR .. "box_model.lua")
M.layout      = dofile(SELF_DIR .. "layout.lua")
M.paint       = dofile(SELF_DIR .. "paint.lua")

local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then error("pmui: cannot open " .. tostring(path) .. ": " .. tostring(err)) end
    local s = f:read("*a"); f:close()
    return s
end

function M.build_formspec(opts)
    opts = opts or {}
    local html_text = opts.html or (opts.html_path and read_file(opts.html_path))
    local css_text  = opts.css  or (opts.css_path  and read_file(opts.css_path))
    if not html_text then error("pmui.build_formspec: missing html / html_path") end
    if not css_text  then css_text = "rules: []" end

    local page_w = opts.page_w or 13.0
    local page_h = opts.page_h or 8.5

    local root  = M.parser_html.parse(html_text, opts.ctx or {})
    local sheet = M.parser_css.parse(css_text)
    M.cascade.compute(root, sheet, {
        page_w = page_w, page_h = page_h,
        hover_ids = opts.hover_ids, active_ids = opts.active_ids,
    })
    M.box_model.compute_all(root)
    return M.paint.render(root, {
        page_w = page_w, page_h = page_h, ctx = opts.ctx,
        texture_dir = opts.texture_dir,
    })
end

return M
