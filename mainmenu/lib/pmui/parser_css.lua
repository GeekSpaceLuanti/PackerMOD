-- pmui.parser_css: YAML を読んで pmui.stylesheet.Stylesheet に変換する。
-- yaml.lua のキーパターンは [%w_%-]+ しか許さないので、selector はクォート key で
-- なく、rules を array にして各 rule に `selector:` フィールドを持たせる形を採る。
--
-- 形式:
--   variables:
--     --fg: "#fff"
--     --space-md: 0.4
--   rules:
--     - selector: ".pack-card"
--       style:
--         bg: "var(--card-bg)"
--         border-width: 1
--     - selector: ".pack-card:hover"
--       style: { border-color: "var(--accent-pink)" }
--   media:
--     - query: "min-width 13.0"
--       rules:
--         - selector: ".card-grid"
--           style: { grid-columns: 3 }

local SELF_DIR = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
local stylesheet = dofile(SELF_DIR .. "stylesheet.lua")

local M = {}

local function get_yaml()
    if rawget(_G, "packermod") and packermod.yaml then return packermod.yaml end
    local ok, mod = pcall(dofile, "mainmenu/yaml.lua")
    if ok then return mod end
    error("pmui.parser_css: yaml.lua not found")
end

local function parse_media_query(text)
    -- "min-width 13.0" / "max-width 10.0"
    local kind, num = text:match("^(%S+)%s+([%d.]+)$")
    if not kind then return { type = "unknown", value = text } end
    return { type = kind, value = tonumber(num) }
end

local function compile_rule(raw)
    if type(raw) ~= "table" or not raw.selector then
        error("pmui.parser_css: rule missing 'selector'")
    end
    local sel = stylesheet.parse_selector(raw.selector)
    local decls = {}
    if type(raw.style) == "table" then
        for prop, val in pairs(raw.style) do
            decls[prop] = stylesheet.parse_value(val)
        end
    end
    return { selectors = { sel }, declarations = decls, source_selector = raw.selector }
end

local function compile_rules(list)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, raw in ipairs(list) do
        out[#out + 1] = compile_rule(raw)
    end
    return out
end

function M.parse(yaml_text)
    local yaml = get_yaml()
    local data = yaml.parse(yaml_text) or {}
    local sheet = stylesheet.new()

    if type(data.variables) == "table" then
        for name, val in pairs(data.variables) do
            sheet.vars[name] = stylesheet.parse_value(val)
        end
    end

    sheet.rules = compile_rules(data.rules)

    if type(data.media) == "table" then
        for _, m in ipairs(data.media) do
            sheet.media[#sheet.media + 1] = {
                query = parse_media_query(m.query or ""),
                rules = compile_rules(m.rules),
            }
        end
    end

    return sheet
end

function M.load(path)
    local f, err = io.open(path, "r")
    if not f then error("pmui.parser_css: cannot open " .. tostring(path) .. ": " .. tostring(err)) end
    local text = f:read("*a"); f:close()
    return M.parse(text)
end

return M
