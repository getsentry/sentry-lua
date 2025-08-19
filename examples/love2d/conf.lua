-- Love2D configuration for Sentry demo

function love.conf(t)
    t.identity = "sentry-love2d-demo"        -- Save directory name
    t.appendidentity = false                 -- Search files in source directory before save directory
    t.version = "11.5"                      -- LÖVE version this game was made for
    t.console = false                       -- Attach a console (Windows only)
    t.accelerometerjoystick = false         -- Enable accelerometer on mobile devices
    t.externalstorage = false               -- True to save files outside of the app folder
    t.gammacorrect = false                  -- Enable gamma-correct rendering
    
    t.audio.mic = false                     -- Request microphone permission
    t.audio.mixwithsystem = true           -- Keep background music playing
    
    t.window.title = "Love2D Sentry Integration Demo"
    t.window.icon = nil                     -- Icon file path
    t.window.width = 800                    -- Window width
    t.window.height = 600                   -- Window height
    t.window.borderless = false             -- Remove window border
    t.window.resizable = false              -- Allow window resizing
    t.window.minwidth = 1                   -- Minimum window width
    t.window.minheight = 1                  -- Minimum window height
    t.window.fullscreen = false             -- Enable fullscreen
    t.window.fullscreentype = "desktop"     -- Choose desktop or exclusive fullscreen
    t.window.vsync = 1                      -- Vertical sync mode (0=off, 1=on, -1=adaptive)
    t.window.msaa = 0                       -- MSAA samples
    t.window.depth = nil                    -- Depth buffer bit depth
    t.window.stencil = nil                  -- Stencil buffer bit depth
    t.window.display = 1                    -- Monitor to display window on
    t.window.highdpi = false                -- Enable high-dpi mode
    t.window.usedpiscale = true             -- Enable automatic DPI scaling
    t.window.x = nil                        -- Window position x-coordinate
    t.window.y = nil                        -- Window position y-coordinate
    
    -- Disable unused modules for faster startup and smaller memory footprint
    t.modules.audio = true                  -- Enable audio module
    t.modules.data = false                  -- Enable data module  
    t.modules.event = true                  -- Enable event module
    t.modules.font = true                   -- Enable font module
    t.modules.graphics = true               -- Enable graphics module
    t.modules.image = false                 -- Enable image module
    t.modules.joystick = false              -- Enable joystick module
    t.modules.keyboard = true               -- Enable keyboard module
    t.modules.math = false                  -- Enable math module
    t.modules.mouse = true                  -- Enable mouse module
    t.modules.physics = false               -- Enable physics (Box2D) module
    t.modules.sound = false                 -- Enable sound module
    t.modules.system = true                 -- Enable system module
    t.modules.thread = true                 -- Enable thread module (needed for HTTP requests)
    t.modules.timer = true                  -- Enable timer module
    t.modules.touch = false                 -- Enable touch module
    t.modules.video = false                 -- Enable video module
    t.modules.window = true                 -- Enable window module
end