#!/usr/bin/env lua
-- run_capture.lua
-- Discovers MineClonia mods, loads them via mock API, outputs JSON data
--
-- Usage: lua scripts/run_capture.lua [mineclonia_dir] [output_file]
-- Defaults: mineclonia_dir=./mineclonia, output_file=./scripts/output.json

local MINECLONIA_DIR = arg[1] or "./mineclonia"
local OUTPUT_FILE = arg[2] or "./scripts/output.json"

-- Load the mock API
local mock = dofile("./scripts/mock_api.lua")
mock._mod_paths = {}

-- ============================================================================
-- Utility: Parse mod.conf
-- ============================================================================

local function parse_modconf(path)
    local conf = {}
    local f = io.open(path, "r")
    if not f then return nil end
    for line in f:lines() do
        local key, val = line:match("^%s*(%S+)%s*=%s*(.-)%s*$")
        if key and val then
            conf[key] = val
        end
    end
    f:close()
    return conf
end

-- ============================================================================
-- Utility: Parse game.conf
-- ============================================================================

local function parse_gameconf(path)
    return parse_modconf(path) or {}
end

-- ============================================================================
-- Discover all mods
-- ============================================================================

local function discover_mods(base_dir)
    local mods = {}
    local modpacks = {}

    -- Scan for modpack directories (COMPAT, CORE, ITEMS, etc.)
    local handle = io.popen('ls -1 "' .. base_dir .. '/mods/" 2>/dev/null')
    if not handle then return {}, {} end

    for entry in handle:lines() do
        local full_path = base_dir .. "/mods/" .. entry
        -- Check if it's a directory with modpack.conf
        local mp_conf = parse_modconf(full_path .. "/modpack.conf")
        if mp_conf then
            modpacks[entry] = { path = full_path, conf = mp_conf }
            -- Scan mods inside this modpack
            local sub_handle = io.popen('ls -1 "' .. full_path .. '/" 2>/dev/null')
            if sub_handle then
                for sub_entry in sub_handle:lines() do
                    local sub_path = full_path .. "/" .. sub_entry
                    local mod_conf = parse_modconf(sub_path .. "/mod.conf")
                    if mod_conf and mod_conf.name then
                        mod_conf._path = sub_path
                        mod_conf._modpack = entry
                        mods[mod_conf.name] = mod_conf
                        mock._mod_paths[mod_conf.name] = sub_path
                    end
                end
                sub_handle:close()
            end
        else
            -- Check if it's a standalone mod
            local mod_conf = parse_modconf(full_path .. "/mod.conf")
            if mod_conf and mod_conf.name then
                mod_conf._path = full_path
                mods[mod_conf.name] = mod_conf
                mock._mod_paths[mod_conf.name] = full_path
            end
        end
    end
    handle:close()

    return mods, modpacks
end

-- ============================================================================
-- Topological sort for mod dependencies
-- ============================================================================

local function topo_sort(mods, first_mod, last_mod)
    local sorted = {}
    local visited = {}
    local visiting = {} -- cycle detection

    local function visit(name)
        if visited[name] then return end
        if visiting[name] then
            -- Circular dependency, just skip
            io.stderr:write("WARN: circular dependency detected for mod: " .. name .. "\n")
            return
        end

        local mod = mods[name]
        if not mod then return end -- external dependency, skip

        visiting[name] = true

        -- Parse dependencies
        local deps_str = mod.depends or ""
        for raw_dep in deps_str:gmatch("[^,]+") do
            local dep = raw_dep:match("^%s*(.-)%s*$") -- trim
            if dep and dep ~= "" then
                visit(dep)
            end
        end

        visiting[name] = nil
        visited[name] = true
        sorted[#sorted + 1] = name
    end

    -- Handle first_mod: force it first
    if first_mod and mods[first_mod] then
        visit(first_mod)
    end

    -- Visit all remaining mods
    for name, _ in pairs(mods) do
        visit(name)
    end

    -- Handle last_mod: force it last
    if last_mod and mods[last_mod] then
        -- Remove from sorted if already there
        for i, name in ipairs(sorted) do
            if name == last_mod then
                table.remove(sorted, i)
                break
            end
        end
        sorted[#sorted + 1] = last_mod
    end

    return sorted
end

-- ============================================================================
-- Load a single mod
-- ============================================================================

local function load_mod(mod_conf)
    local name = mod_conf.name
    local path = mod_conf._path
    local init_path = path .. "/init.lua"

    -- Check if init.lua exists
    local f = io.open(init_path, "r")
    if not f then
        io.stderr:write("SKIP: " .. name .. " (no init.lua)\n")
        return
    end
    f:close()

    io.stderr:write("LOAD: " .. name .. " (" .. init_path .. ")\n")
    mock.set_current_mod(name)

    -- Load the mod
    local ok, err = pcall(dofile, init_path)
    if not ok then
        mock.log_error(name, tostring(err))
        io.stderr:write("  ERROR: " .. tostring(err) .. "\n")
    else
        mock.mark_mod_loaded(name)
    end
end

-- ============================================================================
-- Main
-- ============================================================================

io.stderr:write("=== MineClonia Wiki Data Capture ===\n")
io.stderr:write("Source: " .. MINECLONIA_DIR .. "\n")
io.stderr:write("Output: " .. OUTPUT_FILE .. "\n\n")

-- Parse game.conf
local game_conf = parse_gameconf(MINECLONIA_DIR .. "/game.conf")
io.stderr:write("Game: " .. (game_conf.title or "Unknown") .. "\n")
io.stderr:write("first_mod: " .. (game_conf.first_mod or "none") .. "\n")
io.stderr:write("last_mod: " .. (game_conf.last_mod or "none") .. "\n\n")

-- Discover mods
local mods, modpacks = discover_mods(MINECLONIA_DIR)

local mod_count = 0
for _ in pairs(mods) do mod_count = mod_count + 1 end
local mp_count = 0
for _ in pairs(modpacks) do mp_count = mp_count + 1 end

io.stderr:write("Found " .. mod_count .. " mods in " .. mp_count .. " modpacks\n\n")

-- Sort mods by dependency order
local sorted = topo_sort(mods, game_conf.first_mod, game_conf.last_mod)
io.stderr:write("Load order: " .. #sorted .. " mods\n\n")

-- Load all mods
for _, name in ipairs(sorted) do
    load_mod(mods[name])
end

-- ============================================================================
-- Post-processing: extract mob data from entities
-- ============================================================================

for name, def in pairs(mock.captured.entities) do
    if def.type == "animal" or def.type == "monster" or def.type == "npc" then
        mock.captured.mobs[name] = {
            description = def.description,
            type = def.type,
            hp_min = def.hp_min,
            hp_max = def.hp_max,
            drops = def.drops,
            follow = def.follow,
            _source_mod = def._source_mod,
        }
    end
end

-- ============================================================================
-- Output statistics
-- ============================================================================

local node_count = 0
for _ in pairs(mock.captured.nodes) do node_count = node_count + 1 end
local craftitem_count = 0
for _ in pairs(mock.captured.craftitems) do craftitem_count = craftitem_count + 1 end
local tool_count = 0
for _ in pairs(mock.captured.tools) do tool_count = tool_count + 1 end
local entity_count = 0
for _ in pairs(mock.captured.entities) do entity_count = entity_count + 1 end
local mob_count = 0
for _ in pairs(mock.captured.mobs) do mob_count = mob_count + 1 end

io.stderr:write("\n=== Results ===\n")
io.stderr:write("Nodes:      " .. node_count .. "\n")
io.stderr:write("Craftitems: " .. craftitem_count .. "\n")
io.stderr:write("Tools:      " .. tool_count .. "\n")
io.stderr:write("Entities:   " .. entity_count .. "\n")
io.stderr:write("Mobs:       " .. mob_count .. "\n")
io.stderr:write("Crafts:     " .. #mock.captured.crafts .. "\n")
io.stderr:write("Aliases:    " .. #mock.captured.aliases .. "\n")
io.stderr:write("Biomes:     " .. #mock.captured.biomes .. "\n")
io.stderr:write("Errors:     " .. #mock.captured.errors .. "\n")

-- ============================================================================
-- Write JSON output
-- ============================================================================

io.stderr:write("\nWriting JSON to " .. OUTPUT_FILE .. "...\n")

local out = io.open(OUTPUT_FILE, "w")
if not out then
    io.stderr:write("ERROR: Cannot open output file: " .. OUTPUT_FILE .. "\n")
    os.exit(1)
end

out:write(mock.to_json(mock.captured))
out:close()

io.stderr:write("Done!\n")
