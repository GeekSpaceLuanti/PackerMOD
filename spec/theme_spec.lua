package.path = "./?.lua;" .. package.path

local theme = dofile("mainmenu/lib/theme.lua")

describe("theme.style_for", function()
    it("returns props for known button variants", function()
        for _, v in ipairs({ "primary", "secondary", "danger", "ghost" }) do
            local s = theme.style_for("button", v)
            assert.is_table(s, "no style for button/" .. v)
            assert.is_table(s.props)
            assert.is_string(s.props.bgcolor)
            assert.is_string(s.props.textcolor)
        end
    end)

    it("returns default props when variant is nil", function()
        local s = theme.style_for("button", nil)
        assert.is_table(s)
        assert.is_table(s.props)
    end)

    it("button bgcolor uses hex format #RRGGBB or #RRGGBBAA", function()
        for _, v in ipairs({ "primary", "secondary", "danger", "ghost" }) do
            local s = theme.style_for("button", v)
            assert.is_truthy(s.props.bgcolor:match("^#%x%x%x%x%x%x%x?%x?$"),
                v .. " has invalid bgcolor: " .. s.props.bgcolor)
        end
    end)

    it("returns nil for unknown kind", function()
        assert.is_nil(theme.style_for("nonexistent", "primary"))
    end)
end)

describe("theme.emit_style", function()
    it("emits a single style[name;k=v] line", function()
        local out = theme.emit_style("play", { bgcolor = "#3FA63F" })
        assert.are.equal("style[play;bgcolor=#3FA63F]", out)
    end)

    it("joins multiple props with ;", function()
        local out = theme.emit_style("x", { bgcolor = "#000000", textcolor = "#FFFFFF" })
        -- key order may vary; check both keys present
        assert.is_truthy(out:match("^style%[x;"))
        assert.is_truthy(out:find("bgcolor=#000000", 1, true))
        assert.is_truthy(out:find("textcolor=#FFFFFF", 1, true))
        assert.is_truthy(out:match("%]$"))
    end)

    it("returns nil/empty when props is empty", function()
        local out = theme.emit_style("x", {})
        assert.is_true(out == nil or out == "")
    end)
end)

describe("theme.emit_style_type", function()
    it("emits style_type[kind;k=v]", function()
        local out = theme.emit_style_type("button", { bgcolor = "#3A3A3A" })
        assert.are.equal("style_type[button;bgcolor=#3A3A3A]", out)
    end)
end)

describe("theme.emit_global_prelude", function()
    it("returns a list of formspec lines including bgcolor and style_type", function()
        local lines = theme.emit_global_prelude()
        assert.is_table(lines)
        local joined = table.concat(lines, "")
        assert.is_truthy(joined:find("bgcolor[", 1, true), "missing bgcolor[")
        assert.is_truthy(joined:find("style_type[button", 1, true), "missing style_type[button")
        assert.is_truthy(joined:find("style_type[field", 1, true), "missing style_type[field")
    end)
end)

describe("theme tokens", function()
    it("exposes colors / spacing / icons / button tables", function()
        assert.is_table(theme.colors)
        assert.is_table(theme.spacing)
        assert.is_table(theme.icons)
        assert.is_table(theme.button)
        assert.is_string(theme.colors.bg)
        assert.is_string(theme.colors.accent)
        assert.is_number(theme.spacing.md)
        assert.is_number(theme.icons.size_md)
    end)

    it("uses Minecraft-ish XP green accent", function()
        -- accent should be a green color (G > R, G > B)
        local r, g, b = theme.colors.accent:match("^#(%x%x)(%x%x)(%x%x)$")
        assert.is_truthy(r, "accent must be #RRGGBB")
        local R, G, B = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
        assert.is_true(G > R and G > B, "accent should be green-dominant")
    end)
end)
