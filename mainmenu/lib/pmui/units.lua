-- pmui.units: px ⇄ formspec unit の換算と device-pixel snapping。
--
-- 単位系の設計 (詳細は .claude/plans/24-htlm-css-abstract-map.md):
--   * theme に書く px は "design px" = mockup ビューポート (1024x600, density 1,
--     gui_scaling 1) 基準の見かけ px。
--   * REF_UNIT_PX = そのビューポートでの unit_px (= max(短辺/15, 0.5555*96) = 53.33)。
--     Phase 0 で実測一致。
--   * 寸法 (w/h/padding/gap/border) の px→unit は design_px / REF_UNIT_PX。
--     これは unit_px に依存しない: 物理 px = design_px * unit_px/REF_UNIT_PX、
--     formspec unit = 物理px / unit_px = design_px / REF_UNIT_PX。
--     → window が育つと unit 数は不変のまま物理サイズが比例拡大する (vh 的)。
--   * font は px を直接 formspec へ渡す (hypertext size= / style font_size= は px)。
--     unit に追従しないので font_px = design_px * unit_px/REF_UNIT_PX で毎回 rebuild。

local M = {}

-- 0.5555 * 96: guiFormSpecMenu.cpp getFixedImgsize の下限 imgsize。
-- 1024x600 では min(1024,600)/15 = 40 < 53.33 なのでこの下限が効く。
M.REF_UNIT_PX = 0.5555 * 96  -- ≈ 53.328

-- エンジンが実際に使う unit_px を、emit する size[] と window から逆算する。
-- responsive (clamp 非発動) では win/page に一致し、固定 size 画面や min clamp
-- 発動時は fit 側が効く。responsive/固定で分岐せず 1 本の式で扱う
-- (clamp 時に font だけ過大になる事故を防ぐ)。guiFormSpecMenu.cpp:5278-5316 準拠。
--   win: {x=px, y=px}, page: {w=unit, h=unit}, real_gui_scaling, padding (formspec)
function M.effective_unit_px(win, page, real_gui_scaling, padding)
    padding = padding or 0
    local sx, sy = win.x, win.y
    local gs = real_gui_scaling or 1
    -- prefer_imgsize = max(min(win)/15, 0.5555*96*density) * gui_scaling。
    -- real_gui_scaling は既に gui_scaling*density なので density は乗せない
    -- (0.5555*96 の density は近似で 1 とみなす。実測でこの経路は下限側なので誤差小)。
    local prefer = math.max(math.min(sx, sy) / 15 * gs, M.REF_UNIT_PX * gs)
    local padded_x = sx * (1 - padding * 2)
    local padded_y = sy * (1 - padding * 2)
    local fitx = padded_x / page.w
    local fity = padded_y / page.h
    return math.min(prefer, fitx, fity)
end

-- design px → formspec unit (寸法用、unit_px 非依存)
function M.px_to_units(design_px)
    return design_px / M.REF_UNIT_PX
end

-- design px → 実 font px (unit_px 依存)。整数へ丸め。
function M.font_px(design_px, unit_px)
    return math.floor(design_px * unit_px / M.REF_UNIT_PX + 0.5)
end

-- unit 値を「整数 device px」へスナップする (最小 1px)。
-- サブピクセル境界で border が薄く/暗く描かれる #6 のような問題を防ぐ。
function M.snap_units(units, unit_px)
    if not unit_px or unit_px <= 0 then return units end
    local px = units * unit_px
    local snapped = math.max(1, math.floor(px + 0.5))
    return snapped / unit_px
end

-- "12px" / "12.5px" を design px (number) として取り出す。px でなければ nil。
function M.parse_px(v)
    if type(v) ~= "string" then return nil end
    local num = v:match("^%s*(-?[%d%.]+)px%s*$")
    if num then return tonumber(num) end
    return nil
end

return M
