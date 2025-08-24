-- Auto-setup when spec/ is required as a module
local info = debug.getinfo(2, "S") -- Use level 2 to get caller's info
if info and info.source and info.source:sub(1,1) == "@" then
    local current_file = info.source:sub(2)
    local current_dir = current_file:match("(.*/)")
    if current_dir then
        -- Find project root by looking for spec dir or assume current
        local project_root = current_dir:match("(.*/spec/)") or current_dir:match("(.*/src/)") or current_dir
        if project_root then
            project_root = project_root:gsub("spec/$", ""):gsub("src/$", "")
            local sentry_src = project_root .. "src/sentry/?.lua"
            local sentry_init = project_root .. "src/sentry/?/init.lua"
            if not package.path:find(sentry_src, 1, true) then
                package.path = sentry_src .. ";" .. sentry_init .. ";" .. package.path
            end
        end
    end
end