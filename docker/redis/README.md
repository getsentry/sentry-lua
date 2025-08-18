# Redis + Sentry Lua Integration Test

This directory contains a comprehensive integration test that demonstrates the Sentry Lua SDK working with Redis, including the execution of Lua scripts within Redis itself.

## What This Test Does

The integration test performs several key operations:

### 1. **Basic Redis Operations**
- Connects to Redis from Lua
- Performs basic SET/GET operations
- Tracks operations as breadcrumbs in Sentry

### 2. **Redis Lua Script Execution**
- Loads a Lua script into Redis using `SCRIPT LOAD`
- Executes the script multiple times with different parameters
- The script implements an atomic counter with logging
- Demonstrates server-side Lua execution within Redis

### 3. **Error Handling**
- Tests error conditions in Redis Lua scripts
- Captures and reports Redis script errors to Sentry
- Shows proper error handling patterns

### 4. **Complex Transactions**
- Executes multi-operation atomic transactions using Lua scripts
- Demonstrates user session management patterns
- Shows how Lua scripts ensure atomicity in Redis operations

### 5. **Sentry Integration**
- Captures messages, exceptions, and breadcrumbs
- Tags events with Redis-specific context
- Demonstrates error reporting from Redis operations

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Test Client   │───▶│   Redis Server  │    │  Sentry Server  │
│  (OpenResty)    │    │   (Redis 7)     │    │   (Cloud)       │
│                 │    │                 │    │                 │
│ - Sentry SDK    │    │ - Lua Scripts   │    │ - Event Storage │
│ - Redis Client  │    │ - Data Storage  │    │ - Error Tracking│
│ - Test Runner   │    │ - Script Cache  │    │ - Performance   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

- Docker and Docker Compose installed
- Network access to Sentry (or configure your own DSN)

## Running the Tests

### Quick Start

```bash
# Navigate to the redis test directory
cd docker/redis

# Run all tests with the convenience script
./run_test.sh
```

### Manual Execution

```bash
# Start Redis server
docker-compose up -d redis

# Run the test
docker-compose run --rm sentry-test

# Clean up
docker-compose down -v
```

### Individual Commands

```bash
# Build only
docker-compose build

# View logs
docker-compose logs redis
docker-compose logs sentry-test

# Interactive shell in test container
docker-compose run --rm sentry-test bash
```

## Test Output

The test produces detailed output showing:

```
=== Testing Sentry SDK with Redis Lua Scripts ===
✓ Connected to Redis
✓ Sentry initialized

--- Test 1: Basic Redis Operations ---
✓ SET/GET test: hello_redis

--- Test 2: Redis Lua Script Execution ---
✓ Lua script loaded: 1a2b3c4d5e6f...
  Execution 1: counter = 1 (was 0)
  Execution 2: counter = 3 (was 1)
  Execution 3: counter = 6 (was 3)
  Execution 4: counter = 10 (was 6)
  Execution 5: counter = 15 (was 10)
✓ Script execution log:
  1. Incremented from 6 to 10
  2. Incremented from 3 to 6
  3. Incremented from 1 to 3
  4. Incremented from 0 to 1

--- Test 3: Error Handling in Lua Scripts ---
✓ Success case: success
✓ Caught Redis Lua script error: ...
✓ Exception sent to Sentry: abc123...

--- Test 4: Complex Operations with Transaction ---
✓ Transaction completed:
  User data: data, test_user_data, last_seen, 1703123456
  Session: session_abc_123
  Activity count: 1
✓ Cleanup completed

✓ Final test report sent to Sentry: def456...
✓ Test exception captured: ghi789...

=== All Redis + Sentry integration tests completed successfully! ===
```

## Redis Lua Scripts

The test includes several example Lua scripts that run inside Redis:

### Counter Script
```lua
local key = KEYS[1]
local increment = tonumber(ARGV[1]) or 1
local current = redis.call('GET', key)

if not current then
    current = 0
else
    current = tonumber(current)
end

local new_value = current + increment
redis.call('SET', key, new_value)

-- Log the operation
local log_key = key .. ':log'
redis.call('LPUSH', log_key, 'Incremented from ' .. current .. ' to ' .. new_value)
redis.call('EXPIRE', log_key, 300)

return {new_value, current}
```

### Transaction Script
Demonstrates atomic multi-key operations for user session management.

## Configuration

### Environment Variables

- `REDIS_HOST`: Redis server hostname (default: `redis`)
- `REDIS_PORT`: Redis server port (default: `6379`)

### Sentry DSN

The test uses a pre-configured Sentry DSN. To use your own:

1. Create a Sentry project
2. Update the DSN in `test.lua`
3. Or set the `SENTRY_DSN` environment variable

## Files

- `docker-compose.yml` - Container orchestration
- `Dockerfile` - Test container with OpenResty + dependencies  
- `test.lua` - Main integration test script
- `run_test.sh` - Convenience test runner
- `README.md` - This documentation

## What You Learn

This integration test demonstrates:

1. **Redis Lua Scripting**: How to write and execute Lua scripts in Redis
2. **Atomicity**: Using Lua scripts for atomic multi-key operations
3. **Error Handling**: Proper error handling in both client and server-side Lua
4. **Sentry Integration**: How to instrument Redis operations with Sentry
5. **Docker Orchestration**: Multi-container application testing
6. **Real-world Patterns**: Session management, counters, and logging patterns

## Troubleshooting

### Redis Connection Issues
```bash
# Check if Redis is running
docker-compose ps redis

# View Redis logs
docker-compose logs redis

# Test Redis connectivity
docker-compose exec redis redis-cli ping
```

### Container Build Issues
```bash
# Rebuild without cache
docker-compose build --no-cache

# Check build logs
docker-compose build sentry-test
```

### Test Failures
```bash
# Run with verbose output
docker-compose run --rm sentry-test lua -e "print('Debug mode')" docker/redis/test.lua

# Interactive debugging
docker-compose run --rm sentry-test bash
```

## Next Steps

After running this test successfully, you can:

1. Modify the Lua scripts to test your own use cases
2. Add more complex Redis operations
3. Test different error scenarios
4. Integrate with your own Sentry project
5. Adapt the patterns for your production applications