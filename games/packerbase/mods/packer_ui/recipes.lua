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

		local first = (data.pagenum - 1) * 32 + 1
		local items = {}
		for index = first, math.min(first + 31, #data.items) do
			local item = data.items[index]
			items[#items + 1] = slot(item, item == data.prev_item)
		end
		local catalogue = node("section", "panel catalogue", {
			label("h2", text(player, "Recipe book")),
			node("div", "row", {
				el("field", {name = "filter", value = data.filter, class = "grow"}),
				button("search", text(player, "Search")),
				button("clear", text(player, "Reset"))
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
			detail[#detail + 1] = label("h2", ui.translate(player, item_name(data.prev_item)))
			detail[#detail + 1] = button("packer_recipe_mode",
				text(player, data.show_usages and "Show recipes" or "Show uses"))
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
		return ui.render(player, context, text(player, "Recipes"), {
			node("div", "columns", {catalogue, node("section", "panel recipe-column", detail)})
		}, 820, data.packer_scroll) .. "field_enter_after_edit[filter;true]"
	end
end
