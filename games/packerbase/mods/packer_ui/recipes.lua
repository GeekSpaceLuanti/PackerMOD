-- SPDX-License-Identifier: LGPL-2.1-or-later
return function(ui)
	local function text(player, key, ...)
		return ui.translate(player, ui.S(key, ...))
	end
	local function item_name(item)
		local name = item:match("^%S+")
		local def = core.registered_items[name]
		return def and def.description ~= "" and def.description or name
	end
	return function(player, context, data, describe_item)
		local el, node, label, button = ui.el, ui.node, ui.label, ui.button
		local opened = context.packer_book_open or context.page == "mtg_craftguide:craftguide"
		local slot_size, slot_gap = 34, 4
		local function inventory(list, cols, rows, start)
			return el("inventory", {
				list = list, cols = cols, rows = rows, start = start,
				slot = slot_size, gap = slot_gap,
				inline = {
					width = cols * slot_size + (cols - 1) * slot_gap,
					height = rows * slot_size + (rows - 1) * slot_gap,
				},
			})
		end
		local count = player:get_inventory():get_size("main")
		local columns = math.max(1, math.min(9, player:hud_get_hotbar_itemcount()))
		local craft = {
			label("h2", text(player, "Crafting grid")),
			node("div", "craft-row", {
				inventory("craft", 3, 3),
				label("p", "→", "recipe-arrow"),
				inventory("craftpreview", 1, 1),
			}),
			label("h2", text(player, "Inventory")),
		}
		if count > columns then
			craft[#craft + 1] = inventory("main", columns, math.ceil((count - columns) / columns), columns)
		end
		craft[#craft + 1] = inventory("main", columns, 1)
		local craft_panel = node("section", "panel craft-panel", craft)
		local action = el("button", {
			class = opened and "selected" or nil, name = "packer_book_toggle", icon = "recipe_book",
			text = text(player, "Recipe book"),
			hover = opened and "#325C4D" or "#D6DCCD",
		})
		local function render(children)
			return ui.render(player, context, text(player, "Crafting"), children,
				opened and 720 or 420, data.packer_scroll, action)
				.. "listring[current_player;main]listring[current_player;craft]"
				.. "tooltip[packer_book_toggle;" .. core.formspec_escape(text(player,
					opened and "Close recipe book" or "Open recipe book")) .. "]"
		end
		if not opened then
			data.packer_items = {}
			return render({craft_panel})
		end
		local item_fields, next_id = {}, 0
		local function slot(stack, picked)
			if not stack or stack == "" then return node("div", "tile") end
			local item, tooltip, group = describe_item(stack)
			next_id = next_id + 1
			local name = "packer_item_" .. next_id
			item_fields[name] = item:match("^%S+")
			return el("item-button", {
				class = picked and "tile picked" or "tile",
				item = item, name = name, text = group and "G" or nil,
				tooltip = tooltip
			})
		end

		local first = (data.pagenum - 1) * data.packer_page_size + 1
		local items = {}
		for index = first, math.min(first + data.packer_page_size - 1, #data.items) do
			local item = data.items[index]
			items[#items + 1] = slot(item, item == data.prev_item)
		end
		local catalogue = node("section", "panel catalogue", {
			label("h2", text(player, "Recipe book")),
			node("div", "row", {
				el("field", {name = "filter", value = data.filter, class = "search-query"}),
				button("search", text(player, "Search")),
				button("clear", "×")
			}),
			#items > 0 and node("div", "grid", items) or label("p", text(player, "No matching items.")),
			node("div", "row", {
				button("prev", "<"),
				label("p", ("%d / %d"):format(data.pagenum, data.pagemax), "muted"),
				button("next", ">")
			})
		})

		local detail = {}
		if data.prev_item then
			detail[#detail + 1] = node("div", "row", {
				label("h2", ui.translate(player, item_name(data.prev_item))),
				button("packer_recipe_mode", text(player, data.show_usages and "Show recipes" or "Show uses")),
			})
		else
			detail[#detail + 1] = label("h2", text(player, "Ingredients"))
			detail[#detail + 1] = label("p", text(player, "Select an item to see its ingredients and uses."))
		end
		local recipe = data.recipes and data.recipes[data.rnum]
		if recipe then
			local rows = {}
			local width = recipe.width
			local method = text(player, "Crafting")
			if recipe.method == "cooking" then
				method = text(player, "Smelting time: @1 s", recipe.width)
				width = 1
			elseif width == 0 then
				method = text(player, "Shapeless")
				width = #recipe.items <= 1 and 1 or (#recipe.items <= 4 and 2 or 3)
			end
			detail[#detail + 1] = label("p", method, "muted")
			if width > 3 or math.ceil(table.maxn(recipe.items) / width) > 3 then
				detail[#detail + 1] = label("p", text(player, "This recipe is too large to display."))
			else
				for y = 0, 2 do
					local row = {}
					for x = 1, 3 do
						row[x] = slot(x <= width and recipe.items[y * width + x] or nil)
					end
					rows[#rows + 1] = node("div", "grid-row", row)
				end
				detail[#detail + 1] = node("div", "row", {
					node("section", "recipe-matrix", rows), label("p", "→", "recipe-arrow"), slot(recipe.output)
				})
			end
			if #data.recipes > 1 then
				detail[#detail + 1] = node("div", "row", {
					button("recipe_prev", "<"),
					label("p", ("%d / %d"):format(data.rnum, #data.recipes), "muted"),
					button("recipe_next", ">")
				})
			end
		elseif data.prev_item then
			detail[#detail + 1] = label("p", text(player, data.show_usages
				and "No uses found." or "No recipes found."))
		end
		data.packer_items = item_fields
		catalogue.children[#catalogue.children + 1] = node("section", "recipe-detail", detail)
		return render({node("div", "columns", {catalogue, craft_panel})})
			.. "field_enter_after_edit[filter;true]"
			.. "tooltip[clear;" .. core.formspec_escape(text(player, "Reset")) .. "]"
	end
end
