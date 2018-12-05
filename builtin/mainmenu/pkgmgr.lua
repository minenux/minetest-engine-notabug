--Minetest
--Copyright (C) 2013 sapier
--
--This program is free software; you can redistribute it and/or modify
--it under the terms of the GNU Lesser General Public License as published by
--the Free Software Foundation; either version 2.1 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Lesser General Public License for more details.
--
--You should have received a copy of the GNU Lesser General Public License along
--with this program; if not, write to the Free Software Foundation, Inc.,
--51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

--------------------------------------------------------------------------------
function get_mods(path,retval,modpack)
	local mods = core.get_dir_list(path, true)

	for _, name in ipairs(mods) do
		if name:sub(1, 1) ~= "." then
			local prefix = path .. DIR_DELIM .. name
			local toadd = {}
			retval[#retval + 1] = toadd

			local mod_conf = Settings(prefix .. "mod.conf"):to_table()
			if mod_conf.name then
				name = mod_conf.name
			end

			toadd.name = name
			toadd.author = mod_conf.author
			toadd.release = tonumber(mod_conf.release or "0")
			toadd.path = prefix
			toadd.type = "mod"

			if modpack ~= nil and modpack ~= "" then
				toadd.modpack = modpack
			else
				local modpackfile = io.open(prefix .. DIR_DELIM .. "modpack.txt")
				if modpackfile then
					modpackfile:close()
					toadd.type = "modpack"
					toadd.is_modpack = true
					get_mods(prefix, retval, name)
				end
			end
		end
	end
end

--modmanager implementation
pkgmgr = {}

function pkgmgr.get_texture_packs()
	local txtpath = core.get_texturepath()
	local list = core.get_dir_list(txtpath, true)
	local retval = {}

	local current_texture_path = core.settings:get("texture_path")

	for _, item in ipairs(list) do
		if item ~= "base" then
			local name = item

			local path = txtpath .. DIR_DELIM .. item .. DIR_DELIM
			if path == current_texture_path then
				name = fgettext("$1 (Enabled)", name)
			end

			local conf = Settings(path .. "texture_pack.conf")

			retval[#retval + 1] = {
				name = item,
				author = conf:get("author"),
				release = tonumber(conf:get("release") or "0"),
				list_name = name,
				type = "txp",
				path = path,
				enabled = path == current_texture_path,
			}
		end
	end

	table.sort(retval, function(a, b)
		return a.name > b.name
	end)

	return retval
end

--------------------------------------------------------------------------------
function pkgmgr.extract(modfile)
	if modfile.type == "zip" then
		local tempfolder = os.tempfolder()

		if tempfolder ~= nil and
			tempfolder ~= "" then
			core.create_dir(tempfolder)
			if core.extract_zip(modfile.name,tempfolder) then
				return tempfolder
			end
		end
	end
	return nil
end

function pkgmgr.get_folder_type(path)
	local testfile = io.open(path .. DIR_DELIM .. "init.lua","r")
	if testfile ~= nil then
		testfile:close()
		return { type = "mod", path = path }
	end

	testfile = io.open(path .. DIR_DELIM .. "modpack.txt","r")
	if testfile ~= nil then
		testfile:close()
		return { type = "modpack", path = path }
	end

	testfile = io.open(path .. DIR_DELIM .. "game.conf","r")
	if testfile ~= nil then
		testfile:close()
		return { type = "game", path = path }
	end

	testfile = io.open(path .. DIR_DELIM .. "texture_pack.conf","r")
	if testfile ~= nil then
		testfile:close()
		return { type = "txp", path = path }
	end

	return nil
end

-------------------------------------------------------------------------------
function pkgmgr.get_base_folder(temppath)
	if temppath == nil then
		return { type = "invalid", path = "" }
	end

	local ret = pkgmgr.get_folder_type(temppath)
	if ret then
		return ret
	end

	local subdirs = core.get_dir_list(temppath, true)
	if #subdirs == 1 then
		ret = pkgmgr.get_folder_type(temppath .. DIR_DELIM .. subdirs[1])
		if ret then
			return ret
		else
			return { type = "invalid", path = temppath .. DIR_DELIM .. subdirs[1] }
		end
	end

	return nil
end

--------------------------------------------------------------------------------
function pkgmgr.get_modpack_path(mod)
	return mod.modpack and "mods." .. mod.modpack or "mods"
end

--------------------------------------------------------------------------------
function pkgmgr.isValidModname(modpath)
	if modpath:find("-") ~= nil then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function pkgmgr.parse_register_line(line)
	local pos1 = line:find("\"")
	local pos2 = nil
	if pos1 ~= nil then
		pos2 = line:find("\"",pos1+1)
	end

	if pos1 ~= nil and pos2 ~= nil then
		local item = line:sub(pos1+1,pos2-1)

		if item ~= nil and
			item ~= "" then
			local pos3 = item:find(":")

			if pos3 ~= nil then
				local retval = item:sub(1,pos3-1)
				if retval ~= nil and
					retval ~= "" then
					return retval
				end
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
function pkgmgr.parse_dofile_line(modpath,line)
	local pos1 = line:find("\"")
	local pos2 = nil
	if pos1 ~= nil then
		pos2 = line:find("\"",pos1+1)
	end

	if pos1 ~= nil and pos2 ~= nil then
		local filename = line:sub(pos1+1,pos2-1)

		if filename ~= nil and
			filename ~= "" and
			filename:find(".lua") then
			return pkgmgr.identify_modname(modpath,filename)
		end
	end
	return nil
end

--------------------------------------------------------------------------------
function pkgmgr.identify_modname(modpath,filename)
	local testfile = io.open(modpath .. DIR_DELIM .. filename,"r")
	if testfile ~= nil then
		local line = testfile:read()

		while line~= nil do
			local modname = nil

			if line:find("minetest.register_tool") then
				modname = pkgmgr.parse_register_line(line)
			end

			if line:find("minetest.register_craftitem") then
				modname = pkgmgr.parse_register_line(line)
			end


			if line:find("minetest.register_node") then
				modname = pkgmgr.parse_register_line(line)
			end

			if line:find("dofile") then
				modname = pkgmgr.parse_dofile_line(modpath,line)
			end

			if modname ~= nil then
				testfile:close()
				return modname
			end

			line = testfile:read()
		end
		testfile:close()
	end

	return nil
end
--------------------------------------------------------------------------------
function pkgmgr.render_packagelist(render_list)
	local retval = ""

	if render_list == nil then
		if pkgmgr.global_mods == nil then
			pkgmgr.refresh_globals()
		end
		render_list = pkgmgr.global_mods
	end

	local list = render_list:get_list()
	local last_modpack = nil
	local retval = {}
	for i, v in ipairs(list) do
		local color = ""
		if v.is_modpack then
			local rawlist = render_list:get_raw_list()
			color = mt_color_dark_green

			for j = 1, #rawlist, 1 do
				if rawlist[j].modpack == list[i].name and
						not rawlist[j].enabled then
					-- Modpack not entirely enabled so showing as grey
					color = mt_color_grey
					break
				end
			end
		elseif v.is_game_content or v.type == "game" then
			color = mt_color_blue
		elseif v.enabled or v.type == "txp" then
			color = mt_color_green
		end

		retval[#retval + 1] = color
		if v.modpack ~= nil or v.loc == "game" then
			retval[#retval + 1] = "1"
		else
			retval[#retval + 1] = "0"
		end
		retval[#retval + 1] = core.formspec_escape(v.list_name or v.name)
	end

	return table.concat(retval, ",")
end

--------------------------------------------------------------------------------
function pkgmgr.get_dependencies(path)
	if path == nil then
		return "", ""
	end

	local info = core.get_content_info(path)
	return table.concat(info.depends or {}, ","), table.concat(info.optional_depends or {}, ",")
end

----------- tests whether all of the mods in the modpack are enabled -----------
function pkgmgr.is_modpack_entirely_enabled(data, name)
	local rawlist = data.list:get_raw_list()
	for j = 1, #rawlist do
		if rawlist[j].modpack == name and not rawlist[j].enabled then
			return false
		end
	end
	return true
end

---------- toggles or en/disables a mod or modpack -----------------------------
function pkgmgr.enable_mod(this, toset)
	local mod = this.data.list:get_list()[this.data.selected_mod]

	-- game mods can't be enabled or disabled
	if mod.is_game_content then
		return
	end

	-- toggle or en/disable the mod
	if not mod.is_modpack then
		if toset == nil then
			toset = not mod.enabled
		end
		-- Disable all other mods with the same name in other paths
		-- and enable this one.
		for i, mod_to_set in ipairs(pkgmgr.mods_by_name[mod.name]) do
			if not mod_to_set.is_game_content then
				mod_to_set.enabled = mod_to_set.modpack == mod.modpack and toset
			end
		end
		return
	end

	-- toggle or en/disable every mod in the modpack, interleaved unsupported
	local list = this.data.list:get_raw_list()
	for i, this_mod in ipairs(list) do
		if not this_mod.is_game_content and this_mod.modpack == mod.name then

			if toset == nil then
				toset = not this_mod.enabled
			end
			-- For each mod in the modpack, disable all mods with the same
			-- name in other paths and enable this one.
			for i, mod_to_set in ipairs(pkgmgr.mods_by_name[this_mod.name]) do
				if not mod_to_set.is_game_content then
					local same_mp = mod_to_set.modpack == this_mod.modpack
					mod_to_set.enabled = same_mp and toset
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
function pkgmgr.get_worldconfig(worldpath)
	local filename = worldpath ..
				DIR_DELIM .. "world.mt"

	local worldfile = Settings(filename)

	local worldconfig = {}
	worldconfig.global_mods = {}
	worldconfig.game_mods = {}

	for key,value in pairs(worldfile:to_table()) do
		if key == "gameid" then
			worldconfig.id = value
		elseif key:sub(0, 9) == "load_mod_" then
			worldconfig.global_mods[key] = value ~= "false" and value ~= "nil"
				and value
		else
			worldconfig[key] = value
		end
	end

	--read gamemods
	local gamespec = pkgmgr.find_by_gameid(worldconfig.id)
	pkgmgr.get_game_mods(gamespec, worldconfig.game_mods)

	return worldconfig
end

--------------------------------------------------------------------------------
function pkgmgr.install_dir(type, path, basename, targetpath)
	local basefolder = pkgmgr.get_base_folder(path)

	-- There's no good way to detect a texture pack, so let's just assume
	-- it's correct for now.
	if type == "txp" then
		if basefolder and basefolder.type ~= "invalid" and basefolder.type ~= "txp" then
			return nil, fgettext("Unable to install a $1 as a texture pack", basefolder.type)
		end

		local from = basefolder and basefolder.path or path
		if targetpath then
			core.delete_dir(targetpath)
			core.create_dir(targetpath)
		else
			targetpath = core.get_texturepath() .. DIR_DELIM .. basename
		end
		if not core.copy_dir(from, targetpath) then
			return nil,
				fgettext("Failed to install $1 to $2", basename, targetpath)
		end
		return targetpath, nil

	elseif not basefolder then
		return nil, fgettext("Unable to find a valid mod or modpack")
	end

	--
	-- Get destination
	--
	if basefolder.type == "modpack" then
		if type ~= "mod" then
			return nil, fgettext("Unable to install a modpack as a $1", type)
		end

		-- Get destination name for modpack
		if targetpath then
			core.delete_dir(targetpath)
			core.create_dir(targetpath)
		else
			local clean_path = nil
			if basename ~= nil then
				clean_path = "mp_" .. basename
			end
			if not clean_path then
				clean_path = get_last_folder(cleanup_path(basefolder.path))
			end
			if clean_path then
				targetpath = core.get_modpath() .. DIR_DELIM .. clean_path
			else
				return nil,
					fgettext("Install Mod: Unable to find suitable folder name for modpack $1",
					modfilename)
			end
		end
	elseif basefolder.type == "mod" then
		if type ~= "mod" then
			return nil, fgettext("Unable to install a mod as a $1", type)
		end

		if targetpath then
			core.delete_dir(targetpath)
			core.create_dir(targetpath)
		else
			local targetfolder = basename
			if targetfolder == nil then
				targetfolder = pkgmgr.identify_modname(basefolder.path, "init.lua")
			end

			-- If heuristic failed try to use current foldername
			if targetfolder == nil then
				targetfolder = get_last_folder(basefolder.path)
			end

			if targetfolder ~= nil and pkgmgr.isValidModname(targetfolder) then
				targetpath = core.get_modpath() .. DIR_DELIM .. targetfolder
			else
				return nil, fgettext("Install Mod: Unable to find real mod name for: $1", modfilename)
			end
		end

	elseif basefolder.type == "game" then
		if type ~= "game" then
			return nil, fgettext("Unable to install a game as a $1", type)
		end

		if targetpath then
			core.delete_dir(targetpath)
			core.create_dir(targetpath)
		else
			targetpath = core.get_gamepath() .. DIR_DELIM .. basename
		end
	end

	-- Copy it
	if not core.copy_dir(basefolder.path, targetpath) then
		return nil,
			fgettext("Failed to install $1 to $2", basename, targetpath)
	end

	pkgmgr.refresh_globals()

	return targetpath, nil
end

--------------------------------------------------------------------------------
function pkgmgr.install(type, modfilename, basename, dest)
	local archive_info = pkgmgr.identify_filetype(modfilename)
	local path = pkgmgr.extract(archive_info)

	if path == nil then
		return nil,
			fgettext("Install: file: \"$1\"", archive_info.name) .. "\n" ..
			fgettext("Install: Unsupported file type \"$1\" or broken archive",
				archive_info.type)
	end

	local targetpath, msg = pkgmgr.install_dir(type, path, basename, dest)
	core.delete_dir(path)
	return targetpath, msg
end

--------------------------------------------------------------------------------
function pkgmgr.preparemodlist(data)
	local retval = {}

	local global_mods = {}
	local game_mods = {}

	--read global mods
	local modpath = core.get_modpath()

	if modpath ~= nil and
		modpath ~= "" then
		get_mods(modpath,global_mods)
	end

	for i=1,#global_mods,1 do
		global_mods[i].type = "mod"
		global_mods[i].loc = "global"
		retval[#retval + 1] = global_mods[i]
	end

	--read game mods
	local gamespec = pkgmgr.find_by_gameid(data.gameid)
	pkgmgr.get_game_mods(gamespec, game_mods)

	if #game_mods > 0 then
		-- Add title
		retval[#retval + 1] = {
			type = "game",
			is_game_content = true,
			name = fgettext(gamespec.name .. " mods"),
			path = gamespec.path
		}
	end

	for i=1,#game_mods,1 do
		game_mods[i].type = "mod"
		game_mods[i].loc = "game"
		game_mods[i].is_game_content = true
		retval[#retval + 1] = game_mods[i]
	end

	if data.worldpath == nil then
		return retval
	end

	--read world mod configuration
	local filename = data.worldpath ..
				DIR_DELIM .. "world.mt"

	local worldfile = Settings(filename)

	pkgmgr.mods_by_name = {}
	-- Note mods_active_by_name tracks only mods with a setting value of "true".
	local mods_active_by_name = {}
	-- missing_configured_mods tracks the mods that have a load_mod_XXX but
	-- aren't found in any folder
	local missing_configured_mods = worldfile:to_table()

	for i, mod in ipairs(retval) do
		if not mod.is_modpack then
			pkgmgr.mods_by_name[mod.name] = pkgmgr.mods_by_name[mod.name] or {}
			table.insert(pkgmgr.mods_by_name[mod.name], mod)
			local key = "load_mod_" .. mod.name
			local value = worldfile:get(key)
			if value then
				local is_true = core.is_yes(value)
				if is_true and mod.typ == "global_mod" then
					mods_active_by_name[mod.name] = mods_active_by_name[mod.name] or {}
					table.insert(mods_active_by_name[mod.name], mod)
				end
				mod.enabled = is_true or value == pkgmgr.get_modpack_path(mod)
				if mod.enabled then
					-- Configured another one.
					missing_configured_mods[key] = nil
				end
			end
		end
	end

	for key, value in pairs(missing_configured_mods) do
		if key:sub(1, 9) == "load_mod_" and value ~= "false" and
				value ~= "nil" then
			core.log("info", "Config says that mod \"" .. key:sub(10)
				.. "\" should be loaded from " .. dump(value)
				.. " but it was not found there")
		end
	end

	for name, conflicting in pairs(mods_active_by_name) do
		-- No conflict if there's just one.
		local nconflicting = #conflicting
		if nconflicting > 1 then
			-- Resolve conflict following the core's algorithm:
			-- 1. If it is in a modpack, disable it.
			for j = nconflicting, 1, -1 do
				if conflicting[j].modpack then
					conflicting[j].enabled = false
					-- Remove element from list in O(1) operations.
					conflicting[j] = conflicting[nconflicting]
					conflicting[nconflicting] = nil
					nconflicting = nconflicting - 1
				end
			end
			-- 2. Disable all in root if more than one.
			if nconflicting > 1 then
				for j = 1, nconflicting do
					conflicting[j].enabled = false
				end
 			end
 		end
 	end

	return retval
end

function pkgmgr.compare_package(a, b)
	return a and b and a.name == b.name and a.path == b.path
end

--------------------------------------------------------------------------------
function pkgmgr.comparemod(elem1,elem2)
	if elem1 == nil or elem2 == nil then
		return false
	end
	if elem1.name ~= elem2.name then
		return false
	end
	if elem1.is_modpack ~= elem2.is_modpack then
		return false
	end
	if elem1.type ~= elem2.type then
		return false
	end
	if elem1.modpack ~= elem2.modpack then
		return false
	end

	if elem1.path ~= elem2.path then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
function pkgmgr.mod_exists(basename)

	if pkgmgr.global_mods == nil then
		pkgmgr.refresh_globals()
	end

	if pkgmgr.global_mods:raw_index_by_uid(basename) > 0 then
		return true
	end

	return false
end

--------------------------------------------------------------------------------
function pkgmgr.get_global_mod(idx)

	if pkgmgr.global_mods == nil then
		return nil
	end

	if idx == nil or idx < 1 or
		idx > pkgmgr.global_mods:size() then
		return nil
	end

	return pkgmgr.global_mods:get_list()[idx]
end

--------------------------------------------------------------------------------
function pkgmgr.refresh_globals()
	local function is_equal(element,uid) --uid match
		if element.name == uid then
			return true
		end
	end
	pkgmgr.global_mods = filterlist.create(pkgmgr.preparemodlist,
			pkgmgr.comparemod, is_equal, nil, {})
	pkgmgr.global_mods:add_sort_mechanism("alphabetic", sort_mod_list)
	pkgmgr.global_mods:set_sortmode("alphabetic")
end

--------------------------------------------------------------------------------
function pkgmgr.identify_filetype(name)

	if name:sub(-3):lower() == "zip" then
		return {
				name = name,
				type = "zip"
				}
	end

	if name:sub(-6):lower() == "tar.gz" or
		name:sub(-3):lower() == "tgz"then
		return {
				name = name,
				type = "tgz"
				}
	end

	if name:sub(-6):lower() == "tar.bz2" then
		return {
				name = name,
				type = "tbz"
				}
	end

	if name:sub(-2):lower() == "7z" then
		return {
				name = name,
				type = "7z"
				}
	end

	return {
		name = name,
		type = "ukn"
	}
end


--------------------------------------------------------------------------------
function pkgmgr.find_by_gameid(gameid)
	for i=1,#pkgmgr.games,1 do
		if pkgmgr.games[i].id == gameid then
			return pkgmgr.games[i], i
		end
	end
	return nil, nil
end

--------------------------------------------------------------------------------
function pkgmgr.get_game_mods(gamespec, retval)
	if gamespec ~= nil and
		gamespec.gamemods_path ~= nil and
		gamespec.gamemods_path ~= "" then
		get_mods(gamespec.gamemods_path, retval)
	end
end

--------------------------------------------------------------------------------
function pkgmgr.get_game_modlist(gamespec)
	local retval = ""
	local game_mods = {}
	pkgmgr.get_game_mods(gamespec, game_mods)
	for i=1,#game_mods,1 do
		if retval ~= "" then
			retval = retval..","
		end
		retval = retval .. game_mods[i].name
	end
	return retval
end

--------------------------------------------------------------------------------
function pkgmgr.get_game(index)
	if index > 0 and index <= #pkgmgr.games then
		return pkgmgr.games[index]
	end

	return nil
end

--------------------------------------------------------------------------------
function pkgmgr.update_gamelist()
	pkgmgr.games = core.get_games()
end

--------------------------------------------------------------------------------
function pkgmgr.gamelist()
	local retval = ""
	if #pkgmgr.games > 0 then
		retval = retval .. core.formspec_escape(pkgmgr.games[1].name)

		for i=2,#pkgmgr.games,1 do
			retval = retval .. "," .. core.formspec_escape(pkgmgr.games[i].name)
		end
	end
	return retval
end

--------------------------------------------------------------------------------
-- read initial data
--------------------------------------------------------------------------------
pkgmgr.update_gamelist()
