-- scripts/thumb_emit.lua: テーマ用 default thumbnail YAML を読んで <outdir>/<name>.svg を出力。
-- Usage: lua scripts/thumb_emit.lua <theme.thumb.yml> <outdir>
-- 後段の build_thumb.sh が rsvg-convert で PNG にラスタライズする。

if not arg or not arg[1] or not arg[2] then
    io.stderr:write("usage: lua scripts/thumb_emit.lua <yaml> <outdir>\n")
    os.exit(1)
end

local YAML_PATH = arg[1]
local OUT_DIR   = arg[2]

local function read_file(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local s = f:read("*a"); f:close()
    return s
end

local function write_file(path, text)
    local f = assert(io.open(path, "w"), "cannot write " .. path)
    f:write(text); f:close()
end

local yaml = dofile("mainmenu/yaml.lua")

local function emit_thumb_svg(w, h, bg, shapes)
    -- 16x16 dot grid 上の rect を並べて pixel-art を作る。
    -- shape-rendering="crispEdges" でアンチエイリアスを切ってドット感を維持。
    local parts = {
        '<?xml version="1.0" encoding="UTF-8"?>',
        ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" '
          .. 'width="%d" height="%d" shape-rendering="crispEdges">'):format(w, h),
        ('<rect width="16" height="16" fill="%s"/>'):format(bg),
    }
    for _, s in ipairs(shapes or {}) do
        parts[#parts + 1] = ('<rect x="%g" y="%g" width="%g" height="%g" fill="%s" opacity="%g"/>'):format(
            s.x, s.y, s.w, s.h, s.color, s.opacity or 1.0)
    end
    parts[#parts + 1] = '</svg>'
    return table.concat(parts, "\n")
end

local data = yaml.parse(read_file(YAML_PATH))
if not data or not data.output then
    error("thumb_emit: yaml missing 'output' section")
end

local count = 0
for kind, conf in pairs(data.output) do
    local w = assert(conf.w, "output." .. kind .. ".w missing")
    local h = assert(conf.h, "output." .. kind .. ".h missing")
    local name = assert(conf.name, "output." .. kind .. ".name missing")
    local svg = emit_thumb_svg(w, h, data.bg or "#000000", data.shapes)
    write_file(OUT_DIR .. "/" .. name .. ".svg", svg)
    count = count + 1
end
io.stdout:write(("thumb_emit: %d SVG written to %s\n"):format(count, OUT_DIR))
