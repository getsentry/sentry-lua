# Distributed Tracing Examples

This directory contains comprehensive examples demonstrating Sentry's distributed tracing capabilities in Lua. These examples show how traces propagate across HTTP requests, maintaining context between different services and operations.

## 🚀 Quick Start

1. **Install Dependencies** (optional, for HTTP server/client examples):
   ```bash
   luarocks install pegasus
   luarocks install luasocket
   ```

2. **Run Basic Examples**:
   ```bash
   # Simple tracing demo
   lua examples/tracing/01_basic_tracing.lua
   
   # Headers and propagation
   lua examples/tracing/02_headers_demo.lua
   ```

3. **End-to-End Server/Client Demo**:
   ```bash
   # Terminal 1 - Start the server
   lua examples/tracing/server.lua
   
   # Terminal 2 - Run the client (in another terminal)
   lua examples/tracing/client.lua
   ```

## 📁 Example Files

### Core Tracing Examples

- **`01_basic_tracing.lua`** - Basic trace creation and context management
- **`02_headers_demo.lua`** - Header parsing, generation, and propagation
- **`03_manual_instrumentation.lua`** - Manual HTTP client/server instrumentation
- **`04_auto_instrumentation.lua`** - Automatic library instrumentation demo

### End-to-End Demos

- **`server.lua`** - HTTP server with distributed tracing
- **`client.lua`** - HTTP client that calls the server with trace propagation
- **`middleware_demo.lua`** - Framework middleware integration examples

## 🔄 End-to-End Trace Propagation

The **server.lua** and **client.lua** examples demonstrate real distributed tracing:

1. **Server** (`server.lua`):
   - Runs an HTTP server on `localhost:8080`
   - Automatically continues traces from incoming requests
   - Captures events with trace context
   - Shows trace IDs in responses

2. **Client** (`client.lua`):
   - Makes HTTP requests to the server
   - Automatically injects trace headers
   - Captures events with trace context
   - Demonstrates trace continuation across services

### What You'll See in Sentry

When you run both server and client, you'll see in your Sentry dashboard:

1. **Connected Events**: Client and server events linked by the same trace ID
2. **Request Flow**: Visual representation of requests flowing between services  
3. **Error Correlation**: Any errors in either service connected to the same trace
4. **Performance Context**: Request timing and performance data

## 🎯 Key Concepts Demonstrated

### Automatic Trace Continuation
```lua
-- Server automatically continues traces from incoming headers
local trace_info = tracing.get_current_trace_info()
if trace_info then
    print("Continuing trace: " .. trace_info.trace_id)
end
```

### Automatic Header Injection
```lua
-- Client automatically adds trace headers to outgoing requests
local response = http.request("http://localhost:8080/api/users")
-- sentry-trace header automatically added
```

### Event Trace Context
```lua
-- Events automatically include trace context
sentry.capture_message("User action completed", "info")
-- Event will show up in Sentry connected to the current trace
```

## 🔧 Configuration Options

The examples demonstrate various configuration options:

```lua
tracing_platform.init({
    tracing = {
        -- Only propagate traces to these targets
        trace_propagation_targets = {"localhost", "api%.myservice%.com"},
        
        -- Include W3C traceparent header for OpenTelemetry compatibility
        include_traceparent = true
    },
    
    -- Automatically instrument HTTP libraries when loaded
    auto_instrument = true
})
```

## 🛠️ Prerequisites

- **Lua 5.1+** or **LuaJIT**
- **Optional**: `luarocks install pegasus` for HTTP server examples
- **Optional**: `luarocks install luasocket` for HTTP client examples

## 📊 Expected Output

### Server Console
```
🚀 Distributed Tracing Server
============================
Server running on http://localhost:8080
[2024-08-18 20:15:32] 📥 Incoming request: GET /
[2024-08-18 20:15:32] 🔗 Continuing trace: abc123def456...
[2024-08-18 20:15:32] ✅ Event captured: Server processed request
```

### Client Console  
```
🔄 Distributed Tracing Client
============================
🚀 Starting new trace: abc123def456...
📡 Making request to server...
📋 Trace headers sent:
    sentry-trace: abc123def456...-789xyz-1
✅ Server response: {"trace_id":"abc123def456..."}
✅ Event captured: Client request completed
```

### Sentry Dashboard
- Two connected events with the same trace ID
- Request flow visualization
- Performance and error correlation

## 🎯 Learning Objectives

After running these examples, you'll understand:

1. **How traces flow** between HTTP services automatically
2. **When and how** trace headers are added/read
3. **How events** get connected across service boundaries
4. **Platform detection** and automatic instrumentation
5. **Manual vs automatic** instrumentation approaches
6. **Error correlation** across distributed systems

## 🔍 Troubleshooting

### "Module not found" errors
Make sure you're running from the repository root:
```bash
cd /path/to/sentry-lua
lua examples/tracing/server.lua
```

### No trace propagation
Check that both client and server are using the same Sentry DSN and that the server is reachable.

### Platform not supported
Some examples may show "Platform not supported" - this is normal for platforms like Roblox or Redis. The examples will still demonstrate the concepts with mock implementations.

## 🚀 Next Steps

1. **Modify the DSN** in the examples to use your own Sentry project
2. **Add custom baggage** data for additional context
3. **Create custom spans** for specific operations  
4. **Integrate** with your own HTTP frameworks
5. **Monitor** your distributed traces in the Sentry dashboard