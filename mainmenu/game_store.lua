-- ContentDB game releases are installed side by side. Existing versions are
-- never overwritten, so another Pack's base game cannot change unexpectedly.
local M = {}

function M.compatible(release, version)
    local function compare(a, b)
        local av, bv = {}, {}
        for n in tostring(a):gmatch("%d+") do av[#av + 1] = tonumber(n) end
        for n in tostring(b):gmatch("%d+") do bv[#bv + 1] = tonumber(n) end
        for i = 1, math.max(#av, #bv) do
            if (av[i] or 0) ~= (bv[i] or 0) then return (av[i] or 0) < (bv[i] or 0) and -1 or 1 end
        end
        return 0
    end
    -- ContentDB engine limits are major.minor release families.
    local family = tostring(version):match("^(%d+%.%d+)") or version
    return not (release.min_minetest_version and compare(family, release.min_minetest_version.name) < 0)
        and not (release.max_minetest_version and compare(family, release.max_minetest_version.name) > 0)
end

function M.base_game(game, release)
    if game.installed_id then
        return { id = game.name, installed_id = game.installed_id,
            title = game.title, version = "installed" }
    end
    return { id = game.name, package = game.author .. "/" .. game.name,
        release = release.id, title = game.title,
        version = tostring(release.name or release.title or release.id) }
end

-- This function is serialized into Luanti's worker; it must have no upvalues.
function M.download_worker(params)
    local archive = core.get_temp_path(true)
    local folder = core.get_temp_path()
    if not core.download_file(params.url, archive) then
        os.remove(archive)
        core.delete_dir(folder)
        return { error = "Download failed" }
    end
    local extracted = core.extract_zip(archive, folder)
    os.remove(archive)
    if not extracted then core.delete_dir(folder); return { error = "Invalid game archive" } end
    return { path = folder }
end

function M.new(opts)
    local fs, builder = opts.fs, opts.world_builder
    local self = {}
    function self.ensure(base, release, callback)
        if type(base.id) ~= "string" or not base.id:match("^[%w_%-]+$")
                or (base.installed_id and (type(base.installed_id) ~= "string" or not base.installed_id:match("^[%w_%-]+$")))
                or (not base.installed_id and (type(base.release) ~= "number" or base.release < 1 or base.release % 1 ~= 0)) then
            callback(false, "Invalid game identifier"); return true
        end
        local destination = builder.gamepath_for(base, opts.user_path)
        if destination and fs.exists(destination .. "/game.conf") and fs.exists(destination .. "/mods") then
            callback(true); return true
        end
        if base.installed_id then callback(false, "Installed game is missing"); return true end
        local url = release.url
        if url and url:sub(1, 1) == "/" then url = "https://content.luanti.org" .. url end
        if not url or not url:match("^https://") then callback(false, "Invalid download URL"); return true end
        return core.handle_async(M.download_worker, { url = url }, function(result)
            if not result or result.error then callback(false, result and result.error or "Download failed"); return end
            local root = result.path
            local source = root
            if not fs.exists(source .. "/game.conf") then
                local dirs = core.get_dir_list(root, true) or {}
                if #dirs == 1 then source = root .. "/" .. dirs[1] end
            end
            if not fs.exists(source .. "/game.conf") or not fs.exists(source .. "/mods") then
                fs.delete_dir(root); callback(false, "Invalid game archive"); return
            end
            fs.mkdir(opts.user_path .. "/games")
            -- Re-check after the asynchronous download; another dialog may have
            -- installed the same immutable release while the worker ran.
            if fs.exists(destination) then
                fs.delete_dir(root)
                callback(fs.exists(destination .. "/game.conf") and fs.exists(destination .. "/mods"),
                    "Game destination already exists")
                return
            end
            local staged = destination .. ".installing"
            if fs.exists(staged) then fs.delete_dir(root); callback(false, "Game installation already in progress"); return end
            if not fs.copy_dir(source, staged, true) then
                fs.delete_dir(root); fs.delete_dir(staged); callback(false, "Cannot stage game"); return
            end
            local ok, err = fs.rename(staged, destination)
            fs.delete_dir(root)
            if not ok then fs.delete_dir(staged) end
            callback(ok and true or false, err)
        end)
    end
    return self
end

return M
