-- mock_api.lua
-- Mock Minetest/Luanti API for capturing item/recipe registrations
-- Loads MineClonia mods and extracts all registration data as structured tables

local M = {}

-- ============================================================================
-- Captured data tables
-- ============================================================================

M.captured = {
    nodes = {},
    craftitems = {},
    tools = {},
    entities = {},
    crafts = {},
    aliases = {},
    biomes = {},
    decorations = {},
    ores = {},
    overrides = {},
    mobs = {},
    callbacks = { abms = {}, lbms = {} },
    errors = {},
    mods_loaded = {},
}

-- ============================================================================
-- Current mod tracking
-- ============================================================================

local current_mod = "unknown"

-- ============================================================================
-- JSON serializer (minimal, handles MineClonia data types)
-- ============================================================================

local function escape_json(s)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

local function to_json(val, seen)
    local t = type(val)
    if val == nil then return "null" end
    if t == "boolean" then return val and "true" or "false" end
    if t == "number" then
        if val ~= val then return "null" end  -- NaN
        if val == math.huge then return "null" end
        return tostring(val)
    end
    if t == "string" then return '"' .. escape_json(val) .. '"' end
    if t == "function" then return '"[function]"' end
    if t == "userdata" then return '"[userdata]"' end

    seen = seen or {}
    if seen[val] then return '"[circular]"' end
    seen[val] = true

    if t == "table" then
        -- Check if array (consecutive integer keys from 1)
        local is_array = true
        local max_i = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                is_array = false
                break
            end
            if k > max_i then max_i = k end
        end

        local parts = {}
        if is_array and max_i > 0 then
            for i = 1, max_i do
                parts[i] = to_json(val[i], seen)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            -- Check if empty
            if next(val) == nil then return "{}" end
            for k, v in pairs(val) do
                if type(k) == "string" then
                    parts[#parts + 1] = '"' .. escape_json(k) .. '":' .. to_json(v, seen)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end

    return '"[unknown]"'
end

function M.to_json(val)
    return to_json(val, {})
end

-- ============================================================================
-- Mock: Settings
-- ============================================================================

local mock_settings = {}

function mock_settings:get(key)
    return nil
end

function mock_settings:get_bool(key, default)
    if default ~= nil then return default end
    return false
end

function mock_settings:get_flags(key)
    return {}
end

function mock_settings:set_bool(key, value)
    -- no-op
end

function mock_settings:set(key, value)
    -- no-op
end

-- ============================================================================
-- Mock: Mod storage
-- ============================================================================

local function make_mod_storage()
    local data = {}
    local storage = {}

    function storage:get_string(key)
        return data[key] or ""
    end

    function storage:set_string(key, value)
        data[key] = value
    end

    function storage:get_int(key)
        return tonumber(data[key]) or 0
    end

    function storage:get(key)
        return data[key]
    end

    return storage
end

-- ============================================================================
-- Mock: Translator
-- ============================================================================

local function make_translator(domain)
    return function(s, ...)
        -- If there are format args, apply them
        local args = {...}
        if #args > 0 then
            -- Simple %s/%d substitution
            local i = 0
            local result = s:gsub("%%[sd]", function()
                i = i + 1
                return tostring(args[i] or "")
            end)
            return result
        end
        return s
    end
end

-- ============================================================================
-- Mock: Registration functions (these capture the data)
-- ============================================================================

local function register_node(name, def)
    def._source_mod = current_mod
    M.captured.nodes[name] = def
    -- Also add to registered_items
    core.registered_items[name] = def
    core.registered_nodes[name] = def
end

local function register_craftitem(name, def)
    def._source_mod = current_mod
    M.captured.craftitems[name] = def
    core.registered_items[name] = def
end

local function register_tool(name, def)
    def._source_mod = current_mod
    M.captured.tools[name] = def
    core.registered_items[name] = def
    core.registered_tools[name] = def
end

local function register_craft(recipe)
    recipe._source_mod = current_mod
    M.captured.crafts[#M.captured.crafts + 1] = recipe
end

local function register_entity(name, def)
    def._source_mod = current_mod
    M.captured.entities[name] = def
end

local function register_alias(alias, target)
    M.captured.aliases[alias] = target
end

local function register_biome(def)
    M.captured.biomes[#M.captured.biomes + 1] = def
    core.registered_biomes[def.name] = def
end

local function register_decoration(def)
    M.captured.decorations[#M.captured.decorations + 1] = def
end

local function register_ore(def)
    M.captured.ores[#M.captured.ores + 1] = def
end

local function override_item(name, override)
    -- Merge override into existing registration
    local existing = core.registered_nodes[name] or core.registered_items[name]
    if existing then
        for k, v in pairs(override) do
            existing[k] = v
        end
    end
    M.captured.overrides[#M.captured.overrides + 1] = { name = name, override = override }
end

-- ============================================================================
-- Mock: Callback registration (store but don't execute)
-- ============================================================================

local function noop() end

local function make_callback_reg(name)
    return function(func)
        -- Just store the callback registration, don't execute
    end
end

-- ============================================================================
-- Mock: Core object (the main `core` / `minetest` global)
-- ============================================================================

core = {
    -- Engine constants
    MAP_BLOCKSIZE = 16,
    MAX_MAP_GENERATION_LIMIT = 31000,

    -- Default definition tables (can be modified by mods)
    nodedef_default = { stack_max = 99 },
    craftitemdef_default = { stack_max = 99 },

    -- Lookup tables (populated by registration functions)
    registered_nodes = {},
    registered_items = {},
    registered_tools = {},
    registered_biomes = {},
    registered_chatcommands = {},
    registered_aliases = {},

    -- Registration functions
    register_node = register_node,
    register_craftitem = register_craftitem,
    register_tool = register_tool,
    register_craft = register_craft,
    register_entity = register_entity,
    register_alias = register_alias,
    register_biome = register_biome,
    register_decoration = register_decoration,
    register_ore = register_ore,
    override_item = override_item,

    -- Callback registration (all no-op)
    register_on_mods_loaded = make_callback_reg("on_mods_loaded"),
    register_on_joinplayer = make_callback_reg("on_joinplayer"),
    register_on_leaveplayer = make_callback_reg("on_leaveplayer"),
    register_on_dieplayer = make_callback_reg("on_dieplayer"),
    register_on_respawnplayer = make_callback_reg("on_respawnplayer"),
    register_on_player_hpchange = make_callback_reg("on_player_hpchange"),
    register_on_punchplayer = make_callback_reg("on_punchplayer"),
    register_on_placenode = make_callback_reg("on_placenode"),
    register_on_dignode = make_callback_reg("on_dignode"),
    register_on_item_pickup = make_callback_reg("on_item_pickup"),
    register_on_craft = make_callback_reg("on_craft"),
    register_craft_predict = make_callback_reg("craft_predict"),
    register_on_protection_violation = make_callback_reg("on_protection_violation"),
    register_on_chat_message = make_callback_reg("on_chat_message"),
    register_globalstep = make_callback_reg("globalstep"),
    register_abm = function(def) M.captured.callbacks.abms[#M.captured.callbacks.abms + 1] = def end,
    register_lbm = function(def) M.captured.callbacks.lbms[#M.captured.callbacks.lbms + 1] = def end,
    register_chatcommand = function(name, def) core.registered_chatcommands[name] = def end,
    register_privilege = noop,
    register_mapgen_script = noop,
    register_async_dofile = noop,

    -- Metadata / identity
    get_current_modname = function() return current_mod end,
    get_modpath = function(modname)
        -- Return the actual path to the mod
        return M._mod_paths[modname]
    end,
    get_translator = make_translator,
    translate = function(domain, str, ...) return str end,
    global_exists = function(name) return _G[name] ~= nil end,

    -- Settings
    settings = mock_settings,

    -- Mapgen
    get_mapgen_setting = function(key) return nil end,
    set_mapgen_setting = noop,
    get_mapgen_object = function(objname) return nil end,

    -- Mod storage
    get_mod_storage = function() return make_mod_storage() end,
    get_modnames = function() return {} end,
    get_dir_list = function(path, is_dir) return {} end,
    get_worldpath = function() return "/tmp/mineclonia_wiki_world" end,

    -- Item/group queries
    get_item_group = function(name, group) return 0 end,
    get_craft_result = function(input) return { item = ItemStack(""), time = 0 } end,
    get_craft_recipe = function(item) return nil end,
    get_all_craft_recipes = function(item) return nil end,

    -- Node/world manipulation (runtime, stubbed)
    get_node = function(pos) return { name = "air", param1 = 0, param2 = 0 } end,
    set_node = noop,
    swap_node = noop,
    add_entity = function() return nil end,
    add_item = noop,
    add_particle = noop,
    add_particlespawner = noop,
    delete_area = noop,
    find_node_near = function() return nil end,
    find_nodes_in_area = function() return {}, {} end,
    get_voxel_manip = function()
        return {
            read_from_map = function() return 0, 0 end,
            get_data = function() return {} end,
            set_data = noop,
            write_to_map = noop,
            get_light_data = function() return {} end,
            set_light_data = noop,
            get_param2_data = function() return {} end,
            set_param2_data = noop,
        }
    end,
    get_content_id = function(name) return 0 end,
    get_name_from_content_id = function(id) return "air" end,

    -- Player queries
    get_connected_players = function() return {} end,
    get_player_by_name = function() return nil end,
    get_player_ip = function() return "0.0.0.0" end,
    get_player_information = function() return nil end,

    -- Time/light
    get_timeofday = function() return 0.5 end,
    get_gametime = function() return 0 end,
    get_node_light = function() return 15 end,
    get_natural_light = function() return 15 end,

    -- Chat/messaging
    chat_send_all = noop,
    chat_send_player = noop,

    -- Protection
    is_protected = function() return false end,
    record_protection_violation = noop,
    set_node_password = noop,

    -- Creative/privs
    is_creative_enabled = function() return false end,
    check_player_privs = function() return false, {} end,
    get_player_privs = function() return {} end,
    override_chatcommand = noop,

    -- Serialization
    serialize = function(t) return tostring(t) end,
    deserialize = function(s) return nil end,

    -- Utilities
    hash_node_position = function(pos) return 0 end,
    get_position_from_hash = function(hash) return { x = 0, y = 0, z = 0 } end,
    get_us_time = function() return 0 end,
    get_server_max_lag = function() return 0 end,

    -- Colorize
    colorize = function(color, text) return text end,
    wrap_text = function(text, maxlen) return text end,

    -- Sounds
    sound_play = function() return 0 end,

    -- Log
    log = function(level, msg) end,

    -- Formspec
    show_formspec = noop,
    close_formspec = noop,

    -- Dynamic media
    dynamic_add_media = noop,

    -- HTTP (for mods that fetch data)
    request_http_api = function() return nil end,
    get_http_api = function() return nil end,

    -- Async
    handle_async = noop,
    register_async_work = noop,

    -- Misc
    after = noop,
    kick_player = noop,
    remove_player = noop,
    ban_player = noop,
    get_ban_list = function() return {} end,
    get_ban_description = function() return "" end,
    unban_player_or_ip = noop,
    notify_authentication_modified = noop,
    get_password_hash = function(name, raw) return "" end,
    set_password = function(name, raw) return false end,
    set_player_password = noop,
    set_player_privs = noop,
    send_join_message = noop,
    send_leave_message = noop,
}

-- Alias minetest -> core
minetest = core

-- ============================================================================
-- Mock: Global constants and utilities expected by mods
-- ============================================================================

-- DIR_DELIM: directory separator
DIR_DELIM = "/"

-- table.copy: deep copy (used by many mods)
if not table.copy then
    table.copy = function(t)
        if type(t) ~= "table" then return t end
        local result = {}
        for k, v in pairs(t) do
            result[k] = type(v) == "table" and table.copy(v) or v
        end
        return setmetatable(result, getmetatable(t))
    end
end

-- table.indexof
if not table.indexof then
    table.indexof = function(t, val)
        for i, v in ipairs(t) do
            if v == val then return i end
        end
        return -1
    end
end

-- string.trim
if not string.trim then
    string.trim = function(s)
        return s:match("^%s*(.-)%s*$")
    end
end

-- math.huge is already in standard Lua

-- ============================================================================
-- Mock: Additional callback registrations discovered during testing
-- ============================================================================

core.register_on_player_receive_fields = make_callback_reg("on_player_receive_fields")
core.register_allow_player_inventory_action = make_callback_reg("allow_player_inventory_action")
core.register_on_player_inventory_action = make_callback_reg("on_player_inventory_action")
core.register_globalstep_slow = make_callback_reg("globalstep_slow")

-- IPC (inter-mod communication)
local ipc_store = {}
core.ipc_set = function(key, val) ipc_store[key] = val end
core.ipc_get = function(key) return ipc_store[key] end

-- Insecure environment (used by some mods for HTTP/os calls)
core.request_insecure_environment = function() return _G end

-- get_translator with string methods (some mods use S"string" syntax)
local translator_mt = {
    __call = function(self, s, ...)
        local args = {...}
        if #args > 0 then
            local i = 0
            return s:gsub("%%[sd]", function()
                i = i + 1
                return tostring(args[i] or "")
            end)
        end
        return s
    end,
    __index = function(self, key)
        -- S:string syntax
        if key == "translate" then
            return function(s, ...) return s end
        end
        return nil
    end,
}

-- Override get_translator to return metatabled function
core.get_translator = function(domain)
    local fn = function(s, ...)
        local args = {...}
        if #args > 0 then
            local i = 0
            return s:gsub("%%[sd]", function()
                i = i + 1
                return tostring(args[i] or "")
            end)
        end
        return s
    end
    return setmetatable({}, {
        __call = function(self, s, ...) return fn(s, ...) end,
        __index = function(_, key) return fn end,
    })
end

-- get_language_info (used by translation system)
core.get_language = function() return { code = "en", category = "" } end

-- get_connected_players returns empty list
-- is_creative_enabled already defined

-- is_valid_playername
core.is_valid_playername = function(name) return type(name) == "string" and #name > 0 end

-- get_inventory
core.get_inventory = function() return nil end

-- create_detached_inventory
core.create_detached_inventory = function(name, callbacks)
    return {
        set_size = noop,
        set_width = noop,
        get_size = function() return 0 end,
        set_stack = noop,
        get_stack = function() return ItemStack("") end,
        add_item = noop,
        contains = function() return false end,
        contains_item = function() return false end,
        remove_item = noop,
        get_list = function() return {} end,
        set_list = noop,
        is_empty = function() return true end,
    }
end

-- get_server_status
core.get_server_status = function() return "OK" end

-- get_ban_list / get_ban_description already defined

-- rollback_get_node_actions
core.rollback_get_node_actions = function() return {} end

-- get_craft_result needs to return proper structure
core.get_craft_result = function(input)
    return {
        item = ItemStack(""),
        time = 0,
        replaced = {
            item = ItemStack(""),
        },
    }
end

-- get_craft_recipe
core.get_craft_recipe = function(item) return nil end

-- get_all_craft_recipes
core.get_all_craft_recipes = function(item) return nil end

-- get_content_id / get_name_from_content_id already defined

-- get_item_group - should look up from registered items
core.get_item_group = function(name, group)
    local def = core.registered_items[name]
    if def and def.groups and def.groups[group] then
        return def.groups[group]
    end
    return 0
end

-- Additional missing API functions
core.register_on_newplayer = make_callback_reg("on_newplayer")
core.register_on_shutdown = make_callback_reg("on_shutdown")
core.get_spawn_point_2d = function() return { x = 0, y = 0, z = 0 } end
core.setting_get_pos = function(name) return nil end
core.get_mapgen_setting = function(key)
    local defaults = {
        mg_name = "v7", seed = "0", water_level = 1, chunksize = 5,
        mapgen_limit = 31000, mapgen_edges = 128,
        mg_flags = "caves,dungeons,light,decorations,biomes,mudflow",
        mgv7_spflags = "mountains,ridges,nofloatlands,caverns",
        mgv5_spflags = "caverns",
        mgflat_spflags = "",
        mgsplasdf_spflags = "",
    }
    return defaults[key]
end
core.get_mapgen_setting_noiseparams = function(key) return nil end
core.register_alias_force = register_alias
core.get_game_info = function() return { id = "mineclonia", title = "Mineclonia", author = "", path = "" } end

-- PerlinNoiseMap
PerlinNoiseMap = function(params, size)
    local data = {}
    local map = {
        get_2d_map = function(self, pos) return data end,
        get_3d_map = function(self, pos) return data end,
        get_2d_map_flat = function(self, pos) return data end,
        get_3d_map_flat = function(self, pos) return data end,
        calc_2d_map = function(self, pos) return data end,
        calc_3d_map = function(self, pos) return data end,
        calc_2d_map_flat = function(self, pos) return data end,
        calc_3d_map_flat = function(self, pos) return data end,
    }
    return map
end

-- PerlinNoise
PerlinNoise = function(params)
    return {
        get_2d = function(self, pos) return 0 end,
        get_3d = function(self, pos) return 0 end,
    }
end

-- bit module (used by some mods)
bit = bit or {
    band = function(a, b) return a & b end,
    bor = function(a, b) return a | b end,
    bxor = function(a, b) return a ~ b end,
    bnot = function(a) return ~a end,
    lshift = function(a, n) return a << n end,
    rshift = function(a, n) return a >> n end,
    arshift = function(a, n) return a >> n end,
    bswap = function(a) return a end,
    tobit = function(a) return a end,
    tohex = function(a, n) return string.format("%0" .. (n or 8) .. "x", a) end,
}

-- ============================================================================
-- Mock: doc system (in-game documentation)
-- ============================================================================

doc = {
    sub = {
        identifier = {
            register_object = noop,
            register_node = noop,
        },
    },
    add_entry = noop,
    add_entry_alias = noop,
    add_category = noop,
    add_toc = noop,
}

-- ============================================================================
-- Mock: Global classes
-- ============================================================================

-- AreaStore
AreaStore = function()
    local store = {}
    function store:insert_area(min, max, data, id) return 0 end
    function store:get_areas_in_area(min, max, include_borders, include_data) return {} end
    function store:get_area_for_point(pos, include_borders, include_data) return nil end
    function store:remove_area(id) end
    function store:get_area(id) return nil end
    function store:set_cache_params(params) end
    function store:get_next_id() return 0 end
    return store
end

-- PseudoRandom
PseudoRandom = function(seed)
    local state = seed or 0
    return {
        next = function(self, min, max)
            state = (state * 1103515245 + 12345) % 2147483648
            local val = state / 2147483648
            if min and max then
                return math.floor(min + val * (max - min + 1))
            end
            return state
        end,
    }
end

-- SecureRandom
SecureRandom = function()
    return {
        next_bytes = function(self, n) return string.rep("\0", n) end,
    }
end

-- ItemStack

-- ============================================================================
-- Mock: Global classes
-- ============================================================================

-- ItemStack
ItemStack = function(spec)
    if type(spec) == "string" then
        return {
            get_name = function(self) return spec:match("^[^%s]+") or "" end,
            get_count = function(self) return tonumber(spec:match("%s(%d+)$")) or 1 end,
            get_wear = function(self) return 0 end,
            get_metadata = function(self) return "" end,
            get_definition = function(self)
                local name = self:get_name()
                return core.registered_items[name] or { name = name, description = name }
            end,
            to_string = function(self) return spec end,
            is_empty = function(self) return self:get_name() == "" end,
        }
    end
    if type(spec) == "table" then
        return spec
    end
    return {
        get_name = function(self) return "" end,
        get_count = function(self) return 0 end,
        get_wear = function(self) return 0 end,
        get_metadata = function(self) return "" end,
        get_definition = function(self) return { name = "", description = "" } end,
        to_string = function(self) return "" end,
        is_empty = function(self) return true end,
    }
end

-- VoxelArea
VoxelArea = function(extent)
    local o = {
        MinEdge = extent.MinEdge or { x = 0, y = 0, z = 0 },
        MaxEdge = extent.MaxEdge or { x = 0, y = 0, z = 0 },
    }
    o.ystride = (o.MaxEdge.x - o.MinEdge.x + 1)
    o.zstride = o.ystride * (o.MaxEdge.y - o.MinEdge.y + 1)
    function o:index(x, y, z)
        return (z - o.MinEdge.z) * o.zstride + (y - o.MinEdge.y) * o.ystride + (x - o.MinEdge.x) + 1
    end
    function o:contains(x, y, z)
        return x >= o.MinEdge.x and x <= o.MaxEdge.x
            and y >= o.MinEdge.y and y <= o.MaxEdge.y
            and z >= o.MinEdge.z and z <= o.MaxEdge.z
    end
    return o
end

-- PcgRandom
PcgRandom = function(seed)
    local state = seed or 0
    local rng = {
        next = function(self, min, max)
            -- Simple LCG, good enough for mocking
            state = (state * 1103515245 + 12345) % 2147483648
            local val = state / 2147483648
            if min and max then
                return math.floor(min + val * (max - min + 1))
            end
            return state
        end,
    }
    return rng
end

-- vector
vector = {
    new = function(x, y, z)
        if type(x) == "table" then return { x = x.x or 0, y = x.y or 0, z = x.z or 0 } end
        return { x = x or 0, y = y or 0, z = z or 0 }
    end,
    zero = function() return { x = 0, y = 0, z = 0 } end,
    copy = function(v) return { x = v.x, y = v.y, z = v.z } end,
    equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
    length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
    normalize = function(v)
        local len = vector.length(v)
        if len == 0 then return { x = 0, y = 0, z = 0 } end
        return { x = v.x / len, y = v.y / len, z = v.z / len }
    end,
    distance = function(a, b) return vector.length(vector.subtract(a, b)) end,
    direction = function(from, to) return vector.normalize(vector.subtract(to, from)) end,
    subtract = function(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end,
    add = function(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end,
    multiply = function(a, b)
        if type(b) == "number" then return { x = a.x * b, y = a.y * b, z = a.z * b } end
        return { x = a.x * b.x, y = a.y * b.y, z = a.z * b.z }
    end,
    divide = function(a, b)
        if type(b) == "number" then return { x = a.x / b, y = a.y / b, z = a.z / b } end
        return { x = a.x / b.x, y = a.y / b.y, z = a.z / b.z }
    end,
    apply = function(v, func) return { x = func(v.x), y = func(v.y), z = func(v.z) } end,
    round = function(v) return vector.apply(v, math.floor) end,
    offset = function(v, x, y, z) return { x = v.x + x, y = v.y + y, z = v.z + z } end,
    sort = function(a, b)
        return {
            x = math.min(a.x, b.x), y = math.min(a.y, b.y), z = math.min(a.z, b.z)
        }, {
            x = math.max(a.x, b.x), y = math.max(a.y, b.y), z = math.max(a.z, b.z)
        }
    end,
}

-- vector metatable for arithmetic operators
local vec_mt = {
    __add = function(a, b) return vector.add(a, b) end,
    __sub = function(a, b) return vector.subtract(a, b) end,
    __mul = function(a, b) return vector.multiply(a, b) end,
    __div = function(a, b) return vector.divide(a, b) end,
    __unm = function(v) return { x = -v.x, y = -v.y, z = -v.z } end,
    __len = function(v) return vector.length(v) end,
    __eq = function(a, b) return vector.equals(a, b) end,
    __tostring = function(v) return "(" .. v.x .. "," .. v.y .. "," .. v.z .. ")" end,
}

-- Make vector.new return tables with the metatable
local orig_new = vector.new
vector.new = function(x, y, z)
    local v = orig_new(x, y, z)
    setmetatable(v, vec_mt)
    return v
end

-- ============================================================================
-- Mock: Utility globals used by some mods
-- ============================================================================

-- dump() is used by some mods for debug
function dump(o, indent)
    if type(o) ~= "table" then return tostring(o) end
    return "[table]"
end

-- ============================================================================
-- Public interface
-- ============================================================================

function M.set_current_mod(name)
    current_mod = name
end

function M.log_error(mod, msg)
    M.captured.errors[#M.captured.errors + 1] = { mod = mod, error = msg }
end

function M.mark_mod_loaded(name)
    M.captured.mods_loaded[#M.captured.mods_loaded + 1] = name
end

return M
