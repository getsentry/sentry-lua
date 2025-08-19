-- Love2D Sentry Integration Example
-- A simple app with Sentry logo and error button to demonstrate Sentry SDK

-- Add build path for modules
package.path = "../../build/?.lua;../../build/?/init.lua;" .. package.path

local sentry = require("sentry")
local logger = require("sentry.logger")

-- Game state
local game = {
    font_large = nil,
    font_small = nil,
    button_font = nil,
    
    -- Sentry logo data (simple representation)
    logo_points = {},
    
    -- Button state
    button = {
        x = 300,
        y = 400,
        width = 200,
        height = 60,
        text = "Trigger Error",
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
    love.window.setTitle("Love2D Sentry Integration Demo")
    love.window.setMode(800, 600, {resizable = false})
    
    -- Initialize Sentry
    sentry.init({
        dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
        environment = "love2d-demo",
        release = "love2d-example@1.0.0",
        debug = true
    })
    
    -- Initialize logger  
    logger.init({
        enable_logs = true,
        max_buffer_size = 5,
        flush_timeout = 2.0,
        hook_print = true
    })
    
    -- Set user context
    sentry.set_user({
        id = "love2d_user_" .. math.random(1000, 9999),
        username = "love2d_demo_user"
    })
    
    -- Add tags for filtering
    sentry.set_tag("framework", "love2d")
    sentry.set_tag("version", table.concat({love.getVersion()}, "."))
    sentry.set_tag("platform", love.system.getOS())
    
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
            logger.info("Level 1: Processing user action %s", {user_action})
            return game.demo_functions.level2(error_type, "processing")
        end,
        
        level2 = function(action_type, status)
            logger.debug("Level 2: Executing %s with status %s", {action_type, status})
            return game.demo_functions.level3(action_type)
        end,
        
        level3 = function(error_category)
            logger.warn("Level 3: About to trigger %s error", {error_category})
            return game.demo_functions.trigger_error(error_category)
        end,
        
        trigger_error = function(category)
            game.error_count = game.error_count + 1
            game.last_error_time = love.timer.getTime()
            
            -- Create realistic error scenarios
            if category == "button_click" then
                logger.error("Critical error in button handler")
                error("Love2DButtonError: Button click handler failed with code " .. math.random(1000, 9999))
            elseif category == "rendering" then
                logger.error("Graphics rendering failure")
                error("Love2DRenderError: Failed to render game object at frame " .. love.timer.getTime())
            else
                logger.error("Generic game error occurred")  
                error("Love2DGameError: Unexpected game state error in category " .. tostring(category))
            end
        end
    }
    
    -- Log successful initialization
    logger.info("Love2D Sentry demo initialized successfully")
    logger.info("Love2D version: %s", {table.concat({love.getVersion()}, ".")})
    logger.info("Operating system: %s", {love.system.getOS()})
    
    -- Add breadcrumb for debugging context
    sentry.add_breadcrumb({
        message = "Love2D game initialized",
        category = "game_lifecycle",
        level = "info"
    })
end

function love.update(dt)
    -- Get mouse position for button hover detection
    local mouse_x, mouse_y = love.mouse.getPosition()
    local button = game.button
    
    -- Check if mouse is over button
    local was_hover = button.hover
    button.hover = (mouse_x >= button.x and mouse_x <= button.x + button.width and
                   mouse_y >= button.y and mouse_y <= button.y + button.height)
    
    -- Log hover state changes
    if button.hover and not was_hover then
        logger.debug("Button hover state: entered")
    elseif not button.hover and was_hover then
        logger.debug("Button hover state: exited")  
    end
    
    -- Flush Sentry transport periodically
    if sentry._client and sentry._client.transport and sentry._client.transport.flush then
        sentry._client.transport:flush()
    end
    
    -- Flush logger periodically
    if math.floor(love.timer.getTime()) % 3 == 0 then
        logger.flush()
    end
end

function love.draw()
    -- Clear screen with dark background
    love.graphics.clear(0.1, 0.1, 0.15, 1.0)
    
    -- Draw title
    love.graphics.setFont(game.font_large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Love2D Sentry Integration", 0, 50, love.graphics.getWidth(), "center")
    
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
    love.graphics.printf("This demo shows Love2D integration with Sentry SDK", 0, 280, love.graphics.getWidth(), "center")
    love.graphics.printf("Click the button to trigger an error with multi-frame stack trace", 0, 300, love.graphics.getWidth(), "center")
    
    -- Draw button
    local button = game.button
    local button_color = button.hover and {0.8, 0.2, 0.2, 1} or {0.6, 0.1, 0.1, 1}
    if button.pressed then
        button_color = {1.0, 0.3, 0.3, 1}
    end
    
    love.graphics.setColor(button_color[1], button_color[2], button_color[3], button_color[4])
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 8, 8)
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 8, 8)
    
    -- Draw button text
    love.graphics.setFont(game.button_font)
    love.graphics.setColor(1, 1, 1, 1)
    local text_width = game.button_font:getWidth(button.text)
    local text_height = game.button_font:getHeight()
    love.graphics.print(button.text, 
                       button.x + (button.width - text_width) / 2,
                       button.y + (button.height - text_height) / 2)
    
    -- Draw stats
    love.graphics.setFont(game.font_small)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(string.format("Errors triggered: %d", game.error_count), 20, love.graphics.getHeight() - 60)
    love.graphics.print(string.format("Framework: Love2D %s", table.concat({love.getVersion()}, ".")), 20, love.graphics.getHeight() - 40)
    love.graphics.print(string.format("Platform: %s", love.system.getOS()), 20, love.graphics.getHeight() - 20)
    
    if game.last_error_time > 0 then
        love.graphics.print(string.format("Last error: %.1fs ago", love.timer.getTime() - game.last_error_time), 400, love.graphics.getHeight() - 40)
    end
end

function love.mousepressed(x, y, button_num, istouch, presses)
    if button_num == 1 then -- Left mouse button
        local button = game.button
        
        -- Check if click is within button bounds
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
                    error_count = game.error_count + 1
                }
            })
            
            -- Log the button click
            logger.info("Error button clicked at position (%s, %s)", {x, y})
            logger.info("Preparing to trigger multi-frame error...")
            
            -- Use xpcall to capture the error with original stack trace
            local function error_handler(err)
                logger.error("Button click error occurred: %s", {tostring(err)})
                
                sentry.capture_exception({
                    type = "Love2DUserTriggeredError",
                    message = tostring(err)
                })
                
                logger.info("Error captured and sent to Sentry")
                return err
            end
            
            -- Trigger error through multi-level function calls
            xpcall(function()
                game.demo_functions.level1("button_click", "button_click")
            end, error_handler)
        end
    end
end

function love.mousereleased(x, y, button_num, istouch, presses)
    if button_num == 1 then
        game.button.pressed = false
    end
end

function love.keypressed(key)
    if key == "escape" then
        -- Clean shutdown with Sentry flush
        logger.info("Application shutting down")
        logger.flush()
        
        if sentry._client and sentry._client.transport and sentry._client.transport.close then
            sentry._client.transport:close()
        end
        
        love.event.quit()
    elseif key == "r" then
        -- Trigger rendering error
        logger.info("Rendering error triggered via keyboard")
        
        sentry.add_breadcrumb({
            message = "Rendering error triggered",
            category = "keyboard_interaction",
            level = "info"
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
    end
end

function love.quit()
    -- Clean shutdown
    logger.info("Love2D application quit")
    logger.flush()
    
    if sentry._client and sentry._client.transport and sentry._client.transport.close then
        sentry._client.transport:close()
    end
    
    return false -- Allow quit to proceed
end