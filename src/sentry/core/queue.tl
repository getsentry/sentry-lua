---@class sentry.core.queue
--- Bounded FIFO of serialized envelopes awaiting delivery.
---
--- When the queue is full, the oldest envelope is dropped to make room for the
--- newest (a ring buffer). Each drop is reported through `on_drop` so the client
--- can record it as a `queue_overflow` client report.

local record QueuedItem
   payload: string
   categories: {string}
end

local record Queue
   items: {QueuedItem}
   max_size: number
   on_drop: function(categories: {string})
end

---Create a new bounded queue.
---@param max_size number? Maximum queued envelopes (default 30)
---@param on_drop function? Called with the dropped item's categories on overflow
---@return Queue
function Queue.new(max_size: number, on_drop: function(categories: {string})): Queue
   return setmetatable({
      items = {},
      max_size = max_size or 30,
      on_drop = on_drop
   }, {__index = Queue}) as Queue
end

function Queue:size(): number
   return #self.items
end

function Queue:is_empty(): boolean
   return #self.items == 0
end

---Append an envelope. Drops the oldest item(s) if at capacity.
---@param payload string Serialized envelope
---@param categories {string} Data categories in the envelope
---@return boolean accepted false if an item had to be dropped to make room
function Queue:enqueue(payload: string, categories: {string}): boolean
   local dropped = false
   while #self.items >= self.max_size do
      local old = table.remove(self.items, 1)
      dropped = true
      if self.on_drop and old then
         self.on_drop(old.categories)
      end
   end
   table.insert(self.items, { payload = payload, categories = categories or {} })
   return not dropped
end

---Peek at the head item without removing it.
---@return QueuedItem?
function Queue:peek(): QueuedItem
   return self.items[1]
end

---Remove and return the head item.
---@return QueuedItem?
function Queue:dequeue(): QueuedItem
   return table.remove(self.items, 1)
end

return Queue
