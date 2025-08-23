# Sentry SDK for Lua

> NOTE: Experimental SDK

[![Tests](https://github.com/getsentry/sentry-lua/actions/workflows/test.yml/badge.svg)](https://github.com/getsentry/sentry-lua/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/getsentry/sentry-lua/branch/main/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-lua)

The goal of this SDK is to be *portable* Lua code, so CI/tests run on Standard Lua, as well as LuaJIT, which can run on [Game Consoles](https://luajit.org/status.html#consoles),
one of [Sentry's latest platform investments](https://blog.sentry.io/playstation-xbox-switch-pc-or-mobile-wherever-youve-got-bugs-to-crush-sentry/).

## Installation

### LuaRocks (macOS/Linux)
```bash
# Install from LuaRocks.org - requires Unix-like system for Teal compilation
luarocks install sentry/sdk
```
**Note:** Use `sentry/sdk` (not just `sentry`) as the plain `sentry` package is not a Sentry SDK.

### Direct Download (Windows/Cross-platform)
For Windows or systems without make/compiler support:
1. Download the latest `sentry-lua-sdk-publish.zip` from [GitHub Releases](https://github.com/getsentry/sentry-lua/releases)
2. Extract the contents

## Quick Start

```lua
local sentry = require("sentry")

-- Initialize with your DSN
sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "production",
   release = "0.0.6"
})

-- Capture a message
sentry.capture_message("Hello Sentry!", "info")

-- Capture an exception
local success, err = pcall(function()
   error("Something went wrong!")
end)

if not success then
   sentry.capture_exception({
      type = "MyError",
      message = err
   })
end

-- Flush pending events
sentry.flush()

-- Clean shutdown
sentry.close()
```

## API Reference

- `sentry.init(config)` - Initialize the Sentry client with configuration
- `sentry.capture_message(message, level)` - Capture a log message  
- `sentry.capture_exception(exception, level)` - Capture an exception
- `sentry.set_user(user)` - Set user context
- `sentry.set_tag(key, value)` - Add a tag for filtering
- `sentry.set_extra(key, value)` - Add extra debugging information
- `sentry.add_breadcrumb(breadcrumb)` - Add a breadcrumb for debugging context
- `sentry.flush()` - Force immediate sending of pending events
- `sentry.close()` - Clean shutdown of the Sentry client
- `sentry.with_scope(callback)` - Execute code with isolated scope
- `sentry.wrap(main_function, error_handler)` - Wrap function with error handling


## Automatic Error Capture

For automatic capture of unhandled errors, use `sentry.wrap()` to wrap your main application function:

```lua
local sentry = require("sentry")

sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id"
})

local function main()
   -- Your application logic here
   local config = nil
   local db_url = config.database_url  -- This error will be automatically captured
end

-- Simple automatic error capture
local success, result = sentry.wrap(main)

if not success then
   print("Error occurred but was sent to Sentry:", result)
end
```

You can also provide a custom error handler:

```lua
local function custom_error_handler(err)
   print("Custom handling:", err)
   -- Perform cleanup, logging, etc.
   return "Handled gracefully"
end

local success, result = sentry.wrap(main, custom_error_handler)
```

The `sentry.wrap()` approach automatically includes all your Sentry context (user data, tags, breadcrumbs) with captured errors, making it much simpler than manually wrapping every error-prone operation with `pcall`/`xpcall`.

See `examples/wrap_demo.lua` for a complete demonstration.

## Examples

There are several [examples in this repository](/examples/).

For example, the LÖVE framework example app:

![Screenshot of this example app](./examples/love2d/example-app.png "LÖVE Example App")

