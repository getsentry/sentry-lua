-- Auto-setup when required - no function call needed
local info = debug.getinfo(2, "S") -- Use level 2 to get caller's info
if info and info.source and info.source:sub(1,1) == "@" then
    local current_file = info.source:sub(2)
    local current_dir = current_file:match("(.*/)")
    if current_dir then
        -- Find project root by looking for spec dir or assume current
        local project_root = current_dir:match("(.*/spec/)")
        if project_root then
            project_root = project_root:sub(1, -6) -- Remove "spec/"
        else
            project_root = current_dir
        end
        
        -- Add spec and src paths
        local spec_path = project_root .. "spec/?.lua"
        local sentry_src = project_root .. "src/sentry/?.lua"
        local sentry_init = project_root .. "src/sentry/?/init.lua"
        
        if not package.path:find(spec_path, 1, true) then
            package.path = spec_path .. ";" .. package.path
        end
        if not package.path:find(sentry_src, 1, true) then
            package.path = sentry_src .. ";" .. sentry_init .. ";" .. package.path
        end
    end
end