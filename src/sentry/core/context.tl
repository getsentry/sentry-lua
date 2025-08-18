local record Context
   user: table
   tags: {string: string}
   extra: {string: any}
   level: string
   environment: string
   release: string
   breadcrumbs: {table}
   max_breadcrumbs: number
   contexts: {string: any}  -- For runtime, os, device contexts
end

function Context:new(): Context
   return setmetatable({
      user = {},
      tags = {},
      extra = {},
      level = "error",
      environment = "production",
      release = nil,
      breadcrumbs = {},
      max_breadcrumbs = 100,
      contexts = {}
   }, {__index = Context}) as Context
end

function Context:set_user(user: table)
   self.user = user or {}
end

function Context:set_tag(key: string, value: string)
   self.tags[key] = value
end

function Context:set_extra(key: string, value: any)
   self.extra[key] = value
end

function Context:set_context(key: string, value: any)
   self.contexts[key] = value
end

function Context:set_level(level: string)
   local valid_levels: {string: boolean} = {debug = true, info = true, warning = true, error = true, fatal = true}
   if valid_levels[level] then
      self.level = level
   end
end

function Context:add_breadcrumb(breadcrumb: table)
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

function Context:clear()
   self.user = {}
   self.tags = {}
   self.extra = {}
   self.breadcrumbs = {}
   self.contexts = {}
end

function Context:clone(): Context
   local new_context = Context:new()
   
   for k, v in pairs(self.user) do
      new_context.user[k] = v
   end
   
   for k, v in pairs(self.tags) do
      new_context.tags[k] = v
   end
   
   for k, v in pairs(self.extra) do
      new_context.extra[k] = v
   end
   
   for k, v in pairs(self.contexts) do
      new_context.contexts[k] = v
   end
   
   new_context.level = self.level
   new_context.environment = self.environment
   new_context.release = self.release
   
   for i, breadcrumb in ipairs(self.breadcrumbs) do
      new_context.breadcrumbs[i] = breadcrumb
   end
   
   return new_context
end

return Context