---@class sentry.utils
--- Utility functions for the Sentry Lua SDK
--- Provides helper functions for ID generation, encoding, etc.

local utils = {}

---Generate a random UUID (version 4)
---@return string uuid A random UUID in the format xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
function utils.generate_uuid()
    -- Seed random number generator if not already seeded
    if not utils._random_seeded then
        math.randomseed(os.time())
        utils._random_seeded = true
    end
    
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

---Generate random hex string of specified length
---@param length number Number of hex characters to generate
---@return string hex_string Random hex string
function utils.generate_hex(length)
    if not utils._random_seeded then
        math.randomseed(os.time())
        utils._random_seeded = true
    end
    
    local hex_chars = "0123456789abcdef"
    local result = {}
    
    for i = 1, length do
        local idx = math.random(1, #hex_chars)
        table.insert(result, hex_chars:sub(idx, idx))
    end
    
    return table.concat(result)
end

---URL encode a string
---@param str string String to encode
---@return string encoded_string URL encoded string
function utils.url_encode(str)
    if not str then
        return ""
    end
    
    str = tostring(str)
    
    -- Replace unsafe characters with percent encoding
    str = str:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    
    return str
end

---URL decode a string
---@param str string String to decode
---@return string decoded_string URL decoded string
function utils.url_decode(str)
    if not str then
        return ""
    end
    
    str = tostring(str)
    
    -- Replace percent encoding with actual characters
    str = str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    
    return str
end

---Check if a string is empty or nil
---@param str string? String to check
---@return boolean is_empty True if string is nil or empty
function utils.is_empty(str)
    return not str or str == ""
end

---Trim whitespace from both ends of a string
---@param str string String to trim
---@return string trimmed_string String with whitespace removed from both ends
function utils.trim(str)
    if not str then
        return ""
    end
    
    return str:match("^%s*(.-)%s*$")
end

---Deep copy a table
---@param orig table Original table
---@return table copy Deep copy of the table
function utils.deep_copy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.deep_copy(orig_key)] = utils.deep_copy(orig_value)
        end
        setmetatable(copy, utils.deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

---Merge two tables (shallow merge)
---@param t1 table First table
---@param t2 table Second table
---@return table merged_table Merged table
function utils.merge_tables(t1, t2)
    local result = {}
    
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
function utils.get_timestamp()
    return os.time()
end

---Get current timestamp in milliseconds (best effort)
---@return number timestamp Current timestamp in milliseconds
function utils.get_timestamp_ms()
    -- Try to use socket.gettime if available for higher precision
    local success, socket = pcall(require, "socket")
    if success and socket.gettime then
        return math.floor(socket.gettime() * 1000)
    end
    
    -- Fallback to seconds * 1000
    return os.time() * 1000
end

return utils