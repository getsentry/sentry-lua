# Sentry SDK for Lua

[![Tests](https://github.com/getsentry/sentry-lua/actions/workflows/test.yml/badge.svg)](https://github.com/getsentry/sentry-lua/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/getsentry/sentry-lua/branch/main/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-lua)

A platform-agnostic Sentry SDK for Lua environments. Written in Teal Language for better type safety and developer experience.

The goal of this SDK is to be *portable* Lua code, so CI/tests run on Standard Lua, as well as LuaJIT, which can run on [Game Consoles](https://luajit.org/status.html#consoles),
one of [Sentry's latest platform investments](https://blog.sentry.io/playstation-xbox-switch-pc-or-mobile-wherever-youve-got-bugs-to-crush-sentry/).

## Features

- **Platform Agnostic**: Works across Redis, nginx, Roblox, game engines, and standard Lua
- **Type Safe**: Written in Teal Language with full type definitions
- **Comprehensive**: Error tracking, breadcrumbs, context management, and scoped operations
- **Extensible**: Pluggable transport system for different environments

## Supported Platforms

- Standard Lua 5.1+ environments
- Roblox game platform
- LÖVE 2D game engine
- Solar2D/Corona SDK
- Defold game engine
- Redis (lua scripting)
- nginx/OpenResty

## Installation

### LuaRocks
```bash
luarocks install sentry/sentry
```

### Roblox
Import the module through the Roblox package system or use the pre-built releases.

## Quick Start

```lua
local sentry = require("sentry")

-- Initialize with your DSN
sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "production",
   release = "0.0.1"
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
```

## Distributed Tracing

The Sentry Lua SDK supports distributed tracing for performance monitoring across service boundaries. Traces help you understand the performance characteristics of your application and identify bottlenecks.

### Requirements

For the distributed tracing examples, you'll need additional dependencies:

```bash
luarocks install pegasus    # HTTP server framework
luarocks install luasocket  # HTTP client library
```

### Basic Tracing

```lua
local sentry = require("sentry")
local performance = require("sentry.performance")

sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id"
})

-- Start a transaction
local transaction = performance.start_transaction("user_checkout", "http.server")

-- Add spans for different operations
local validation_span = performance.start_span("validation", "Validate cart")
-- ... validation logic ...
performance.finish_span("ok")

local payment_span = performance.start_span("payment.charge", "Process payment")
-- ... payment logic ...
performance.finish_span("ok")

-- Finish the transaction
performance.finish_transaction("ok")
```

### Distributed Tracing Examples

The SDK includes complete examples demonstrating distributed tracing:

- `examples/tracing_basic.lua` - Basic tracing concepts with transactions and spans
- `examples/tracing_server.lua` - HTTP server with distributed tracing endpoints
- `examples/tracing_client.lua` - HTTP client that propagates trace context

To see distributed tracing in action:

1. Start the server: `lua examples/tracing_server.lua`
2. In another terminal, run the client: `lua examples/tracing_client.lua`
3. Check your Sentry dashboard to see connected traces across both processes

The examples demonstrate:
- Automatic trace context propagation via HTTP headers
- Nested spans showing operation hierarchy and timing  
- Error correlation within distributed traces
- Performance monitoring across service boundaries

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

## Development

### Prerequisites
- Teal Language compiler
- busted (for testing)
- Docker (for integration tests)

### Building
```bash
make install     # Install dependencies
make build       # Compile Teal to Lua
make test        # Run unit tests
make docs        # Generate documentation
make serve-docs  # Serve docs at http://localhost:8000
make lint-soft   # Lint with warnings (permissive)
```

**Windows:**
```cmd
build.bat serve-docs  # Serve docs locally
```

### Testing
```bash
# Unit tests
make test

# Docker integration tests
make docker-test-redis
make docker-test-nginx

# Full test suite
make test-all
```

## License

MIT License - see LICENSE file for details.