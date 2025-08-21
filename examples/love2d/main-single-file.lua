-- Love2D Sentry Integration Example (Single File)
-- A simple app with Sentry logo and error button to demonstrate Sentry single-file SDK

-- Instead of copying the entire 'sentry' directory, you only need the single sentry.lua file
-- Copy build-single-file/sentry.lua to your Love2D project and require it
local sentry = require("sentry")

-- Game state
local game = {
    font_large = nil,
    font_small = nil,
    button_font = nil,
    
    -- Sentry logo data (simple representation)
    logo_points = {},
    
    -- Button state
    button = {
        x = 250,
        y = 400,
        width = 160,
        height = 60,
        text = "Trigger Error",
        hover = false,
        pressed = false
    },
    
    -- Fatal error button
    fatal_button = {
        x = 430,
        y = 400,
        width = 160,
        height = 60,
        text = "Fatal Error",
        hover = false,
        pressed = false
    },
    
    -- Error state
    error_count = 0,
    last_error_time = 0,
    
    -- Demo functions for stack trace
    demo_functions = {}
}

function love.load()
    -- Initialize window
    love.window.setTitle("Love2D Sentry Single-File Demo")
    love.window.setMode(800, 600, {resizable = false})
    
    -- Initialize Sentry with single-file SDK
    sentry.init({
        dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928", 
        environment = "love2d-demo",
        release = "love2d-single-file@1.0.0",
        debug = true
    })
    
    -- Set user context
    sentry.set_user({
        id = "love2d_user_" .. math.random(1000, 9999),
        username = "love2d_single_file_demo_user"
    })
    
    -- Add tags for filtering
    sentry.set_tag("framework", "love2d")
    sentry.set_tag("version", table.concat({love.getVersion()}, "."))
    sentry.set_tag("platform", love.system.getOS())
    sentry.set_tag("sdk_type", "single-file")
    
    -- Add extra context
    sentry.set_extra("love2d_info", {
        version = {love.getVersion()},
        os = love.system.getOS(),
        renderer = love.graphics.getRendererInfo()
    })
    
    -- Load fonts
    game.font_large = love.graphics.newFont(32)
    game.font_small = love.graphics.newFont(16)
    game.button_font = love.graphics.newFont(18)
    
    -- Create Sentry logo points (simple S shape)
    game.logo_points = {
        -- Top part of S
        {120, 100}, {180, 100}, {180, 130}, {150, 130}, {150, 150},
        {180, 150}, {180, 180}, {120, 180}, {120, 150}, {150, 150},
        -- Bottom part of S  
        {150, 170}, {120, 170}, {120, 200}, {180, 200}
    }
    
    -- Initialize demo functions for multi-frame stack traces
    game.demo_functions = {
        level1 = function(user_action, error_type)
            sentry.logger.info("Level 1: Processing user action " .. user_action)
            return game.demo_functions.level2(error_type, "processing")
        end,
        
        level2 = function(action_type, status)
            sentry.logger.debug("Level 2: Executing " .. action_type .. " with status " .. status)
            return game.demo_functions.level3(action_type)
        end,
        
        level3 = function(error_category)
            sentry.logger.warn("Level 3: About to trigger " .. error_category .. " error")
            return game.demo_functions.trigger_error(error_category)
        end,
        
        trigger_error = function(category)
            game.error_count = game.error_count + 1
            game.last_error_time = love.timer.getTime()
            
            -- Create realistic error scenarios
            if category == "button_click" then
                sentry.logger.error("Critical error in button handler")
                error("Love2DButtonError: Button click handler failed with code " .. math.random(1000, 9999))
            elseif category == "rendering" then
                sentry.logger.error("Graphics rendering failure")
                error("Love2DRenderError: Failed to render game object at frame " .. love.timer.getTime())
            else
                sentry.logger.error("Generic game error occurred")  
                error("Love2DGameError: Unexpected game state error in category " .. tostring(category))
            end
        end
    }
    
    -- Test all single-file SDK features
    print("🧪 Testing Single-File SDK Features:")
    
    -- Test logging functions
    sentry.logger.info("Love2D single-file demo initialized successfully")
    sentry.logger.info("Love2D version: " .. table.concat({love.getVersion()}, "."))
    sentry.logger.debug("Operating system: " .. love.system.getOS())
    
    -- Test tracing
    local transaction = sentry.start_transaction("love2d_initialization", "Initialize Love2D game")
    local span = transaction:start_span("load_assets", "Load game assets")
    -- Simulate some work
    love.timer.sleep(0.01)
    span:finish()
    transaction:finish()
    
    -- Add breadcrumb for debugging context
    sentry.add_breadcrumb({
        message = "Love2D single-file game initialized",
        category = "game_lifecycle",
        level = "info",
        data = {
            sdk_type = "single-file",
            features_tested = {"logging", "tracing", "breadcrumbs"}
        }
    })
    
    print("✅ Single-file SDK initialized and tested successfully!")
end

function love.update(dt)
    -- Get mouse position for button hover detection
    local mouse_x, mouse_y = love.mouse.getPosition()
    local button = game.button
    local fatal_button = game.fatal_button
    
    -- Check if mouse is over buttons
    local was_hover = button.hover
    button.hover = (mouse_x >= button.x and mouse_x <= button.x + button.width and
                   mouse_y >= button.y and mouse_y <= button.y + button.height)
    
    fatal_button.hover = (mouse_x >= fatal_button.x and mouse_x <= fatal_button.x + fatal_button.width and
                         mouse_y >= fatal_button.y and mouse_y <= fatal_button.y + fatal_button.height)
    
    -- Flush Sentry transport periodically
    sentry.flush()
end

function love.draw()
    -- Clear screen with dark background
    love.graphics.clear(0.1, 0.1, 0.15, 1.0)
    
    -- Draw title
    love.graphics.setFont(game.font_large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Love2D Sentry Single-File Demo", 0, 50, love.graphics.getWidth(), "center")
    
    -- Draw Sentry logo (simple S shape)
    love.graphics.setColor(0.4, 0.3, 0.8, 1) -- Purple color similar to Sentry
    love.graphics.setLineWidth(8)
    
    -- Draw S shape
    local logo_x, logo_y = 350, 120
    for i = 1, #game.logo_points - 1 do
        local x1, y1 = game.logo_points[i][1] + logo_x, game.logo_points[i][2] + logo_y
        local x2, y2 = game.logo_points[i + 1][1] + logo_x, game.logo_points[i + 1][2] + logo_y
        love.graphics.line(x1, y1, x2, y2)
    end
    
    -- Draw info text
    love.graphics.setFont(game.font_small)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Single-File SDK Demo - Only sentry.lua required!", 0, 280, love.graphics.getWidth(), "center")
    love.graphics.printf("Red: Regular error (caught) • Purple: Fatal error (love.errorhandler)", 0, 300, love.graphics.getWidth(), "center")
    love.graphics.printf("Press 'R' for regular error, 'F' for fatal error, 'L' for logger test, 'ESC' to exit", 0, 320, love.graphics.getWidth(), "center")
    
    -- Draw buttons
    draw_button(game.button)
    draw_button(game.fatal_button)
    
    -- Draw stats
    love.graphics.setFont(game.font_small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(string.format("Errors triggered: %d", game.error_count), 20, love.graphics.getHeight() - 80)
    love.graphics.print(string.format("Framework: Love2D %s", table.concat({love.getVersion()}, ".")), 20, love.graphics.getHeight() - 60)
    love.graphics.print(string.format("Platform: %s", love.system.getOS()), 20, love.graphics.getHeight() - 40)
    love.graphics.print("SDK: Single-File Distribution", 20, love.graphics.getHeight() - 20)
    
    if game.last_error_time > 0 then
        love.graphics.print(string.format("Last error: %.1fs ago", love.timer.getTime() - game.last_error_time), 400, love.graphics.getHeight() - 40)
    end
end

function draw_button(button_config)
    local button_color
    if button_config == game.button then
        button_color = button_config.hover and {0.8, 0.2, 0.2, 1} or {0.6, 0.1, 0.1, 1}
    else
        button_color = button_config.hover and {0.8, 0.2, 0.8, 1} or {0.6, 0.1, 0.6, 1}
    end
    
    if button_config.pressed then
        button_color = {1.0, 0.3, button_config == game.button and 0.3 or 1.0, 1}
    end
    
    love.graphics.setColor(button_color[1], button_color[2], button_color[3], button_color[4])
    love.graphics.rectangle("fill", button_config.x, button_config.y, button_config.width, button_config.height, 8, 8)
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button_config.x, button_config.y, button_config.width, button_config.height, 8, 8)
    
    -- Draw button text
    love.graphics.setFont(game.button_font)
    love.graphics.setColor(1, 1, 1, 1)
    local text_width = game.button_font:getWidth(button_config.text)
    local text_height = game.button_font:getHeight()
    love.graphics.print(button_config.text, 
                       button_config.x + (button_config.width - text_width) / 2,
                       button_config.y + (button_config.height - text_height) / 2)
end

function love.mousepressed(x, y, button_num, istouch, presses)
    if button_num == 1 then -- Left mouse button
        local button = game.button
        local fatal_button = game.fatal_button
        
        -- Check if click is within regular button bounds
        if x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height then
            
            button.pressed = true
            
            -- Add breadcrumb before triggering error
            sentry.add_breadcrumb({
                message = "Error button clicked",
                category = "user_interaction", 
                level = "info",
                data = {
                    mouse_x = x,
                    mouse_y = y,
                    error_count = game.error_count + 1,
                    sdk_type = "single-file"
                }
            })
            
            sentry.logger.info("Error button clicked at position (" .. x .. ", " .. y .. ")")
            
            -- Use xpcall to capture the error
            local function error_handler(err)
                sentry.logger.error("Button click error occurred: " .. tostring(err))
                
                sentry.capture_exception({
                    type = "Love2DUserTriggeredError",
                    message = tostring(err)
                })
                
                sentry.logger.info("Error captured and sent to Sentry")
                return err
            end
            
            -- Trigger error through multi-level function calls
            xpcall(function()
                game.demo_functions.level1("button_click", "button_click")
            end, error_handler)
            
        -- Check if click is within fatal button bounds
        elseif x >= fatal_button.x and x <= fatal_button.x + fatal_button.width and
               y >= fatal_button.y and y <= fatal_button.y + fatal_button.height then
            
            fatal_button.pressed = true
            
            -- Add breadcrumb before triggering fatal error
            sentry.add_breadcrumb({
                message = "Fatal error button clicked - will trigger love.errorhandler",
                category = "user_interaction", 
                level = "warning",
                data = {
                    mouse_x = x,
                    mouse_y = y,
                    test_type = "fatal_error",
                    sdk_type = "single-file"
                }
            })
            
            sentry.logger.info("Fatal error button clicked - this will crash the app...")
            
            -- Trigger a fatal error that will go through love.errorhandler
            error("Fatal Love2D error triggered by user - Testing single-file SDK with love.errorhandler!")
        end
    end
end

function love.mousereleased(x, y, button_num, istouch, presses)
    if button_num == 1 then
        game.button.pressed = false
        game.fatal_button.pressed = false
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- Clean shutdown with Sentry flush
        sentry.logger.info("Application shutting down")
        sentry.close()
        love.event.quit()
        
    elseif key == "r" then
        -- Trigger rendering error
        sentry.logger.info("Rendering error triggered via keyboard")
        
        sentry.add_breadcrumb({
            message = "Rendering error triggered via keyboard (R key)",
            category = "keyboard_interaction",
            level = "info",
            data = { sdk_type = "single-file" }
        })
        
        local function error_handler(err)
            sentry.capture_exception({
                type = "Love2DRenderingError",
                message = tostring(err)
            })
            return err
        end
        
        xpcall(function()
            game.demo_functions.level1("render_test", "rendering")
        end, error_handler)
        
    elseif key == "f" then
        -- Trigger fatal error via keyboard
        sentry.logger.info("Fatal error triggered via keyboard - will crash app")
        
        sentry.add_breadcrumb({
            message = "Fatal error triggered via keyboard (F key)",
            category = "keyboard_interaction", 
            level = "warning",
            data = {
                test_type = "fatal_error_keyboard",
                sdk_type = "single-file"
            }
        })
        
        -- This will go through love.errorhandler and crash the app
        error("Fatal Love2D error triggered by keyboard (F key) - Testing single-file SDK!")
        
    elseif key == "l" then
        -- Test all logger functions
        print("🧪 Testing logger functions...")
        sentry.logger.info("Info message from single-file SDK")
        sentry.logger.warn("Warning message from single-file SDK")  
        sentry.logger.error("Error message from single-file SDK")
        sentry.logger.debug("Debug message from single-file SDK")
        
        -- Test tracing
        local transaction = sentry.start_transaction("manual_test", "Manual tracing test")
        local span = transaction:start_span("test_operation", "Test span operation")
        love.timer.sleep(0.01) -- Simulate work
        span:finish()
        transaction:finish()
        
        print("✅ Logger and tracing tests completed!")
    end
end

function love.quit()
    -- Clean shutdown
    sentry.logger.info("Love2D single-file application quit")
    sentry.close()
    return false -- Allow quit to proceed
end