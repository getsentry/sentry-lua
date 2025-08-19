---@class sentry.performance
--- Object-oriented performance monitoring without global state

local headers = require("sentry.tracing.headers")

local record Transaction
   span_id: string
   parent_span_id: string
   trace_id: string
   op: string
   description: string
   status: string
   start_timestamp: number
   timestamp: number
   
   -- Transaction-specific fields
   event_id: string
   type: string
   transaction: string
   spans: {Span}
   contexts: {string: any}
   tags: {string: string}
   extra: {string: any}
   finished: boolean
   active_spans: {Span}  -- Stack for child spans
   
   -- Methods
   finish: function(self: Transaction, status: string)
   start_span: function(self: Transaction, op: string, description: string, options: table): Span
   add_tag: function(self: Transaction, key: string, value: string)
   add_data: function(self: Transaction, key: string, value: any)
end

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
   finished: boolean
   transaction: Transaction  -- Reference to parent transaction
   
   -- Methods
   finish: function(self: Span, status: string)
   start_span: function(self: Span, op: string, description: string, options: table): Span
   add_tag: function(self: Span, key: string, value: string)
   add_data: function(self: Span, key: string, value: any)
end

local performance = {}

---Generate a high-precision timestamp
---@return number timestamp Unix timestamp with microsecond precision
local function get_timestamp(): number
   return os.time() + (os.clock() % 1)
end

---Span methods (defined first since transaction methods reference it)
local span_mt = {}
span_mt.__index = span_mt

---Transaction methods
local transaction_mt = {}
transaction_mt.__index = transaction_mt

function transaction_mt:finish(status: string)
   if self.finished then
      return
   end
   
   self.timestamp = get_timestamp()
   self.status = status or "ok"
   self.finished = true
   
   -- Send transaction to Sentry using the main client
   local sentry = require("sentry")
   
   local transaction_data = {
      event_id = self.event_id,
      type = "transaction",
      transaction = self.transaction,
      start_timestamp = self.start_timestamp,
      timestamp = self.timestamp,
      spans = self.spans,
      contexts = self.contexts,
      tags = self.tags,
      extra = self.extra,
      platform = "lua",
      sdk = {
         name = "sentry.lua",
         version = "0.0.1"
      }
   }
   
   -- Add trace context
   transaction_data.contexts = transaction_data.contexts or {}
   transaction_data.contexts.trace = {
      trace_id = self.trace_id,
      span_id = self.span_id,
      parent_span_id = self.parent_span_id,
      op = self.op,
      status = self.status
   }
   
   -- Use the main sentry client to send the transaction
   if sentry._client then
      local envelope = require("sentry.utils.envelope")
      if sentry._client.transport and sentry._client.transport.send_envelope then
         local envelope_data = envelope.build_transaction_envelope(transaction_data, self.event_id)
         local transport_success, err = sentry._client.transport:send_envelope(envelope_data)
         
         if transport_success then
            print("[Sentry] Transaction sent: " .. self.event_id)
         else
            local fallback_success, fallback_err = sentry._client.transport:send(transaction_data)
            if fallback_success then
               print("[Sentry] Transaction sent: " .. self.event_id)
            else
               print("[Sentry] Failed to send transaction: " .. tostring(fallback_err or err))
            end
         end
      end
   end
end

function transaction_mt:start_span(op: string, description: string, options: table): Span
   options = options or {}
   
   local parent_span_id = #self.active_spans > 0 and self.active_spans[#self.active_spans].span_id or self.span_id
   
   local span_data: Span = {
      span_id = headers.generate_span_id(),
      parent_span_id = parent_span_id,
      trace_id = self.trace_id,
      op = op,
      description = description,
      status = "ok",
      tags = options.tags or {},
      data = options.data or {},
      start_timestamp = get_timestamp(),
      timestamp = 0, -- Will be set when finished
      origin = options.origin or "manual",
      finished = false,
      transaction = self
   }
   
   -- Set up span methods
   setmetatable(span_data, span_mt)
   
   table.insert(self.active_spans, span_data)
   
   -- Update propagation context to reflect the current active span
   local success, propagation = pcall(require, "sentry.tracing.propagation")
   if success then
      local propagation_context = {
         trace_id = span_data.trace_id,
         span_id = span_data.span_id,
         parent_span_id = span_data.parent_span_id,
         sampled = true,
         baggage = {},
         dynamic_sampling_context = {}
      }
      propagation.set_current_context(propagation_context)
   end
   
   return span_data
end

function transaction_mt:add_tag(key: string, value: string)
   self.tags = self.tags or {}
   self.tags[key] = value
end

function transaction_mt:add_data(key: string, value: any)
   self.extra = self.extra or {}
   self.extra[key] = value
end


function span_mt:finish(status: string)
   if self.finished then
      return
   end
   
   self.timestamp = get_timestamp()
   self.status = status or "ok"
   self.finished = true
   
   -- Remove from active spans stack
   local tx = self.transaction
   for i = #tx.active_spans, 1, -1 do
      if tx.active_spans[i].span_id == self.span_id then
         table.remove(tx.active_spans, i)
         break
      end
   end
   
   -- Add to completed spans
   table.insert(tx.spans, {
      span_id = self.span_id,
      parent_span_id = self.parent_span_id,
      trace_id = self.trace_id,
      op = self.op,
      description = self.description,
      status = self.status,
      tags = self.tags,
      data = self.data,
      start_timestamp = self.start_timestamp,
      timestamp = self.timestamp,
      origin = self.origin
   })
   
   -- Update propagation context (revert to parent context)
   local success, propagation = pcall(require, "sentry.tracing.propagation")
   if success then
      local parent_context
      if #tx.active_spans > 0 then
         -- Still have active spans, use the most recent one
         local active_span = tx.active_spans[#tx.active_spans]
         parent_context = {
            trace_id = active_span.trace_id,
            span_id = active_span.span_id,
            parent_span_id = active_span.parent_span_id,
            sampled = true,
            baggage = {},
            dynamic_sampling_context = {}
         }
      else
         -- No active spans, revert to transaction context
         parent_context = {
            trace_id = tx.trace_id,
            span_id = tx.span_id,
            parent_span_id = tx.parent_span_id,
            sampled = true,
            baggage = {},
            dynamic_sampling_context = {}
         }
      end
      propagation.set_current_context(parent_context)
   end
end

function span_mt:start_span(op: string, description: string, options: table): Span
   -- Delegate to transaction
   return self.transaction:start_span(op, description, options)
end

function span_mt:add_tag(key: string, value: string)
   self.tags = self.tags or {}
   self.tags[key] = value
end

function span_mt:add_data(key: string, value: any)
   self.data = self.data or {}
   self.data[key] = value
end

---Start a new transaction
---@param name string Transaction name
---@param op string Operation type (e.g., "http.server", "navigation")
---@param options table? Additional options
---@return Transaction transaction The started transaction
function performance.start_transaction(name: string, op: string, options: table): Transaction
   options = options or {}
   
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
         else
            -- No context exists, create new trace context automatically
            context = propagation.start_new_trace()
            trace_id = trace_id or context.trace_id
            span_id = span_id or headers.generate_span_id()
         end
      end
   end
   
   -- Fallback to generating new trace if no context exists
   trace_id = trace_id or headers.generate_trace_id()
   span_id = span_id or headers.generate_span_id()
   local start_time = get_timestamp()
   
   local transaction: Transaction = {
      event_id = require("sentry.utils").generate_uuid(),
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
            status = "unknown"
         }
      },
      tags = options.tags or {},
      extra = options.extra or {},
      
      -- Span fields
      span_id = span_id,
      parent_span_id = parent_span_id,
      trace_id = trace_id,
      op = op,
      description = name,
      status = "ok",
      finished = false,
      active_spans = {}
   }
   
   -- Set up transaction methods
   setmetatable(transaction, transaction_mt)
   
   -- Update propagation context to the transaction
   local success, propagation = pcall(require, "sentry.tracing.propagation")
   if success then
      local propagation_context = {
         trace_id = transaction.trace_id,
         span_id = transaction.span_id,
         parent_span_id = transaction.parent_span_id,
         sampled = true,
         baggage = {},
         dynamic_sampling_context = {}
      }
      propagation.set_current_context(propagation_context)
   end
   
   return transaction
end

return performance