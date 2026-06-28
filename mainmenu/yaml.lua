local M = {}

local function rtrim(s)
    return (s:gsub("%s+$", ""))
end

local function indent_of(line)
    return #(line:match("^( *)") or "")
end

local function strip_comment(line)
    local in_single, in_double = false, false
    for i = 1, #line do
        local c = line:sub(i, i)
        if c == "'" and not in_double then in_single = not in_single
        elseif c == '"' and not in_single then in_double = not in_double
        elseif c == "#" and not in_single and not in_double then
            return rtrim(line:sub(1, i - 1))
        end
    end
    return rtrim(line)
end

local function parse_scalar(s)
    s = s:match("^%s*(.-)%s*$")
    if s == "" or s == "~" or s == "null" then return nil end
    if s == "true" then return true end
    if s == "false" then return false end
    local q = s:match("^\"(.*)\"$") or s:match("^'(.*)'$")
    if q then return q end
    local n = tonumber(s)
    if n then return n end
    return s
end

local function read_block_scalar(lines, i, base_indent)
    local parts, j = {}, i + 1
    while j <= #lines do
        local line = lines[j]
        if line:match("^%s*$") then
            table.insert(parts, "")
            j = j + 1
        elseif indent_of(line) > base_indent then
            table.insert(parts, line:sub(base_indent + 3))
            j = j + 1
        else
            break
        end
    end
    return table.concat(parts, "\n"), j - 1
end

local parse_lines

local function parse_value_after_key(lines, i, value_str, key_indent)
    if value_str == "|" or value_str == "|-" or value_str == ">" then
        local text, last = read_block_scalar(lines, i, key_indent)
        if value_str == "|-" then text = text:gsub("\n+$", "") end
        return text, last
    end
    if value_str ~= "" then
        return parse_scalar(value_str), i
    end
    local j = i + 1
    while j <= #lines and lines[j]:match("^%s*$") do j = j + 1 end
    if j > #lines or indent_of(lines[j]) <= key_indent then
        return nil, i
    end
    local child_indent = indent_of(lines[j])
    local child_lines = {}
    local last = i
    while j <= #lines do
        local line = lines[j]
        if line:match("^%s*$") then
            table.insert(child_lines, line)
            last = j
            j = j + 1
        elseif indent_of(line) >= child_indent then
            table.insert(child_lines, line)
            last = j
            j = j + 1
        else
            break
        end
    end
    return parse_lines(child_lines, child_indent), last
end

parse_lines = function(lines, base_indent)
    local result
    local i = 1
    while i <= #lines do
        local line = lines[i]
        if line:match("^%s*$") then
            i = i + 1
        else
            local ind = indent_of(line)
            if ind ~= base_indent then
                error(("yaml: inconsistent indent at line %d (expected %d, got %d): %q"):format(i, base_indent, ind, line))
            end
            local body = line:sub(ind + 1)
            if body:sub(1, 2) == "- " or body == "-" then
                result = result or {}
                local item_body = body == "-" and "" or body:sub(3)
                local key, val = item_body:match("^([%w_%-]+):%s*(.*)$")
                if key then
                    local map = {}
                    local parsed_val, consumed = parse_value_after_key(lines, i, val, ind + 2)
                    map[key] = parsed_val
                    i = consumed + 1
                    while i <= #lines do
                        local nline = lines[i]
                        if nline:match("^%s*$") then
                            i = i + 1
                        elseif indent_of(nline) == ind + 2 and not nline:match("^%s*%-") then
                            local nbody = nline:sub(ind + 3)
                            local nkey, nval = nbody:match("^([%w_%-]+):%s*(.*)$")
                            if not nkey then break end
                            local nparsed, nconsumed = parse_value_after_key(lines, i, nval, ind + 2)
                            map[nkey] = nparsed
                            i = nconsumed + 1
                        else
                            break
                        end
                    end
                    table.insert(result, map)
                else
                    local val, consumed = parse_value_after_key(lines, i, item_body, ind + 2)
                    table.insert(result, val)
                    i = consumed + 1
                end
            else
                result = result or {}
                local key, val = body:match("^([%w_%-]+):%s*(.*)$")
                if not key then
                    error(("yaml: cannot parse line %d: %q"):format(i, line))
                end
                local parsed, consumed = parse_value_after_key(lines, i, val, ind)
                result[key] = parsed
                i = consumed + 1
            end
        end
    end
    return result
end

function M.parse(text)
    local raw_lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(raw_lines, strip_comment(line))
    end
    return parse_lines(raw_lines, 0)
end

local dump_value

local function is_array(t)
    if type(t) ~= "table" then return false end
    local n = 0
    for k in pairs(t) do
        n = n + 1
        if type(k) ~= "number" then return false end
    end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return n > 0
end

local function needs_quote(s)
    if s == "" then return true end
    if s:match("[:#\n]") then return true end
    if s == "true" or s == "false" or s == "null" or s == "~" then return true end
    if tonumber(s) then return true end
    return false
end

local function dump_scalar(v)
    if v == nil then return "null" end
    if v == true then return "true" end
    if v == false then return "false" end
    if type(v) == "number" then return tostring(v) end
    local s = tostring(v)
    if s:find("\n") then
        local out = { "|" }
        for line in (s .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(out, line)
        end
        return table.concat(out, "\n  ")
    end
    if needs_quote(s) then
        return '"' .. s:gsub('"', '\\"') .. '"'
    end
    return s
end

dump_value = function(v, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    if type(v) ~= "table" then
        return dump_scalar(v)
    end
    if is_array(v) then
        local parts = {}
        for _, item in ipairs(v) do
            if type(item) == "table" then
                local first = true
                for k, val in pairs(item) do
                    local prefix = first and (pad .. "- ") or (pad .. "  ")
                    if type(val) == "table" then
                        table.insert(parts, prefix .. k .. ":\n" .. dump_value(val, indent + 2))
                    else
                        table.insert(parts, prefix .. k .. ": " .. dump_scalar(val))
                    end
                    first = false
                end
            else
                table.insert(parts, pad .. "- " .. dump_scalar(item))
            end
        end
        return table.concat(parts, "\n")
    end
    local parts = {}
    for k, val in pairs(v) do
        if type(val) == "table" then
            table.insert(parts, pad .. k .. ":\n" .. dump_value(val, indent + 1))
        else
            table.insert(parts, pad .. k .. ": " .. dump_scalar(val))
        end
    end
    return table.concat(parts, "\n")
end

function M.dump(value)
    return dump_value(value, 0) .. "\n"
end

return M
