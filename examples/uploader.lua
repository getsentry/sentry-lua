#!/usr/bin/env lua
-- Companion uploader for sandboxed platforms.
--
-- Run this from somewhere WITH network access (a desktop helper, a server-side
-- cron, or a CI step). It reads spooled envelopes and delivers them to Sentry.
--
-- Usage:
--   lua examples/uploader.lua <DSN> <spool-file>
-- e.g. for a WoW addon:
--   lua examples/uploader.lua "https://key@org.ingest.sentry.io/1" \
--       "~/World of Warcraft/_retail_/WTF/Account/.../SavedVariables/SentryExample.lua"

package.path = "build/?.lua;build/?/init.lua;;" .. package.path

local persistence = require("sentry.core.persistence")
local uploader = require("sentry.uploader")
local file_io = require("sentry.core.file_io")

local dsn = arg[1]
local spool_path = arg[2]
if not dsn or not spool_path then
   io.stderr:write("usage: lua examples/uploader.lua <DSN> <spool-file>\n")
   os.exit(1)
end

-- The file provider expects the NDJSON spool written by the file-backed spool
-- transport. (For WoW SavedVariables, parse the Lua table and feed a
-- memory_provider instead.)
local provider = persistence.file_provider(file_io.create_standard_file_io(), spool_path, 10000)

local result = uploader.upload(provider, dsn)
print(string.format("Uploaded %d/%d spooled envelopes", result.sent, result.total))
