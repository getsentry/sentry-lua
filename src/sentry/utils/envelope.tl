---@class sentry.utils.envelope
--- Envelope formatting utilities for Sentry transactions and performance data

local json = require("sentry.utils.json")

---Build an envelope for a transaction
---@param transaction table Transaction data
---@param event_id string Event ID 
---@return string envelope_body The formatted envelope body
local function build_transaction_envelope(transaction: table, event_id: string): string
   -- Get current timestamp in RFC 3339 format
   local sent_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
   
   -- Envelope header
   local envelope_header = {
      event_id = event_id,
      sent_at = sent_at
   }
   
   -- Transaction JSON payload
   local transaction_json = json.encode(transaction)
   local payload_length = string.len(transaction_json)
   
   -- Item header  
   local item_header = {
      type = "transaction",
      length = payload_length
   }
   
   -- Build envelope: header + newline + item header + newline + payload
   local envelope_parts = {
      json.encode(envelope_header),
      json.encode(item_header),
      transaction_json
   }
   
   return table.concat(envelope_parts, "\n")
end

return {
   build_transaction_envelope = build_transaction_envelope
}