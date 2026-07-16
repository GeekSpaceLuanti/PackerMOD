-- pmui.host_mainmenu: mainmenu 環境の host adapter。
--
-- pmui コアは engine API (core.*) を直接触らず、この adapter 経由で呼ぶ。
-- 将来 in-game 版 (per-player window / set_sky 等) を別 adapter として差せるよう、
-- 全関数は第 1 引数に view コンテキストを取る (mainmenu では無視)。
--
-- 提供する capability:
--   * get_window_info(view)          -> {size, max_formspec_size, real_gui_scaling}
--   * supports_fullscreen_background -> bool (mainmenu は set_background で true)
--   * set_fullscreen_background(view, kind, path, opts)
--   * clear_fullscreen_background(view, kind)
--   * escape_hypertext(view, text)   -> string
--   * log(view, level, msg)

local M = {}

-- core 不在 (busted 等 headless) 時の REF フォールバック。
-- 1024x600 / gui_scaling 1 = design 基準ビューポート。これで build_formspec が
-- engine 無しでも決定論的に走り、spec が formspec 文字列を検証できる。
local FALLBACK_WINDOW = {
    size = { x = 1024, y = 600 },
    max_formspec_size = { x = 19.2019, y = 11.2511 },
    real_gui_scaling = 1,
}

local function has_core() return rawget(_G, "core") ~= nil end

function M.get_window_info(_view)
    if has_core() and core.get_window_info then
        local wi = core.get_window_info()
        -- 古いクライアント (5.7 未満) は max_formspec_size を返さないことがある。
        -- その場合は fallback で固定サイズに落とす (責務は呼び出し側の clamp)。
        if wi and wi.max_formspec_size and wi.size then
            return wi
        end
    end
    return FALLBACK_WINDOW
end

M.supports_fullscreen_background = has_core()

-- kind: "background" | "overlay"。opts.tile / opts.minsize で原寸タイル。
function M.set_fullscreen_background(_view, kind, path, opts)
    if not (has_core() and core.set_background) then return false end
    opts = opts or {}
    return core.set_background(kind or "background", path,
                              opts.tile and true or false, opts.minsize or 16)
end

function M.clear_fullscreen_background(_view, kind)
    if not (has_core() and core.set_background) then return false end
    return core.set_background(kind or "background", "")
end

function M.escape_hypertext(_view, text)
    text = tostring(text or "")
    if has_core() and core.hypertext_escape then
        return core.hypertext_escape(text)
    end
    -- fallback: hypertext のタグ開始 '<' と実体参照 '\' をエスケープ。
    return (text:gsub("\\", "\\\\"):gsub("<", "\\<"))
end

function M.log(_view, level, msg)
    if has_core() and core.log then
        core.log(level or "warning", "[pmui] " .. tostring(msg))
    end
end

return M
