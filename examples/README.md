# Sentry Lua SDK Examples

This directory contains practical examples demonstrating how to use the Sentry Lua SDK for error monitoring and performance tracking.

## Distribution Methods

- **Single-File Distribution** (Game Engines): Copy `build-single-file/sentry.lua` (~21 KB) to your project. All functions available under `sentry` namespace.
- **LuaRocks Distribution** (Traditional Lua): Install via `luarocks install sentry/sentry` and require modules separately.

## Basic Usage Examples

### `basic.lua`
Complete demonstration of core Sentry functionality:
- SDK initialization and configuration
- User context, tags, and extra data
- Breadcrumbs for debugging context
- Manual error capture with `xpcall`
- Common Lua pitfalls and error patterns
- Scoped context management

**Run:** `lua examples/basic.lua`

### `wrap_demo.lua`
Demonstrates automatic error capture using `sentry.wrap()`:
- Simple automatic error capture
- Custom error handlers
- Comparison with manual error handling
- Context preservation across wrapped functions

**Run:** `lua examples/wrap_demo.lua`

### `logging.lua`
Comprehensive logging functionality demonstration:
- Structured logging at different severity levels
- Parameterized messages with template support
- Additional attributes for rich context
- Automatic print statement capture with recursion protection
- Log correlation with distributed traces
- Log filtering and modification hooks
- Batching and buffer management

**Run:** `lua examples/logging.lua`

## Distributed Tracing Examples

**Requirements:** Install dependencies first:
```bash
luarocks install pegasus
luarocks install luasocket
```

### `tracing/client.lua`
HTTP client demonstrating trace propagation:
- Object-oriented performance API with method chaining
- LuaSocket HTTP client integration
- Automatic trace context injection into requests
- Cross-process distributed tracing
- Proper parent-child span relationships

### `tracing/server.lua`
HTTP server with distributed tracing:
- Object-oriented transaction and span management
- Pegasus web server integration
- Automatic trace context extraction from headers
- Cross-process trace propagation and continuation
- Performance monitoring for web endpoints

**Usage:**
1. Start server: `lua examples/tracing/server.lua`
2. In another terminal: `lua examples/tracing/client.lua`
3. View connected traces in Sentry UI showing proper parent-child relationships

**Key Features Demonstrated:**
- `transaction:start_span()` and `span:finish()` methods
- Automatic trace context management across HTTP boundaries
- Proper distributed trace hierarchy (client transaction → server transaction)
- Error correlation within distributed traces
- Performance timing across service boundaries

## Configuration

All examples use the playground project DSN. For production use:
1. Replace DSN with your project's DSN
2. Update environment and release information
3. Configure appropriate sampling rates

## Viewing Results

After running examples, check your Sentry project:
- **Issues** tab: View captured errors and exceptions
- **Performance** tab: View transactions and spans
- **Discover** tab: Query events and trace data

The distributed tracing examples will show connected spans across processes, demonstrating how requests flow through your system.

## Platform-Specific Examples

### Roblox
- **`roblox/sentry.lua`**: Complete Roblox example with embedded single-file SDK
- **`roblox/README.md`**: Roblox setup guide

Copy the example file into Roblox Studio as a Script for immediate use.

### Love2D
- **`love2d/main.lua`**: Love2D example using single-file SDK  
- **`love2d/conf.lua`**: Love2D configuration
- **`love2d/sentry.lua`**: Single-file SDK copied to project
- **`love2d/README.md`**: Complete setup guide
- **`love2d/main-luarocks.lua`**: LuaRocks version (for reference)

### Build Examples
To generate the single-file SDK and update all platform examples:
```bash
make build-single-file  # Generates build-single-file/sentry.lua
```