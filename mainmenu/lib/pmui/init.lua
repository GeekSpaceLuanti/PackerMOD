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

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./")

local M = {}
-- The portable backend is the default; renderer="legacy" is opt-in.
M.modern = dofile(SELF_DIR .. "modern/init.lua")
M.new = M.modern.new
M.el = M.modern.el
M.parse_html = M.modern.parse_html
local ui_preferences = dofile(SELF_DIR .. "../../ui_preferences.lua")
local mainmenu_host=dofile(SELF_DIR.."modern/mainmenu.lua")
local bridge=dofile(SELF_DIR.."modern/bridge.lua")
M.control_defaults=dofile(SELF_DIR.."../../ui/controls.lua")
function M.host()return mainmenu_host.host(M.control_defaults)end
function M.configure_control(tag,properties)
    M.modern.new():configure(tag,properties)
    M.control_defaults[tag]=properties
end
function M.viewport_width()
    local wi=mainmenu_host.host().get_window_info()
    return math.min(1040,wi.size.x/(wi.real_gui_scaling or 1)-32)
end
function M.viewport_height()
    local wi=mainmenu_host.host().get_window_info()
    return wi.size.y/(wi.real_gui_scaling or 1)-32
end
function M.handle_fields(state,fields)
    if not state or not fields.pm_flow_scroll then return false end
    state.gui_scroll=tonumber(tostring(fields.pm_flow_scroll):match("%a+:(%d+)")) or state.gui_scroll
    return tostring(fields.pm_flow_scroll):match("^CHG:")~=nil
end
function M.render_widgets(root,opts)
    opts=opts or {}
    local fs,meta=M.modern.new(mainmenu_host.host(M.control_defaults)):render{
        tree=bridge.widgets(root),css=opts.modern_css,max_width=1040,scroll=opts.state and opts.state.gui_scroll}
    if opts.state then opts.state.gui_layout=meta end
    return fs..table.concat(opts.append or {}),meta
end

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
    if packermod and packermod.i18n and opts.ctx then
        local context = {}
        for k, v in pairs(opts.ctx) do
            context[k] = type(v) == "string" and k:find("status") and packermod.i18n.message(v) or v
        end
        opts.ctx = context
    end
    local html_text = opts.html or (opts.html_path and read_file(opts.html_path))
    local css_text  = opts.css  or (opts.css_path  and read_file(opts.css_path))
    if not html_text then error("pmui.build_formspec: missing html / html_path") end
    if not css_text  then css_text = "rules: []" end

    local page_w = opts.page_w or 13.0
    local page_h = opts.page_h or 8.5
    page_w, page_h = ui_preferences.viewport(page_w, page_h, opts.fixed_viewport)

    local root  = M.parser_html.parse(html_text, opts.ctx or {})
    if opts.renderer~="legacy" then
        local sheet=M.parser_css.parse(css_text)
        M.cascade.compute(root,sheet,{page_w=page_w,page_h=page_h})
        M.box_model.compute_all(root)
        local tree=bridge.dom(root)
        local fs,meta=M.modern.new(mainmenu_host.host(M.control_defaults)):render{
            tree=tree,css=opts.modern_css,max_width=tree.preferred_width or 1040,scroll=opts.state and opts.state.gui_scroll}
        if opts.state then opts.state.gui_layout=meta end
        return fs,meta
    end
    local sheet = M.parser_css.parse(css_text)
    M.cascade.compute(root, sheet, {
        page_w = page_w, page_h = page_h,
        hover_ids = opts.hover_ids, active_ids = opts.active_ids,
    })
    M.box_model.compute_all(root)
    -- One spacing scale for the page, instead of offsets for each field/button.
    -- Form rows measure their labels + controls; flex panels take what remains.
    local gap = math.max(0.3, math.min(0.55, page_w / 60))
    M.dom.walk(root, function(el)
        if el.tag == "grid" and opts.ctx and opts.ctx.grid_cols then el.box.grid_columns = opts.ctx.grid_cols end
        if el.tag == "page" then el.box.padding = gap * 1.6 end
        for _, class in ipairs(el.classes or {}) do
            if page_w < 25 then
                if root.attrs.layout ~= "flow" and (class == "subtab-actions" or class == "modal-actions") then
                    el.box.display, el.box.grid_columns, el.box.h = "grid", 2, nil
                elseif class == "subtab-btn" then
                    el.box.font_size = "*0.8"
                elseif class == "modal-dim" and #(el.text or "") > 40 then
                    el.tag, el.box.h, el.box.font_size = "paragraph", 1.6, "*0.8"
                elseif class == "detail-header" then
                    el.box.flex_direction, el.box.gap, el.box.h = "column", 0.15, nil
                    M.dom.walk(el, function(child)
                        if child.tag == "h2" or child.tag == "span" then
                            child.box.w, child._ellipsize = page_w - gap * 4, true
                        end
                    end)
                end
            end
            if class == "page-label" then
                el.box.w, el._ellipsize = math.min(12, page_w - 12), true
            end
            if class == "pack-card" and opts.ctx and opts.ctx.grid_cols then
                el.box.w = (page_w - gap * 3.2 - (opts.ctx.grid_cols - 1) * 0.45) / opts.ctx.grid_cols
                el.box.h = math.max(4.5, 3.5 + 0.9 * ui_preferences.font_scale())
            end
            if class == "modal-card" then
                el.box.padding = gap * 1.6
                el.box.gap = gap
                el.box.w = math.min(el.box.w or page_w, page_w - gap * 3.2)
            elseif class == "modal-card-wide" then
                el.box.h = nil
                el._max_h = page_h - gap * 3.2
            end
        end
    end)
    return M.paint.render(root, {
        page_w = page_w, page_h = page_h, ctx = opts.ctx,
        texture_dir = opts.texture_dir,
    })
end

return M
