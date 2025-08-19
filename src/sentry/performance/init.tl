---@class sentry.performance
--- Performance monitoring with transactions and spans
--- Provides timed operations with start/end timestamps

local headers = require("sentry.tracing.headers")

local record Span
   span_id: string
   parent_span_id: string
   trace_id: string
   op: string
   description: string
   status: string
   tags: {string: string}
   data: {string: any}
   start_timestamp: number
   timestamp: number
   origin: string
end

local record Transaction
   event_id: string
   type: string
   transaction: string
   start_timestamp: number
   timestamp: number
   spans: {Span}
   contexts: {string: any}
   tags: {string: string}
   extra: {string: any}
   -- Inherits from Span
   span_id: string
   parent_span_id: string
   trace_id: string
   op: string
   description: string
   status: string
end

local performance = {}

---Active spans stack for nested operations
local active_spans: {Span} = {}

---Current transaction
local current_transaction: Transaction = nil

---Generate a high-precision timestamp
---@return number timestamp Unix timestamp with microsecond precision
local function get_timestamp(): number
   return os.time() + (os.clock() % 1)
end

---Start a new transaction
---@param name string Transaction name
---@param op string Operation type (e.g., "http.server", "navigation")
---@param options table? Additional options
---@return Transaction transaction The started transaction
function performance.start_transaction(name: string, op: string, options: table): Transaction
   options = options or {}
   
   -- End current transaction if one exists
   if current_transaction then
      performance.finish_transaction()
   end
   
   -- Check for existing propagation context first
   local trace_id = options.trace_id
   local parent_span_id = options.parent_span_id
   local span_id = options.span_id
   
   if not trace_id or not span_id then
      local success, propagation = pcall(require, "sentry.tracing.propagation")
      if success then
         local context = propagation.get_current_context()
         if context then
            -- Continue existing trace
            trace_id = trace_id or context.trace_id
            parent_span_id = parent_span_id or context.span_id -- Current context becomes parent
            span_id = span_id or headers.generate_span_id() -- Generate new span for transaction
         end
      end
   end
   
   -- Fallback to generating new trace if no context exists
   trace_id = trace_id or headers.generate_trace_id()
   span_id = span_id or headers.generate_span_id()
   local start_time = get_timestamp()
   
   current_transaction = {
      event_id = require("sentry.utils").generate_uuid(), -- Use proper UUID for event ID
      type = "transaction",
      transaction = name,
      start_timestamp = start_time,
      timestamp = start_time, -- Will be updated when finished
      spans = {},
      contexts = {
         trace = {
            trace_id = trace_id,
            span_id = span_id,
            parent_span_id = parent_span_id,
            op = op,
            description = options.description or name,
            status = "ok",
            origin = options.origin or "manual"
         }
      },
      tags = options.tags or {},
      extra = options.extra or {},
      
      -- Span fields
      span_id = span_id,
      parent_span_id = parent_span_id,
      trace_id = trace_id,
      op = op,
      description = options.description or name,
      status = "ok"
   }
   
   -- Integrate with tracing propagation context
   local success, propagation = pcall(require, "sentry.tracing.propagation")
   if success then
      -- Set the current transaction's trace context as the active propagation context
      local propagation_context = {
         trace_id = trace_id,
         span_id = span_id,
         parent_span_id = parent_span_id,
         sampled = true, -- Performance monitoring implies sampling
         baggage = {},
         dynamic_sampling_context = {}
      }
      propagation.set_current_context(propagation_context)
   end
   
   return current_transaction
end

---Finish the current transaction
---@param status string? Final status (default: "ok")
function performance.finish_transaction(status: string)
   if not current_transaction then
      return
   end
   
   current_transaction.timestamp = get_timestamp()
   current_transaction.status = status or "ok"
   current_transaction.contexts.trace.status = current_transaction.status
   
   -- Send transaction to Sentry using envelope format
   local success, sentry = pcall(require, "sentry")
   if success and sentry and sentry._client then
      -- Create transaction event
      local transaction_event = {
         event_id = current_transaction.event_id,
         type = "transaction",
         transaction = current_transaction.transaction,
         start_timestamp = current_transaction.start_timestamp,
         timestamp = current_transaction.timestamp,
         spans = current_transaction.spans,
         contexts = current_transaction.contexts,
         tags = current_transaction.tags,
         extra = current_transaction.extra,
         platform = "lua",
         sdk = {
            name = "sentry.lua",
            version = require("sentry.version")
         }
      }
      
      -- Apply scope data
      transaction_event = sentry._client.scope:apply_to_event(transaction_event as any) as any
      
      -- Send as envelope if transport supports it
      local transport_success, err
      if sentry._client.transport.send_envelope then
         -- Use envelope format for transactions
         local envelope = require("sentry.utils.envelope")
         local envelope_body = envelope.build_transaction_envelope(transaction_event, current_transaction.event_id)
         transport_success, err = sentry._client.transport:send_envelope(envelope_body)
      else
         -- Fallback to regular send (for compatibility)
         transport_success, err = sentry._client.transport:send(transaction_event)
      end
      
      if sentry._client.options.debug then
         if transport_success then
            print("[Sentry] Transaction sent: " .. current_transaction.event_id)
         else
            print("[Sentry] Failed to send transaction: " .. tostring(err))
         end
      end
   end
   
   current_transaction = nil
   active_spans = {}
end

---Start a new span within the current transaction
---@param op string Operation type (e.g., "db.query", "http.client")
---@param description string Span description
---@param options table? Additional options
---@return Span span The started span
function performance.start_span(op: string, description: string, options: table): Span
   options = options or {}
   
   if not current_transaction then
      error("Cannot start span without active transaction")
   end
   
   local parent_span_id = #active_spans > 0 and active_spans[#active_spans].span_id or current_transaction.span_id
   
   local span: Span = {
      span_id = headers.generate_span_id(),
      parent_span_id = parent_span_id,
      trace_id = current_transaction.trace_id,
      op = op,
      description = description,
      status = "ok",
      tags = options.tags or {},
      data = options.data or {},
      start_timestamp = get_timestamp(),
      timestamp = 0, -- Will be set when finished
      origin = options.origin or "manual"
   }
   
   table.insert(active_spans, span)
   
   -- Update propagation context to reflect the current active span
   local success, propagation = pcall(require, "sentry.tracing.propagation")
   if success then
      local propagation_context = {
         trace_id = span.trace_id,
         span_id = span.span_id,
         parent_span_id = span.parent_span_id,
         sampled = true,
         baggage = {},
         dynamic_sampling_context = {}
      }
      propagation.set_current_context(propagation_context)
   end
   
   return span
end

---Finish the most recent span
---@param status string? Final status (default: "ok")
function performance.finish_span(status: string)
   if #active_spans == 0 then
      return
   end
   
   local span = table.remove(active_spans)
   span.timestamp = get_timestamp()
   span.status = status or "ok"
   
   if current_transaction then
      table.insert(current_transaction.spans, span)
   end
   
   -- Update propagation context when span finishes (revert to parent context)
   local success, propagation = pcall(require, "sentry.tracing.propagation")
   if success then
      local parent_context
      if #active_spans > 0 then
         -- Still have active spans, use the most recent one
         local active_span = active_spans[#active_spans]
         parent_context = {
            trace_id = active_span.trace_id,
            span_id = active_span.span_id,
            parent_span_id = active_span.parent_span_id,
            sampled = true,
            baggage = {},
            dynamic_sampling_context = {}
         }
      elseif current_transaction then
         -- No active spans, revert to transaction context
         parent_context = {
            trace_id = current_transaction.trace_id,
            span_id = current_transaction.span_id,
            parent_span_id = current_transaction.parent_span_id,
            sampled = true,
            baggage = {},
            dynamic_sampling_context = {}
         }
      else
         parent_context = nil
      end
      propagation.set_current_context(parent_context)
   end
end

---Get the current active transaction
---@return Transaction? transaction Current transaction or nil
function performance.get_current_transaction(): Transaction
   return current_transaction
end

---Get the current active span
---@return Span? span Current span or nil  
function performance.get_current_span(): Span
   return #active_spans > 0 and active_spans[#active_spans] or nil
end

---Set status on current span or transaction
---@param status string Status to set
function performance.set_status(status: string)
   if #active_spans > 0 then
      active_spans[#active_spans].status = status
   elseif current_transaction then
      current_transaction.status = status
      current_transaction.contexts.trace.status = status
   end
end

---Set tag on current span or transaction
---@param key string Tag key
---@param value string Tag value
function performance.set_tag(key: string, value: string)
   if #active_spans > 0 then
      active_spans[#active_spans].tags[key] = value
   elseif current_transaction then
      current_transaction.tags[key] = value
   end
end

---Set data on current span or transaction
---@param key string Data key
---@param value any Data value
function performance.set_data(key: string, value: any)
   if #active_spans > 0 then
      active_spans[#active_spans].data[key] = value
   elseif current_transaction then
      current_transaction.extra[key] = value
   end
end

---Create a traced function wrapper
---@param op string Operation type
---@param description string Description
---@param func function Function to wrap
---@return function wrapped_func Wrapped function that creates spans
function performance.trace(op: string, description: string, func: function): function
   return function(...): any
      local span = performance.start_span(op, description)
      
      local success, result = pcall(func, ...)
      
      if success then
         performance.finish_span("ok")
         return result
      else
         performance.finish_span("internal_error")
         error(result)
      end
   end
end

---Measure a function execution time and create a span
---@param op string Operation type
---@param description string Description  
---@param func function Function to measure
---@return any result Function result
function performance.measure(op: string, description: string, func: function): any
   local span = performance.start_span(op, description)
   
   local success, result = pcall(func)
   
   if success then
      performance.finish_span("ok")
      return result
   else
      performance.finish_span("internal_error")
      error(result)
   end
end

return {
   Span = Span,
   Transaction = Transaction,
   start_transaction = performance.start_transaction,
   finish_transaction = performance.finish_transaction,
   start_span = performance.start_span,
   finish_span = performance.finish_span,
   get_current_transaction = performance.get_current_transaction,
   get_current_span = performance.get_current_span,
   set_status = performance.set_status,
   set_tag = performance.set_tag,
   set_data = performance.set_data,
   trace = performance.trace,
   measure = performance.measure
}