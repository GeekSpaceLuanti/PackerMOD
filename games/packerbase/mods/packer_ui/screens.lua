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
.craft-screen { padding: 12px 16px; gap: 8px; }
h1 { font-size: 26px; font-weight: bold; }
h2 { font-size: 19px; font-weight: bold; }
.row { flex-direction: row; flex-wrap: wrap; align-items: center; gap: 8px; }
.columns { flex-direction: row; flex-wrap: wrap; align-items: stretch; gap: 12px; }
.catalogue { min-width: 280px; flex-grow: 1; }
.search-query { min-width: 106px; flex-grow: 1; }
.craft-panel { min-width: 366px; flex-grow: 1; }
.craft-row { flex-direction: row; flex-wrap: wrap; align-items: center; gap: 12px; }
.recipe-detail { border-width: 1px; border-color: var(--border); padding: 6px; gap: 5px; }
.muted { color: var(--muted); font-size: 14px; }
.panel { background: var(--inset); border-width: 1px; border-color: var(--border);
  padding: 12px; gap: 8px; }
button { min-height: 38px; padding: 8px 12px; background: var(--slot);
  border-width: 1px; border-color: var(--border); text-align: center; }
.selected { background: var(--active); color: var(--on-active); }
field { background: var(--slot); border-width: 1px; border-color: var(--border); border-radius: 0px; }
.tile { width: 32px; height: 32px; background: var(--slot);
  border-width: 1px; border-color: var(--border); }
.picked { border-width: 3px; border-color: var(--active); }
.grid-row { flex-direction: row; gap: 4px; }
.recipe-matrix { gap: 4px; }
.grid { flex-direction: row; flex-wrap: wrap; gap: 4px; }
.recipe-arrow { font-size: 24px; font-weight: bold; }
@media (max-width: 580px) { .screen { padding: 12px; } }
]]
	local renderer = ui.new({
		texture = function(name, color)
			if name == "icon_recipe_book" then return "default_book.png" end
			return "pmui_" .. name .. ".png" .. (color and "^[multiply:" .. color or "")
		end,
	})
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
	local function render(player, context, title, children, width, scroll, action)
		local layout = {nav(player, context), node("div", "row", {label("h1", title), action})}
		for _, child in ipairs(children) do layout[#layout + 1] = child end
		local high_contrast = player:get_meta():get_int(contrast_key) == 1
		local class = high_contrast and "screen high-contrast" or "screen"
		local window = core.get_player_window_information(player:get_player_name())
		if action then
			class = class .. " craft-screen"
			-- Keep both panels visible when GUI scaling is high on a small screen.
			if window then
				local max = window.max_formspec_size
				local pixels_per_unit = math.max(window.size.x / max.x, window.size.y / max.y)
				local fit = (max.x - 0.5) * pixels_per_unit / width
				window.real_gui_scaling = math.min(window.real_gui_scaling, math.max(0.85, fit))
			end
		end
		local fs = renderer:render({
			tree = node("main", class, layout),
			css = css,
			theme = false,
			window = window,
			max_width = width,
			backdrop = "#202A24A0",
			inventory_colors = high_contrast and {"#F7FAF2", "#BCDCC9", "#172B22"}
				or {"#D3CFBE", "#EBE8D9", "#515B54"},
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
