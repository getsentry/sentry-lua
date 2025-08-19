---@class sentry.utils
--- Utility functions for the Sentry Lua SDK
--- Provides helper functions for ID generation, encoding, etc.

local record Utils
    _random_seeded: boolean
    
    generate_uuid: function(): string
    generate_hex: function(length: number): string
    url_encode: function(str: string): string
    url_decode: function(str: string): string
    is_empty: function(str: string): boolean
    trim: function(str: string): string
    deep_copy: function<T>(orig: T): T
    merge_tables: function<K, V>(t1: {K: V}, t2: {K: V}): {K: V}
    get_timestamp: function(): number
    get_timestamp_ms: function(): number
end

local utils: Utils = {}

---Generate a random UUID (version 4)
---@return string uuid A random UUID in the format xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
function utils.generate_uuid(): string
    -- Seed random number generator if not already seeded
    if not utils._random_seeded then
        math.randomseed(os.time())
        utils._random_seeded = true
    end
    
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    
    local result = template:gsub("[xy]", function(c: string): string
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
    return result
end

---Generate random hex string of specified length
---@param length number Number of hex characters to generate
---@return string hex_string Random hex string
function utils.generate_hex(length: number): string
    if not utils._random_seeded then
        math.randomseed(os.time())
        utils._random_seeded = true
    end
    
    local hex_chars = "0123456789abcdef"
    local result: {string} = {}
    
    for _ = 1, length do
        local idx = math.random(1, #hex_chars)
        table.insert(result, hex_chars:sub(idx, idx))
    end
    
    return table.concat(result)
end

---URL encode a string
---@param str string String to encode
---@return string encoded_string URL encoded string
function utils.url_encode(str: string): string
    if not str then
        return ""
    end
    
    str = tostring(str)
    
    -- Replace unsafe characters with percent encoding
    str = str:gsub("([^%w%-%.%_%~])", function(c: string): string
        return string.format("%%%02X", string.byte(c))
    end)
    
    return str
end

---URL decode a string
---@param str string String to decode
---@return string decoded_string URL decoded string
function utils.url_decode(str: string): string
    if not str then
        return ""
    end
    
    str = tostring(str)
    
    -- Replace percent encoding with actual characters
    str = str:gsub("%%(%x%x)", function(hex: string): string
        return string.char(tonumber(hex, 16) as integer)
    end)
    
    return str
end

---Check if a string is empty or nil
---@param str string? String to check
---@return boolean is_empty True if string is nil or empty
function utils.is_empty(str: string): boolean
    return not str or str == ""
end

---Trim whitespace from both ends of a string
---@param str string String to trim
---@return string trimmed_string String with whitespace removed from both ends
function utils.trim(str: string): string
    if not str then
        return ""
    end
    
    return str:match("^%s*(.-)%s*$") or ""
end

---Deep copy a table
---@param orig table Original table
---@return table copy Deep copy of the table
function utils.deep_copy<T>(orig: T): T
    local copy: any
    if type(orig) == "table" then
        copy = {}
        local orig_table = orig as {any: any}
        for orig_key, orig_value in next, orig_table, nil do
            (copy as {any: any})[utils.deep_copy(orig_key)] = utils.deep_copy(orig_value)
        end
        setmetatable(copy as table, utils.deep_copy(getmetatable(orig as table)))
    else
        copy = orig
    end
    return copy as T
end

---Merge two tables (shallow merge)
---@param t1 table First table
---@param t2 table Second table
---@return table merged_table Merged table
function utils.merge_tables<K, V>(t1: {K: V}, t2: {K: V}): {K: V}
    local result: {K: V} = {}
    
    if t1 then
        for k, v in pairs(t1) do
            result[k] = v
        end
    end
    
    if t2 then
        for k, v in pairs(t2) do
            result[k] = v
        end
    end
    
    return result
end

---Get current timestamp in seconds
---@return number timestamp Current timestamp
function utils.get_timestamp(): number
    return os.time()
end

---Get current timestamp in milliseconds (best effort)
---@return number timestamp Current timestamp in milliseconds
function utils.get_timestamp_ms(): number
    -- Try to use socket.gettime if available for higher precision
    local success, socket_module = pcall(require, "socket")
    if success and socket_module and type(socket_module) == "table" then
        local socket_table = socket_module as {string: any}
        if socket_table["gettime"] and type(socket_table["gettime"]) == "function" then
            local gettime = socket_table["gettime"] as function(): number
            return math.floor(gettime() * 1000)
        end
    end
    
    -- Fallback to seconds * 1000
    return os.time() * 1000
end

return utils