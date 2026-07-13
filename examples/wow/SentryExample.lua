-- Example World of Warcraft addon using Sentry.
--
-- WoW addons are sandboxed (no outbound HTTP), so events are spooled into the
-- addon's SavedVariables and delivered later by the companion uploader
-- (see examples/uploader.lua). `SentryExampleDB` is declared in the .toc.

local sentry = require("sentry")
local wow = require("sentry.platforms.wow.integration")

-- SavedVariables is created by the game before addon load.
SentryExampleDB = SentryExampleDB or {}

sentry.init({
   dsn = "https://your-key@your-org.ingest.sentry.io/your-project",
   release = "SentryExample@1.0.0",
   environment = "live",
   spool = true,
   persistence_provider = wow.saved_variables_provider(SentryExampleDB),
   -- Attaches game version/build, locale, realm and the full addon list, and
   -- installs a global error handler for unhandled addon errors.
   integrations = { wow.integration() },
})

-- Add context/breadcrumbs like any other platform.
sentry.set_tag("module", "combat")
sentry.add_breadcrumb({ message = "Entered raid instance", category = "navigation" })

-- Manually capture a handled error.
local ok, err = pcall(function()
   error("example: something went wrong in a handled path")
end)
if not ok then
   sentry.capture_exception(err)
end

-- Envelopes now sit in SentryExampleDB.envelopes until the uploader delivers them.
