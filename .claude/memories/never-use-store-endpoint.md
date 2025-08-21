# NEVER USE STORE ENDPOINT - ONLY ENVELOPES

## CRITICAL RULE

**NEVER USE THE /store ENDPOINT IN SENTRY LUA SDK**
**ONLY USE ENVELOPES VIA THE /envelope ENDPOINT**

## Why This Rule Exists

1. **Logs require envelopes to work** - Sentry's logging functionality only works with envelope transport
2. **Modern Sentry protocol** - The /store endpoint is legacy, envelopes are the modern approach
3. **Feature completeness** - All Sentry features (errors, logs, traces, performance) work through envelopes
4. **No fallbacks** - Never implement fallback to /store endpoint

## Implementation Requirements

### DSN Utils (src/sentry/utils/dsn.tl)
- ✅ ONLY `build_envelope_url()` function
- ❌ NO `build_ingest_url()` function
- ✅ All URLs point to `/api/{project_id}/envelope/`

### Transport Layer (src/sentry/platforms/*/transport.tl)
- ✅ ONLY `send_envelope()` method
- ❌ NO `send()` method for events
- ✅ ONLY `envelope_endpoint` field
- ❌ NO `endpoint` field
- ✅ Content-Type: `application/x-sentry-envelope`

### Core Client (src/sentry/core/client.tl)
- ✅ All events converted to envelopes before sending
- ✅ Use `envelope.build_error_envelope(event)` for errors/messages
- ✅ Use `envelope.build_log_envelope(logs)` for logs
- ✅ Use `envelope.build_transaction_envelope(transaction, event_id)` for performance
- ✅ Call `transport:send_envelope(envelope_body)`

### Envelope Building (src/sentry/utils/envelope.tl)
- ✅ Centralized envelope building logic in core
- ✅ Platform-specific transports only handle network layer
- ✅ Supports errors, logs, and transactions

## Transport Architecture

```
Core Client → Envelope Builder → Platform Transport → Network Request
             (envelope.tl)      (only network layer)
```

## Verification Checklist

When working with Sentry Lua SDK, always verify:
- [ ] No references to `build_ingest_url`
- [ ] No `send(event)` methods in transports
- [ ] No `/store/` URLs in any transport
- [ ] All events use `build_error_envelope()`
- [ ] All transports have `send_envelope()` method
- [ ] Content-Type is `application/x-sentry-envelope`
- [ ] Envelope building logic is in core, not platforms

## Memory Trigger

This rule applies to ALL work on the Sentry Lua SDK. Never implement or suggest the /store endpoint approach.