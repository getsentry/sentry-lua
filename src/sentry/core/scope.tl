-- Scope manages contextual data that gets applied to events
-- This includes user, tags, extra data, contexts, breadcrumbs, etc.

local record Scope
   user: table
   tags: {string: string}
   extra: {string: any}
   contexts: {string: any}  -- For runtime, os, device contexts
   breadcrumbs: {table}
   max_breadcrumbs: number
   level: string
end

function Scope:new(): Scope
   return setmetatable({
      user = {},
      tags = {},
      extra = {},
      contexts = {},
      breadcrumbs = {},
      max_breadcrumbs = 100,
      level = nil  -- nil means inherit from client/event
   }, {__index = Scope}) as Scope
end

function Scope:set_user(user: table)
   self.user = user or {}
end

function Scope:set_tag(key: string, value: string)
   self.tags[key] = value
end

function Scope:set_extra(key: string, value: any)
   self.extra[key] = value
end

function Scope:set_context(key: string, value: any)
   self.contexts[key] = value
end

function Scope:set_level(level: string)
   local valid_levels: {string: boolean} = {debug = true, info = true, warning = true, error = true, fatal = true}
   if valid_levels[level] then
      self.level = level
   end
end

function Scope:add_breadcrumb(breadcrumb: table)
   local crumb: table = {
      timestamp = os.time(),
      message = breadcrumb.message or "",
      category = breadcrumb.category or "default",
      level = breadcrumb.level or "info",
      data = breadcrumb.data or {}
   }
   table.insert(self.breadcrumbs, crumb)
   
   while #self.breadcrumbs > self.max_breadcrumbs do
      table.remove(self.breadcrumbs, 1)
   end
end

function Scope:clear()
   self.user = {}
   self.tags = {}
   self.extra = {}
   self.contexts = {}
   self.breadcrumbs = {}
   self.level = nil
end

function Scope:clone(): Scope
   local new_scope = Scope:new()
   
   for k, v in pairs(self.user) do
      new_scope.user[k] = v
   end
   
   for k, v in pairs(self.tags) do
      new_scope.tags[k] = v
   end
   
   for k, v in pairs(self.extra) do
      new_scope.extra[k] = v
   end
   
   for k, v in pairs(self.contexts) do
      new_scope.contexts[k] = v
   end
   
   new_scope.level = self.level
   new_scope.max_breadcrumbs = self.max_breadcrumbs
   
   for i, breadcrumb in ipairs(self.breadcrumbs) do
      new_scope.breadcrumbs[i] = breadcrumb
   end
   
   return new_scope
end

-- Apply scope data to an event (used by Client when creating events)
function Scope:apply_to_event(event: table): table
   -- Apply user data
   if next(self.user) then
      event.user = event.user or {}
      for k, v in pairs(self.user) do
         event.user[k] = v
      end
   end
   
   -- Apply tags
   if next(self.tags) then
      event.tags = event.tags or {}
      for k, v in pairs(self.tags) do
         event.tags[k] = v
      end
   end
   
   -- Apply extra data
   if next(self.extra) then
      event.extra = event.extra or {}
      for k, v in pairs(self.extra) do
         event.extra[k] = v
      end
   end
   
   -- Apply contexts
   if next(self.contexts) then
      event.contexts = event.contexts or {}
      for k, v in pairs(self.contexts) do
         event.contexts[k] = v
      end
   end
   
   -- Apply breadcrumbs
   if #self.breadcrumbs > 0 then
      event.breadcrumbs = {}
      for i, breadcrumb in ipairs(self.breadcrumbs) do
         event.breadcrumbs[i] = breadcrumb
      end
   end
   
   -- Apply level if set on scope
   if self.level then
      event.level = self.level
   end
   
   return event
end

return Scope