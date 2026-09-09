#!/usr/bin/env luajit

--[[
Export a simple XKB symbols layout as a KOReader Lua layout table.

Supports the common simple-layout subset: xkb_symbols sections, includes, and
key definitions with up to four symbol levels. It does not implement XKB
types, groups, or actions. Dead keys are preserved for runtime composition.

Examples:
    tools/xkb_to_lua.lua us
    tools/xkb_to_lua.lua de > /tmp/de.lua
    tools/xkb_to_lua.lua --all
]]--

local DEFAULT_SYMBOLS_DIR = "/usr/share/X11/xkb/symbols"
local DEFAULT_OUTPUT_DIR = "plugins/externalkeyboard.koplugin/keyboard_layouts"
local SHIFT = 1
local ALTGR = 2
local LEVEL_MASKS = { 0, SHIFT, ALTGR, SHIFT + ALTGR }
local ffi = require("ffi")

ffi.cdef[[
int isatty(int fd);
typedef uint32_t xkb_keysym_t;
xkb_keysym_t xkb_keysym_from_name(const char *name, int flags);
int xkb_keysym_to_utf8(xkb_keysym_t keysym, char *buffer, size_t size);
]]

local xkbcommon = ffi.load("xkbcommon")

-- XKB physical names used by a standard evdev full-size keyboard, mapped to
-- the names produced by externalkeyboard.koplugin/event_map_keyboard.lua.
local KEY_NAMES = {
    TLDE = "`",
    AE11 = "-", AE12 = "=",
    AD11 = "[", AD12 = "]",
    AC10 = ";", AC11 = "'", BKSL = "\\",
    AB08 = ",", AB09 = ".", AB10 = "/", SPCE = " ",
}

for number, key in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }) do
    KEY_NAMES[("AE%02d"):format(number)] = key
end
for number, key in ipairs({ "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P" }) do
    KEY_NAMES[("AD%02d"):format(number)] = key
end
for number, key in ipairs({ "A", "S", "D", "F", "G", "H", "J", "K", "L" }) do
    KEY_NAMES[("AC%02d"):format(number)] = key
end
for number, key in ipairs({ "Z", "X", "C", "V", "B", "N", "M" }) do
    KEY_NAMES[("AB%02d"):format(number)] = key
end

local function lua_string(value)
    return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function read_file(path)
    local file, error_message = io.open(path, "r")
    assert(file, error_message)
    local content = file:read("*a")
    file:close()
    return content:gsub("//[^\n]*", "")
end

local function section_body(text, variant, source)
    local _, section_end = text:find('xkb_symbols%s+"' .. variant .. '"%s*%{')
    assert(section_end, ('%s: xkb_symbols "%s" not found'):format(source, variant))
    local depth = 1
    local position = section_end + 1
    local start = position
    while position <= #text and depth > 0 do
        local character = text:sub(position, position)
        if character == "{" then
            depth = depth + 1
        elseif character == "}" then
            depth = depth - 1
        end
        position = position + 1
    end
    assert(depth == 0, source .. ": unclosed xkb_symbols section")
    return text:sub(start, position - 2)
end

local function parse_include(include)
    local layout, variant = include:match("^([%w%./+%-]+)%(([%w_%-]+)%)$")
    if not layout then
        layout = include:match("^[%w%./+%-]+$")
    end
    assert(layout, "unsupported include " .. include)
    return layout, variant or "basic"
end

local function parse_keysym(name)
    if #name == 1 then return name end
    if name:match("^dead_[%w_]+$") then return { dead = name } end
    local keysym = xkbcommon.xkb_keysym_from_name(name, 0)
    if keysym == 0 then return nil end
    local buffer = ffi.new("char[7]")
    local length = xkbcommon.xkb_keysym_to_utf8(keysym, buffer, 7)
    return length > 0 and ffi.string(buffer, length - 1) or nil
end

local function load_section(symbols_dir, layout, variant, seen)
    local identity = layout .. "(" .. variant .. ")"
    assert(not seen[identity], "cyclic include involving " .. identity)
    seen[identity] = true

    local body = section_body(read_file(symbols_dir .. "/" .. layout), variant, layout)
    local entries = {}
    for include in body:gmatch('include%s+"([^"]+)"') do
        local included_layout, included_variant = parse_include(include)
        for key, levels in pairs(load_section(symbols_dir, included_layout, included_variant, seen)) do
            entries[key] = levels
        end
    end
    for xkb_key, symbols in body:gmatch("key%s+<([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])>%s*{%s*%[([^%]]*)%]") do
        local key = KEY_NAMES[xkb_key]
        if key then
            local levels = {}
            local level = 0
            for keysym in (symbols .. ","):gmatch("(.-),") do
                keysym = keysym:match("^%s*(.-)%s*$")
                if level >= #LEVEL_MASKS then
                    io.stderr:write(("warning: %s(%s) <%s>: more than four levels\n"):format(layout, variant, xkb_key))
                    break
                end
                local value = parse_keysym(keysym)
                if value then
                    levels[LEVEL_MASKS[level + 1]] = value
                else
                    io.stderr:write(("warning: %s(%s) <%s>: unsupported keysym %s\n"):format(layout, variant, xkb_key, keysym))
                end
                level = level + 1
            end
            if next(levels) then entries[key] = levels end
        end
    end
    seen[identity] = nil
    return entries
end

local KOREADER_XKB_LAYOUTS = {
    ar = { "ara", "basic" },
    bg_BG = { "bg", "bds" },
    bn = { "bd", "basic" },
    cs = { "cz", "basic" },
    da = { "dk", "basic" },
    el = { "gr", "basic" },
    en = { "us", "basic" },
    fa = { "ir", "pes" },
    he = { "il", "basic" },
    ja = { "jp", "106" },
    ka = { "ge", "basic" },
    ko_KR = { "kr", "kr106" },
    ml = { "in", "mal" },
    nb_NO = { "no", "basic" },
    pt_BR = { "br", "abnt2" },
    ru = { "ru", "winkeys" },
    sr = { "rs", "basic" },
    sv = { "se", "basic" },
    uk = { "ua", "unicode" },
    vi = { "vn", "basic" },
    zh = { "cn", "basic" },
    zh_CN = { "cn", "basic" },
}

local function available_koreader_layouts()
    local virtual_keyboard = read_file("frontend/ui/widget/virtualkeyboard.lua")
    local map = virtual_keyboard:match("lang_to_keyboard_layout%s*=%s*{(.-)\n    },")
    assert(map, "VirtualKeyboard.lang_to_keyboard_layout not found")
    local layouts = {}
    for language in map:gmatch("\n%s*([%w_]+)%s*=") do
        local xkb_layout = KOREADER_XKB_LAYOUTS[language]
        table.insert(layouts, {
            language = language,
            layout = xkb_layout and xkb_layout[1] or language:match("^[^_]+"),
            variant = xkb_layout and xkb_layout[2] or "basic",
        })
    end
    table.sort(layouts, function(left, right) return left.language < right.language end)
    return layouts
end

local function usage()
    io.stderr:write("Usage: tools/xkb_to_lua.lua <layout> [--variant NAME] [--layout-name NAME] [--symbols-dir PATH] [--output PATH]\n")
    io.stderr:write("       tools/xkb_to_lua.lua --all [--symbols-dir PATH] [--output-dir PATH]  # KOReader virtual keyboard layouts\n")
end

local function parse_arguments()
    local arguments = { variant = "basic", symbols_dir = DEFAULT_SYMBOLS_DIR }
    local index = 1
    while index <= #arg do
        local value = arg[index]
        if value == "--help" then
            usage()
            os.exit(0)
        elseif value == "--all" then
            arguments.all = true
        elseif value == "--variant" or value == "--layout-name" or value == "--symbols-dir" or value == "--output" or value == "--output-dir" then
            index = index + 1
            assert(arg[index], value .. " requires a value")
            arguments[value:sub(3):gsub("%-", "_")] = arg[index]
        elseif not arguments.layout then
            arguments.layout = value
        else
            error("unexpected argument " .. value)
        end
        index = index + 1
    end
    assert(arguments.layout or arguments.all, "layout or --all is required")
    assert(not (arguments.layout and arguments.all), "--all cannot be combined with a layout")
    assert(not (arguments.all and (arguments.variant ~= "basic" or arguments.layout_name or arguments.output)), "--all only supports --symbols-dir and --output-dir")
    return arguments
end

local function render_layout(entries, layout, variant)
    local lines = {
        ("-- Generated by tools/xkb_to_lua.lua from %s(%s).\n"):format(layout, variant),
        "return {\n",
    }
    local keys = {}
    for key in pairs(entries) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local levels = entries[key]
        local rendered_levels = {}
        local last_level = 0
        for index, level in ipairs(LEVEL_MASKS) do
            if levels[level] then last_level = index end
        end
        for index = 1, last_level do
            local value = levels[LEVEL_MASKS[index]]
            local rendered_value = type(value) == "table" and ("{ dead = %s }"):format(lua_string(value.dead)) or value and lua_string(value)
            table.insert(rendered_levels, rendered_value or "nil")
        end
        table.insert(lines, ("    [%s] = { %s },\n"):format(lua_string(key), table.concat(rendered_levels, ", ")))
    end
    table.insert(lines, "}\n")
    return table.concat(lines)
end

local function write_layout(path, output)
    local file, error_message = io.open(path, "w")
    assert(file, error_message)
    file:write(output)
    file:close()
end

local arguments = parse_arguments()
if arguments.all then
    local output_dir = arguments.output_dir or DEFAULT_OUTPUT_DIR
    local written = 0
    local skipped = 0
    for _, layout_info in ipairs(available_koreader_layouts()) do
        local success, entries = pcall(load_section, arguments.symbols_dir, layout_info.layout, layout_info.variant, {})
        if success and next(entries) then
            entries[" "] = entries[" "] or { [0] = " ", [SHIFT] = " " }
            write_layout(output_dir .. "/" .. layout_info.language .. ".lua", render_layout(entries, layout_info.layout, layout_info.variant))
            written = written + 1
        else
            io.stderr:write(("warning: skipped %s (%s/%s): %s\n"):format(layout_info.language, layout_info.layout, layout_info.variant, success and "no supported keys" or entries))
            skipped = skipped + 1
        end
    end
    io.write(("Wrote %d layouts to %s (%d skipped)\n"):format(written, output_dir, skipped))
else
    local entries = load_section(arguments.symbols_dir, arguments.layout, arguments.variant, {})
    entries[" "] = entries[" "] or { [0] = " ", [SHIFT] = " " }
    local output = render_layout(entries, arguments.layout, arguments.variant)
    local is_terminal = ffi.C.isatty(1) ~= 0
    local output_path = arguments.output
    if not output_path and is_terminal then
        output_path = DEFAULT_OUTPUT_DIR .. "/" .. (arguments.layout_name or arguments.layout) .. ".lua"
    end
    if output_path then
        write_layout(output_path, output)
        io.write("Wrote " .. output_path .. "\n")
    else
        io.write(output)
    end
end