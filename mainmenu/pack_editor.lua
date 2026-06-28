-- 既存 Pack の編集(Phase 10)。
-- - Mod の追加・削除(ContentDB から検索 → 追加)
-- - メタ情報(name / version / description)の更新
-- いずれも対象は <pack_root>/manifest.yaml への書き戻し。

local M = {}

local function default_write(path, text)
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(text)
    f:close()
    return true
end

local function resolve_manifest_mod(opts)
    if opts and opts.manifest_mod then return opts.manifest_mod end
    local pm = rawget(_G, "packermod")
    if pm and pm.manifest then return pm.manifest end
    return require("mainmenu.manifest")
end

local function save_manifest(pack, opts)
    opts = opts or {}
    local manifest_mod = resolve_manifest_mod(opts)
    local ok, dumped = manifest_mod.dump(pack.manifest)
    if not ok then return false, dumped end
    local writer = opts.write_file or default_write
    return writer(pack.path .. "/manifest.yaml", dumped)
end

function M.add_mod(pack, mod_spec, opts)
    pack.manifest.mods = pack.manifest.mods or {}
    for _, existing in ipairs(pack.manifest.mods) do
        if existing.name == mod_spec.name then
            return false, "duplicate mod name: " .. mod_spec.name
        end
    end
    table.insert(pack.manifest.mods, mod_spec)
    return save_manifest(pack, opts)
end

function M.remove_mod(pack, index, opts)
    if not pack.manifest.mods or index < 1 or index > #pack.manifest.mods then
        return false, "index out of range"
    end
    table.remove(pack.manifest.mods, index)
    return save_manifest(pack, opts)
end

-- name / version / description を更新。空文字列は (description は nil 化、
-- 必須項目 name/version は無視) として扱う。
function M.update_meta(pack, fields, opts)
    if fields.name and fields.name ~= "" then pack.manifest.name = fields.name end
    if fields.version and fields.version ~= "" then pack.manifest.version = fields.version end
    if fields.description ~= nil then
        if fields.description == "" then pack.manifest.description = nil
        else pack.manifest.description = fields.description end
    end
    return save_manifest(pack, opts)
end

-- ContentDB の検索結果 1 件 → manifest 用 mod entry。
function M.contentdb_result_to_mod(result, release_id)
    return {
        name = result.name,
        source = "contentdb",
        package = result.author .. "/" .. result.name,
        release = release_id,
    }
end

return M
