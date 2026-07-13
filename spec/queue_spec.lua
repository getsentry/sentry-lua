-- Bounded outbound queue unit tests
local Queue = require("sentry.core.queue")

describe("Queue", function()
   it("enqueues and reports size", function()
      local q = Queue.new(5)
      assert.is_true(q:is_empty())
      q:enqueue("a", {"error"})
      q:enqueue("b", {"error"})
      assert.equals(2, q:size())
      assert.is_false(q:is_empty())
   end)

   it("dequeues FIFO", function()
      local q = Queue.new(5)
      q:enqueue("a", {"error"})
      q:enqueue("b", {"error"})
      assert.equals("a", q:peek().payload)
      assert.equals("a", q:dequeue().payload)
      assert.equals("b", q:dequeue().payload)
      assert.is_nil(q:dequeue())
   end)

   it("drops oldest on overflow and reports the drop", function()
      local dropped = {}
      local q = Queue.new(2, function(cats) table.insert(dropped, cats[1]) end)
      assert.is_true(q:enqueue("a", {"error"}))
      assert.is_true(q:enqueue("b", {"transaction"}))
      -- Third enqueue overflows: oldest ("a"/error) is dropped
      assert.is_false(q:enqueue("c", {"log_item"}))
      assert.equals(2, q:size())
      assert.same({"error"}, dropped)
      -- Head is now "b"
      assert.equals("b", q:peek().payload)
   end)

   it("defaults to a max size of 30", function()
      local q = Queue.new()
      for i = 1, 40 do
         q:enqueue("x" .. i, {})
      end
      assert.equals(30, q:size())
   end)
end)
