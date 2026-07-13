---@class sentry.utils.envelope
--- Envelope construction and (de)serialization for every Sentry item type
--- (event, transaction, session, log, client_report, attachment, ...).
---
--- The envelope is the single wire format for all Sentry ingestion. Every item
--- carries a `type` (used to derive its data category for rate limiting) and a
--- byte `length`. See https://develop.sentry.dev/sdk/data-model/envelopes/

local json = require("sentry.utils.json")

local record EnvelopeItem
   header: {string: any}   -- must contain "type"; may contain length, content_type, item_count, ...
   payload: string         -- serialized item body (JSON for structured items, raw bytes for attachments)
end

local record Envelope
   header: {string: any}   -- may contain event_id, sent_at, dsn, trace
   items: {EnvelopeItem}
end

---Current time as an RFC 3339 UTC timestamp (used for the `sent_at` envelope header)
---@return string timestamp
local function now_rfc3339(): string
   return os.date("!%Y-%m-%dT%H:%M:%SZ") as string
end

-- Map an envelope item type to its Sentry "data category". The category is what
-- rate limiting and client reports are keyed on (e.g. "event" -> "error").
local TYPE_TO_CATEGORY: {string: string} = {
   event = "error",
   transaction = "transaction",
   session = "session",
   sessions = "session",
   log = "log_item",
   client_report = "internal",
   attachment = "attachment",
   check_in = "monitor",
   profile = "profile",
   profile_chunk = "profile_chunk",
}

---Resolve the data category for an item type (falls back to the type itself)
---@param item_type string
---@return string category
local function data_category(item_type: string): string
   return TYPE_TO_CATEGORY[item_type] or item_type
end

---Create a new, empty envelope
---@param header {string: any}? Optional envelope header (event_id, sent_at, dsn, trace)
---@return Envelope
local function new_envelope(header: {string: any}): Envelope
   return {
      header = header or {},
      items = {}
   }
end

---Append a structured (JSON) item. The payload table is serialized to JSON and
---its byte length recorded in the item header.
---@param env Envelope
---@param item_type string e.g. "event", "transaction", "session", "client_report"
---@param payload any Lua table serialized to JSON as the item body
---@param extra_header {string: any}? Optional extra item-header fields (content_type, item_count, ...)
local function add_item(env: Envelope, item_type: string, payload: any, extra_header: {string: any})
   local body = json.encode(payload)
   local item_header: {string: any} = {
      type = item_type,
      length = #body
   }
   if extra_header then
      for k, v in pairs(extra_header) do
         item_header[k] = v
      end
   end
   table.insert(env.items, { header = item_header, payload = body })
end

---Append a raw (already-serialized) item, e.g. an attachment.
---@param env Envelope
---@param item_header {string: any} Item header; `length` is set from the payload
---@param payload string Raw item bytes
local function add_raw_item(env: Envelope, item_header: {string: any}, payload: string)
   item_header.length = #payload
   table.insert(env.items, { header = item_header, payload = payload })
end

---Serialize an envelope to the on-the-wire format:
---  {envelope header}\n{item header}\n{item payload}\n{item header}\n{item payload}
---@param env Envelope
---@return string
local function serialize(env: Envelope): string
   local parts: {string} = { json.encode(env.header) }
   for _, item in ipairs(env.items) do
      table.insert(parts, json.encode(item.header))
      table.insert(parts, item.payload)
   end
   return table.concat(parts, "\n")
end

---List the distinct data categories present in an envelope (for rate limiting).
---@param env Envelope
---@return {string} categories
local function categories(env: Envelope): {string}
   local seen: {string: boolean} = {}
   local result: {string} = {}
   for _, item in ipairs(env.items) do
      local cat = data_category(item.header.type as string)
      if not seen[cat] then
         seen[cat] = true
         table.insert(result, cat)
      end
   end
   return result
end

---Best-effort parse of a serialized envelope back into an Envelope. Used by the
---test/file transports and tests to introspect what was sent. Safe on malformed
---input (returns whatever could be parsed).
---@param str string
---@return Envelope
local function parse(str: string): Envelope
   local env: Envelope = { header = {}, items = {} }
   if not str or str == "" then
      return env
   end

   local lines: {string} = {}
   for line in (str .. "\n"):gmatch("(.-)\n") do
      table.insert(lines, line)
   end
   if #lines == 0 then
      return env
   end

   local ok, decoded = pcall(json.decode, lines[1])
   if ok and decoded then
      env.header = decoded as {string: any}
   end

   local i = 2
   while i <= #lines do
      local hok, ih = pcall(json.decode, lines[i])
      if not hok or not ih then
         break
      end
      local payload = lines[i + 1] or ""
      table.insert(env.items, { header = ih as {string: any}, payload = payload })
      i = i + 2
   end
   return env
end

---Return the decoded payloads of every item of a given type in a serialized envelope.
---@param str string Serialized envelope
---@param item_type string e.g. "event"
---@return {any} payloads
local function extract_items(str: string, item_type: string): {any}
   local env = parse(str)
   local result: {any} = {}
   for _, item in ipairs(env.items) do
      if item.header.type == item_type then
         local ok, decoded = pcall(json.decode, item.payload)
         table.insert(result, ok and decoded or item.payload)
      end
   end
   return result
end

-- === High-level builders (return serialized strings) ===

---Build a serialized envelope for a single error/message event.
---@param event table Event payload (must contain event_id)
---@return string envelope
local function build_event_envelope(event: table, attachments: {any}): string
   local env = new_envelope({
      event_id = (event as any).event_id,
      sent_at = now_rfc3339()
   })
   add_item(env, "event", event)
   -- Attachments ride in the same envelope, sharing the event's event_id.
   if attachments then
      for _, att in ipairs(attachments) do
         local a = att as {string: any}
         add_raw_item(env, {
            type = "attachment",
            filename = (a["filename"] as string) or "attachment",
            content_type = (a["content_type"] as string) or "application/octet-stream",
            attachment_type = (a["attachment_type"] as string) or "event.attachment"
         }, (a["data"] as string) or "")
      end
   end
   return serialize(env)
end

---Build a serialized envelope for a transaction.
---@param transaction table Transaction payload
---@param event_id string Transaction event id
---@return string envelope
local function build_transaction_envelope(transaction: table, event_id: string, dsc: {string: any}): string
   local header: {string: any} = {
      event_id = event_id,
      sent_at = now_rfc3339()
   }
   -- The frozen Dynamic Sampling Context travels as the envelope `trace` header.
   if dsc then
      header["trace"] = dsc
   end
   local env = new_envelope(header)
   add_item(env, "transaction", transaction)
   return serialize(env)
end

---Build a serialized envelope for a release-health session.
---@param session table Session payload
---@return string envelope
local function build_session_envelope(session: table): string
   local env = new_envelope({ sent_at = now_rfc3339() })
   add_item(env, "session", session)
   return serialize(env)
end

---Build a serialized `client_report` envelope from discarded-event counts.
---@param discarded_events {any} Array of {reason, category, quantity}
---@return string envelope (empty string when there is nothing to report)
local function build_client_report_envelope(discarded_events: {any}): string
   if not discarded_events or #discarded_events == 0 then
      return ""
   end
   local env = new_envelope({})
   add_item(env, "client_report", {
      timestamp = now_rfc3339(),
      discarded_events = discarded_events
   })
   return serialize(env)
end

---Build a serialized envelope for a batch of log records.
---@param log_records {any} Array of log records
---@return string envelope (empty string when there are no records)
local function build_log_envelope(log_records: {any}): string
   if not log_records or #log_records == 0 then
      return ""
   end
   local env = new_envelope({ sent_at = now_rfc3339() })
   add_item(env, "log", { items = log_records }, {
      item_count = #log_records,
      content_type = "application/vnd.sentry.items.log+json"
   })
   return serialize(env)
end

---Build a serialized envelope for a batch of trace-connected metrics.
---@param records {any} Array of metric records
---@return string envelope (empty string when there are no records)
local function build_metrics_envelope(records: {any}): string
   if not records or #records == 0 then
      return ""
   end
   local env = new_envelope({ sent_at = now_rfc3339() })
   add_item(env, "trace_metric", { items = records }, {
      item_count = #records,
      content_type = "application/vnd.sentry.items.trace_metric+json"
   })
   return serialize(env)
end

return {
   EnvelopeItem = EnvelopeItem,
   Envelope = Envelope,
   new_envelope = new_envelope,
   add_item = add_item,
   add_raw_item = add_raw_item,
   serialize = serialize,
   categories = categories,
   data_category = data_category,
   parse = parse,
   extract_items = extract_items,
   now_rfc3339 = now_rfc3339,
   build_event_envelope = build_event_envelope,
   build_transaction_envelope = build_transaction_envelope,
   build_session_envelope = build_session_envelope,
   build_client_report_envelope = build_client_report_envelope,
   build_log_envelope = build_log_envelope,
   build_metrics_envelope = build_metrics_envelope,
}
