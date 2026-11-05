-- Width-first reflow on a copy; resize never accumulates rows or sizes.
local M = {}
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, item in pairs(v) do out[k] = copy(item) end
    return out
end
function M.fit(source, width, height, measure, L, scroll_value)
    local function flow(node, available)
        available = math.max(0.5, available)
        local kind = node._kind
        if kind == "VBox" or kind == "HBox" then
            node._flow_decor, node.w = true, available
            local inner = math.max(0.5, available - 2 * node.padding)
            if kind == "HBox" then
                local rows, row, used = {}, {}, 0
                for _, child in ipairs(node) do
                    local preferred = child.w or 0
                    if child.flex and child.flex > 0 then
                        preferred = child._kind == "Spacer" and 0 or math.min(preferred, child.min_w or 6)
                    end
                    preferred = math.min(inner, preferred)
                    if #row > 0 and used + node.spacing + preferred > inner then
                        rows[#rows + 1], row, used = row, {}, 0
                    end
                    used = used + (#row > 0 and node.spacing or 0) + preferred
                    row[#row + 1] = { widget = child, width = preferred }
                end
                if #row > 0 then rows[#rows + 1] = row end
                local wrapped, total_h = {}, 0
                for _, items in ipairs(rows) do
                    local base, weight, row_h = node.spacing * (#items - 1), 0, 0
                    for _, item in ipairs(items) do
                        base = base + item.width
                        weight = weight + math.max(0, item.widget.flex or 0)
                    end
                    local line = L.HBox { spacing = node.spacing, align = node.align, w = inner }
                    for _, item in ipairs(items) do
                        local child = item.widget
                        local grow = weight > 0 and math.max(0, inner - base) * math.max(0, child.flex or 0) / weight or 0
                        flow(child, item.width + grow)
                        child.flex = nil
                        row_h = math.max(row_h, child.h)
                        line[#line + 1] = child
                    end
                    line.h = row_h
                    wrapped[#wrapped + 1], total_h = line, total_h + row_h
                end
                for i = #node, 1, -1 do node[i] = nil end
                node._kind, node.align = "VBox", "stretch"
                for _, item in ipairs(wrapped) do node[#node + 1] = item end
                node.h = math.max(node._user_h and node.h or 0, total_h + node.spacing * math.max(0, #wrapped - 1) + node.padding * 2)
            else
                local total = node.spacing * math.max(0, #node - 1) + node.padding * 2
                for _, child in ipairs(node) do
                    local cw = math.min(inner, child.w or inner)
                    if node.align == "stretch" and (child._kind == "VBox" or child._kind == "HBox" or child._kind == "TextList") then cw = inner end
                    flow(child, cw)
                    total = total + child.h
                end
                node.h = math.max(node._user_h and node.h or 0, total)
            end
        elseif kind == "Label" then
            local natural = node.w
            node.w = math.min(natural, available)
            if natural > available and not node.ellipsize then
                node._kind = "Paragraph"
                node.color = (node.text or ""):match("\27%(c@([^)]*)%)")
                node.text = (node.text or ""):gsub("\27%([^)]*%)", "")
                node.h = math.max(node.h, math.ceil(natural / available) * 0.55 + 0.3)
            end
        elseif kind == "Spacer" then
            node.w = available
        elseif kind == "TextList" then
            node.w = math.min(node.w or available, available)
            node.h = math.max(node.h or 0, math.min(6, math.max(1, #(node.items or {}))) * 0.65 + 0.3)
        else
            node.w = math.min(node.w or available, available)
        end
    end
    local root = copy(source)
    measure(root)
    flow(root, width)
    if root.h > height then
        root = copy(source)
        measure(root)
        flow(root, width - 0.5)
        root.flex = nil
        return L.VBox { w = width, h = height, spacing = 0,
            L.Scroll { name = "pm_flow_scroll", value = scroll_value or 0,
                w = width, h = height, root } }
    end
    return root
end
return M
