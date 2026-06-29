-- scripts/bgimg_emit.lua: テーマ設定 YAML を読んで <outdir>/<name>.svg を出力する。
-- Usage: lua scripts/bgimg_emit.lua <theme.bgimg.yml> <outdir>
-- 後段の build_bgimg.sh が rsvg-convert で PNG に raster 化する。

if not arg or not arg[1] or not arg[2] then
    io.stderr:write("usage: lua scripts/bgimg_emit.lua <yaml> <outdir>\n")
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

local function svg_open(w, h)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n' ..
            '<svg xmlns="http://www.w3.org/2000/svg" ' ..
            'viewBox="0 0 %d %d" width="%d" height="%d">\n'):format(w, h, w, h)
end

local function emit_gradient_svg(w, h, stops)
    local parts = { svg_open(w, h) }
    parts[#parts + 1] = '<defs>\n'
    parts[#parts + 1] = '<linearGradient id="g" x1="0" y1="0" x2="0" y2="1">\n'
    for _, s in ipairs(stops) do
        parts[#parts + 1] = ('<stop offset="%g" stop-color="%s"/>\n'):format(s.pos, s.color)
    end
    parts[#parts + 1] = '</linearGradient>\n</defs>\n'
    parts[#parts + 1] = ('<rect width="%d" height="%d" fill="url(#g)"/>\n'):format(w, h)
    parts[#parts + 1] = '</svg>\n'
    return table.concat(parts)
end

local function emit_grid_svg(w, h, cfg)
    local vx = (cfg.vanishing_point and cfg.vanishing_point.x or 0.5) * w
    local vy = (cfg.vanishing_point and cfg.vanishing_point.y or 0.0) * h
    local cols = cfg.cols or 24
    local rows = cfg.rows or 12
    local lc = cfg.line_color or "#ffffff"
    local ac = cfg.alt_color  or lc
    local parts = { svg_open(w, h) }
    -- フェードマスク: 上部 (vanishing point 側) は透明、下に向かって不透明に
    parts[#parts + 1] = '<defs>\n'
    parts[#parts + 1] = '<linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">\n'
    parts[#parts + 1] = '<stop offset="0" stop-color="white" stop-opacity="0"/>\n'
    parts[#parts + 1] = '<stop offset="1" stop-color="white" stop-opacity="1"/>\n'
    parts[#parts + 1] = '</linearGradient>\n'
    parts[#parts + 1] = ('<mask id="m"><rect width="%d" height="%d" fill="url(#fade)"/></mask>\n'):format(w, h)
    parts[#parts + 1] = '</defs>\n'
    parts[#parts + 1] = '<g mask="url(#m)">\n'
    -- 垂直線 (vanishing point から下辺の cols+1 等分点へ)
    for i = 0, cols do
        local x_end = (i / cols) * w
        parts[#parts + 1] = ('<line x1="%g" y1="%g" x2="%g" y2="%d" stroke="%s" stroke-width="2"/>\n'):format(
            vx, vy, x_end, h, lc)
    end
    -- 水平線 (行 = rows + 1 本)
    for i = 1, rows do
        local y = (i / rows) * h
        parts[#parts + 1] = ('<line x1="0" y1="%g" x2="%d" y2="%g" stroke="%s" stroke-width="2"/>\n'):format(
            y, w, y, ac)
    end
    parts[#parts + 1] = '</g>\n</svg>\n'
    return table.concat(parts)
end

local data = yaml.parse(read_file(YAML_PATH))
if not data or not data.output then
    error("bgimg_emit: yaml missing 'output' section")
end

local count = 0
for kind, conf in pairs(data.output) do
    local w = assert(conf.w, "output." .. kind .. ".w missing")
    local h = assert(conf.h, "output." .. kind .. ".h missing")
    local name = assert(conf.name, "output." .. kind .. ".name missing")
    local svg
    if kind == "bg" then
        if not data.gradient then error("bgimg_emit: gradient section missing for kind=bg") end
        svg = emit_gradient_svg(w, h, data.gradient.stops)
    elseif kind == "grid" then
        if not data.grid then error("bgimg_emit: grid section missing for kind=grid") end
        svg = emit_grid_svg(w, h, data.grid)
    else
        error("bgimg_emit: unknown output kind: " .. tostring(kind))
    end
    write_file(OUT_DIR .. "/" .. name .. ".svg", svg)
    count = count + 1
end
io.stdout:write(("bgimg_emit: %d SVG written to %s\n"):format(count, OUT_DIR))
