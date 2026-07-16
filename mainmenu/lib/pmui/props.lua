-- pmui.props: タグ集合と CSS プロパティのレジストリを一元管理する。
-- 以前は CONTAINER_TAGS / LABEL_TAGS 等が layout.lua と paint.lua に重複していた
-- (「変更時は 2 ファイル更新」規約)。ここへ集約して同期崩れを無くす。
-- あわせて「box_model が消費する = 効くプロパティ」の集合を持ち、未知/効かない
-- プロパティを build 時に警告する (font-size を label に付けるような no-op の早期検出)。

local M = {}

M.CONTAINER_TAGS = {
    page = true, div = true, header = true, footer = true, section = true,
    nav  = true, card = true, grid = true, main = true,
}
-- status は含めない: pmui/layout.lua が status を専用ブランチ (attrs.text fallback 付き)
-- で扱い、paint.lua の is_label_tag も status を label 扱いしないため。
M.LABEL_TAGS = {
    h1 = true, h2 = true, h3 = true, span = true, p = true, label = true,
}
M.BUTTON_TAGS = {
    button = true, ["icon-button"] = true,
}

function M.is_container(tag) return M.CONTAINER_TAGS[tag] == true end
function M.is_label(tag)     return M.LABEL_TAGS[tag] == true end
function M.is_button(tag)    return M.BUTTON_TAGS[tag] == true end

-- box_model が実際に読むプロパティ (= 効くプロパティ)。ここに無い名前を CSS で
-- 指定してもサイレントに落ちるので警告対象にする。--var 定義や display 値ではなく
-- プロパティ名の集合。
M.KNOWN_PROPS = {
    ["padding"] = true, ["margin"] = true, ["gap"] = true,
    ["border-width"] = true, ["border-color"] = true,
    ["border-top-width"] = true, ["border-bottom-width"] = true,
    ["border-left-width"] = true, ["border-right-width"] = true,
    ["border-top-color"] = true, ["border-bottom-color"] = true,
    ["border-left-color"] = true, ["border-right-color"] = true,
    ["flex"] = true, ["flex-direction"] = true, ["w"] = true, ["h"] = true,
    ["justify"] = true, ["align"] = true, ["display"] = true,
    ["grid-columns"] = true, ["bg"] = true, ["background-color"] = true,
    ["bg-image"] = true, ["bg-image-hover"] = true, ["bg-image-middle"] = true,
    ["color"] = true, ["font-size"] = true, ["text-align"] = true,
    ["text-transform"] = true,
}

-- 特定タグで効かないプロパティ (エンジン制約由来の no-op)。
--   field/textarea: formspec の field style は border/font/font_size/textcolor のみ。
--     bg は無効 → border=false + 背後 box[] が定石 (paint 側で対応予定)。
M.NOOP_FOR_TAG = {
    field    = { ["bg"] = "field に bgcolor は無効 (border=false + box[] を使う)" },
    textarea = { ["bg"] = "textarea に bgcolor は無効 (border=false + box[] を使う)" },
}

-- cascade 後の DOM を走査し、未知/効かない CSS プロパティを warn へ通知する。
-- mainmenu は操作ごとに rebuild するため、同一 (tag, prop, 理由) の警告は
-- セッション内で 1 度だけ出す (seen で dedupe)。warn(msg) は adapter.log 等。
local seen = {}
function M.validate(root, dom_mod, warn)
    if type(warn) ~= "function" then return end
    dom_mod.walk(root, function(el)
        local c = el.computed
        if type(c) ~= "table" then return end
        local noop = M.NOOP_FOR_TAG[el.tag]
        for prop in pairs(c) do
            local key, msg
            if not M.KNOWN_PROPS[prop] then
                key = "unknown:" .. prop
                msg = ("未知の CSS プロパティ '%s' (tag=%s id=%s) はサイレントに無視される")
                    :format(prop, tostring(el.tag), tostring(el.id))
            elseif noop and noop[prop] then
                key = el.tag .. ":" .. prop
                msg = ("no-op プロパティ '%s' (tag=%s): %s"):format(prop, el.tag, noop[prop])
            end
            if key and not seen[key] then
                seen[key] = true
                warn(msg)
            end
        end
    end)
end

return M
