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
   fingerprint: {string}
   attachments: {table}
end

function Scope:new(): Scope
   return setmetatable({
      user = {},
      tags = {},
      extra = {},
      contexts = {},
      breadcrumbs = {},
      max_breadcrumbs = 100,
      level = nil,  -- nil means inherit from client/event
      fingerprint = nil,
      attachments = {}
   }, {__index = Scope}) as Scope
end

function Scope:add_attachment(attachment: table)
   self.attachments = self.attachments or {}
   table.insert(self.attachments, attachment)
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

function Scope:set_fingerprint(fingerprint: {string})
   self.fingerprint = fingerprint
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

   if self.fingerprint then
      new_scope.fingerprint = {}
      for i, fp in ipairs(self.fingerprint) do
         new_scope.fingerprint[i] = fp
      end
   end

   for i, breadcrumb in ipairs(self.breadcrumbs) do
      new_scope.breadcrumbs[i] = breadcrumb
   end

   if self.attachments then
      new_scope.attachments = {}
      for i, att in ipairs(self.attachments) do
         new_scope.attachments[i] = att
      end
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
   
   -- Append breadcrumbs (so merging global -> isolation -> current accumulates
   -- rather than overwriting). Trace context is applied by the client, not here.
   if #self.breadcrumbs > 0 then
      event.breadcrumbs = event.breadcrumbs or {}
      for _, breadcrumb in ipairs(self.breadcrumbs) do
         table.insert(event.breadcrumbs, breadcrumb)
      end
   end

   -- Apply level if set on scope
   if self.level then
      event.level = self.level
   end

   -- Apply fingerprint if set
   if self.fingerprint and #self.fingerprint > 0 then
      event.fingerprint = self.fingerprint
   end

   return event
end

return Scope