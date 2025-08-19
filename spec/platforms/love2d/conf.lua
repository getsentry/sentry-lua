-- Minimal Love2D configuration for headless testing

function love.conf(t)
    t.identity = "sentry-love2d-tests"
    t.version = "11.5"
    t.console = false
    
    -- Minimal window for headless testing
    t.window.width = 200
    t.window.height = 100
    t.window.title = "Sentry Love2D Tests"
    t.window.resizable = false
    
    -- Enable only required modules
    t.modules.audio = false
    t.modules.data = false
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
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
    t.modules.window = true
end