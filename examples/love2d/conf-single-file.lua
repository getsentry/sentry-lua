-- Love2D configuration for Sentry Single-File Demo
function love.conf(t)
    t.identity = "sentry-love2d-single-file"
    t.version = "11.4"
    t.console = false
    
    t.window.title = "Love2D Sentry Single-File Demo"
    t.window.icon = nil
    t.window.width = 800
    t.window.height = 600
    t.window.borderless = false
    t.window.resizable = false
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.display = 1
    t.window.highdpi = false
    t.window.x = nil
    t.window.y = nil
    
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
