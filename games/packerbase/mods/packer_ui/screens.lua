-- SPDX-License-Identifier: LGPL-2.1-or-later
return function(ui)
	local S = core.get_translator("packer_ui")
	local el = ui.el
	local contrast_key = "packer_ui:high_contrast"
	local css = [[
:root { --panel: #C7C5B6; --inset: #A7AA9D; --border: #515B54;
  --text: #192522; --muted: #101A14; --active: #325C4D; --on-active: #F7F5E7;
  --slot: #E7E4D6; color: var(--text); font-size: 16px; line-height: 1.4; }
.high-contrast { --panel: #EDEEE8; --inset: #CDD5C9; --border: #172B22;
  --text: #0A1410; --muted: #172B22; --active: #173C2B; --on-active: #FFFFFF;
  --slot: #FFFFFF; }
.screen { background: var(--panel); color: var(--text); border-width: 2px;
  border-color: var(--border); padding: 20px; gap: 12px; }
h1 { font-size: 26px; font-weight: bold; }
h2 { font-size: 19px; font-weight: bold; }
.row { flex-direction: row; flex-wrap: wrap; align-items: center; gap: 8px; }
.columns { flex-direction: row; flex-wrap: wrap; align-items: stretch; gap: 12px; }
.recipe-column { min-width: 252px; flex-grow: 1; gap: 10px; }
.catalogue { min-width: 376px; flex-grow: 1; }
.grow { min-width: 130px; flex-grow: 1; }
.muted { color: var(--muted); font-size: 14px; }
.panel { background: var(--inset); border-width: 1px; border-color: var(--border);
  padding: 12px; gap: 8px; }
button { min-height: 38px; padding: 8px 12px; background: var(--slot);
  border-width: 1px; border-color: var(--border); text-align: center; }
.selected { background: var(--active); color: var(--on-active); }
field { background: var(--slot); border-width: 1px; border-color: var(--border); border-radius: 0px; }
.tile { width: 40px; height: 40px; background: var(--slot);
  border-width: 1px; border-color: var(--border); }
.picked { border-width: 3px; border-color: var(--active); }
.grid-row { flex-direction: row; gap: 4px; }
.recipe-matrix { gap: 4px; }
.grid { flex-direction: row; flex-wrap: wrap; gap: 4px; }
.recipe-arrow { font-size: 24px; font-weight: bold; }
@media (max-width: 580px) { .screen { padding: 12px; } }
]]
	local renderer = ui.new()
	local function node(tag, class, children)
		return el(tag, {class = class}, children)
	end
	local function label(tag, text, class)
		return el(tag, {text = text, class = class})
	end
	local function button(name, text, selected)
		return el("button", {name = name, text = text,
			class = selected and "selected" or nil, hover = selected and "#325C4D" or "#D6DCCD"})
	end
	local function translate(player, text)
		local info = core.get_player_information(player:get_player_name())
		return core.get_translated_string(info and info.lang_code or "en", text)
	end
	local function nav(player, context)
		local buttons = {}
		for i, title in ipairs(context.nav_titles or {}) do
			buttons[i] = button("packer_page_" .. i, translate(player, title), i == context.nav_idx)
		end
		return node("nav", "row", buttons)
	end
	local function render(player, context, title, children, width, scroll)
		local layout = {nav(player, context), label("h1", title)}
		for _, child in ipairs(children) do layout[#layout + 1] = child end
		local high_contrast = player:get_meta():get_int(contrast_key) == 1
		local fs = renderer:render({
			tree = node("main", high_contrast and "screen high-contrast" or "screen", layout),
			css = css,
			theme = false,
			window = core.get_player_window_information(player:get_player_name()),
			max_width = width,
			backdrop = "#202A24A0",
			scroll = scroll
		})
		return fs
	end
	local function receive(player, context, fields)
		for key in pairs(fields) do
			local index = tonumber(key:match("^packer_page_(%d+)$"))
			local page = index and context.nav and context.nav[index]
			if page then
				sfinv.set_page(player, page)
				return true
			end
		end
	end
	return {
		S = S, el = el, node = node, label = label, button = button, translate = translate,
		render = render, receive = receive, contrast_key = contrast_key
	}
end
