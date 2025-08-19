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