#!/usr/bin/env luajit

--[[
Export a simple XKB symbols layout as a KOReader Lua layout table.

Supports the common simple-layout subset: xkb_symbols sections, includes, and
key definitions with up to four symbol levels. It does not implement XKB
types, groups, actions, dead keys, or compose processing.

Examples:
    tools/xkb_to_lua.lua us
    tools/xkb_to_lua.lua de > /tmp/de.lua
]]--

local DEFAULT_SYMBOLS_DIR = "/usr/share/X11/xkb/symbols"
local DEFAULT_OUTPUT_DIR = "plugins/externalkeyboard.koplugin/keyboard_layouts"
local SHIFT = 1
local ALTGR = 2
local LEVEL_MASKS = { 0, SHIFT, ALTGR, SHIFT + ALTGR }
local ffi = require("ffi")

ffi.cdef[[
int isatty(int fd);
]]

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

local KEYSYMS = {
    space = " ", exclam = "!", quotedbl = '"', numbersign = "#",
    dollar = "$", percent = "%", ampersand = "&", apostrophe = "'",
    parenleft = "(", parenright = ")", asterisk = "*", plus = "+",
    comma = ",", minus = "-", period = ".", slash = "/",
    colon = ":", semicolon = ";", less = "<", equal = "=", greater = ">",
    question = "?", at = "@", bracketleft = "[", backslash = "\\",
    bracketright = "]", asciicircum = "^", underscore = "_", grave = "`",
    braceleft = "{", bar = "|", braceright = "}", asciitilde = "~",
    nobreakspace = "\194\160", exclamdown = "\194\161", cent = "\194\162",
    sterling = "\194\163", currency = "\194\164", yen = "\194\165", section = "\194\167",
    diaeresis = "\194\168", copyright = "\194\169", registered = "\194\174",
    degree = "\194\176", plusminus = "\194\177", paragraph = "\194\182",
    periodcentered = "\194\183", multiply = "\195\151", division = "\195\183",
    EuroSign = "\226\130\172", guillemotleft = "\194\171", guillemotright = "\194\187",
    leftsinglequotemark = "\226\128\152", rightsinglequotemark = "\226\128\153",
    leftdoublequotemark = "\226\128\156", rightdoublequotemark = "\226\128\157",
}

local function lua_string(value)
    return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function utf8_char(codepoint)
    if codepoint <= 0x7f then
        return string.char(codepoint)
    elseif codepoint <= 0x7ff then
        return string.char(0xc0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
    elseif codepoint <= 0xffff then
        return string.char(0xe0 + math.floor(codepoint / 0x1000), 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    elseif codepoint <= 0x10ffff then
        return string.char(0xf0 + math.floor(codepoint / 0x40000), 0x80 + math.floor(codepoint / 0x1000) % 0x40, 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    end
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
    local layout, variant = include:match("^([%w%./+%-]+)%(([%w+%-]+)%)$")
    if not layout then
        layout = include:match("^[%w%./+%-]+$")
    end
    assert(layout, "unsupported include " .. include)
    return layout, variant or "basic"
end

local function parse_keysym(name)
    if #name == 1 then return name end
    if KEYSYMS[name] then return KEYSYMS[name] end
    local codepoint = tonumber(name:match("^U([%x]+)$"), 16)
    return codepoint and utf8_char(codepoint) or nil
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

local function usage()
    io.stderr:write("Usage: tools/xkb_to_lua.lua <layout> [--variant NAME] [--layout-name NAME] [--symbols-dir PATH] [--output PATH]\n")
end

local function parse_arguments()
    local arguments = { variant = "basic", symbols_dir = DEFAULT_SYMBOLS_DIR }
    local index = 1
    while index <= #arg do
        local value = arg[index]
        if value == "--help" then
            usage()
            os.exit(0)
        elseif value == "--variant" or value == "--layout-name" or value == "--symbols-dir" or value == "--output" then
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
    assert(arguments.layout, "layout is required")
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
            table.insert(rendered_levels, value and lua_string(value) or "nil")
        end
        table.insert(lines, ("    [%s] = { %s },\n"):format(lua_string(key), table.concat(rendered_levels, ", ")))
    end
    table.insert(lines, "}\n")
    return table.concat(lines)
end

local arguments = parse_arguments()
local entries = load_section(arguments.symbols_dir, arguments.layout, arguments.variant, {})
entries[" "] = entries[" "] or { [0] = " ", [SHIFT] = " " }
local output = render_layout(entries, arguments.layout, arguments.variant)
local is_terminal = ffi.C.isatty(1) ~= 0
local output_path = arguments.output
if not output_path and is_terminal then
    output_path = DEFAULT_OUTPUT_DIR .. "/" .. (arguments.layout_name or arguments.layout) .. ".lua"
end
if output_path then
    local file, error_message = io.open(output_path, "w")
    assert(file, error_message)
    file:write(output)
    file:close()
    io.write("Wrote " .. output_path .. "\n")
else
    io.write(output)
end