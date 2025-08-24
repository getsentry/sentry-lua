local Scope = {}
Scope.__index = Scope

Scope.user = {}
Scope.tags = {}
Scope.extra = {}
Scope.contexts = {}
Scope.breadcrumbs = {}

function Scope:new()
    print("scope:new")
    local scope = setmetatable({
        max_breadcrumbs = 100
    }, {__index = self})
    return scope
end

function Scope:clone()
    local new_scope = Scope:new()
    for k, v in pairs(self.user) do
        new_scope.user[k] = v
    end
    return new_scope
end

function Scope:add_breadcrumb(breadcrumb)
   local crumb = {
      -- TODO: os.time won't work on Roblox?
      -- timestamp = os.time(),
      message = breadcrumb.message or "",
      category = breadcrumb.category or "default",
      level = breadcrumb.level or "info",
      data = breadcrumb.data -- or {}
   }
   table.insert(self.breadcrumbs, crumb)

   while #self.breadcrumbs > self.max_breadcrumbs do
      table.remove(self.breadcrumbs, 1)
   end
end

return Scope