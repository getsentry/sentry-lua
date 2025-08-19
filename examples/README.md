# Sentry Lua SDK Examples

This directory contains practical examples demonstrating how to use the Sentry Lua SDK for error monitoring and performance tracking.

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

## Distributed Tracing Examples

**Requirements:** Install dependencies first:
```bash
luarocks install pegasus
luarocks install luasocket
```

### `tracing_basic.lua`
Introduction to performance monitoring:
- Creating transactions and spans
- Custom instrumentation
- Error correlation within traces
- Basic performance tracking

**Run:** `lua examples/tracing_basic.lua`

### `tracing_server.lua`
HTTP server with distributed tracing:
- Pegasus web server integration
- Automatic trace context extraction
- Cross-process trace propagation
- Performance monitoring for web endpoints

**Run:** `lua examples/tracing_server.lua`

### `tracing_client.lua`
HTTP client demonstrating trace propagation:
- LuaSocket HTTP client
- Trace context injection into requests
- Cross-process distributed tracing
- Client-side performance monitoring

**Usage:**
1. Start server: `lua examples/tracing_server.lua`
2. In another terminal: `lua examples/tracing_client.lua`
3. View connected traces in Sentry UI

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