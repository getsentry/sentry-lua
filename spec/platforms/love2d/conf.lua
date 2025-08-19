-- Minimal Love2D configuration for headless testing

function love.conf(t)
    t.identity = "sentry-love2d-tests"
    t.version = "11.5"
    t.console = false
    
    -- Minimal headless window configuration
    -- Note: t.window = false doesn't work reliably across all Love2D versions
    -- Instead use minimal window config that works in headless environments
    t.window.title = "Sentry Love2D Tests (Headless)"
    t.window.width = 1
    t.window.height = 1
    t.window.borderless = true
    t.window.resizable = false
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.vsync = 0
    t.window.display = 1
    t.window.highdpi = false
    t.window.x = nil
    t.window.y = nil
    
    -- Disable all non-essential modules for headless testing
    t.modules.audio = false
    t.modules.data = false
    t.modules.event = true
    t.modules.font = false
    t.modules.graphics = true  -- Keep minimal graphics for headless compatibility
    t.modules.image = false
    t.modules.joystick = false
    t.modules.keyboard = false
    t.modules.math = false
    t.modules.mouse = false
    t.modules.physics = false
    t.modules.sound = false
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true  -- Keep window module for headless compatibility
end