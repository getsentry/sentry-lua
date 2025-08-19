-- Love2D platform unit tests
-- These run with busted but mock the Love2D environment

describe("sentry.platforms.love2d", function()
    
    -- Mock Love2D environment
    local original_love
    
    before_each(function()
        original_love = _G.love
        
        -- Mock Love2D global
        _G.love = {
            system = {
                getOS = function() return "macOS" end
            },
            getVersion = function() return 11, 5, 0, "Mysterious Mysteries" end,
            graphics = {
                getDimensions = function() return 800, 600 end
            },
            thread = {
                newThread = function(code)
                    return {
                        start = function() end,
                        wait = function() end
                    }
                end,
                getChannel = function(name)
                    return {
                        push = function() end,
                        pop = function() return nil end
                    }
                end
            },
            filesystem = {
                append = function() return true end
            },
            timer = {
                sleep = function() end,
                getTime = function() return 0 end
            }
        }
    end)
    
    after_each(function()
        _G.love = original_love
    end)
    
    describe("transport", function()
        local transport_module
        
        before_each(function()
            package.loaded["sentry.platforms.love2d.transport"] = nil
            transport_module = require("sentry.platforms.love2d.transport")
        end)
        
        it("should detect Love2D availability", function()
            assert.is_true(transport_module.is_love2d_available())
        end)
        
        it("should create Love2D transport", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            assert.is_not_nil(transport)
            assert.is_function(transport.send)
        end)
        
        it("should queue events for async sending", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            local success, message = transport:send({event_id = "test123"})
            
            assert.is_true(success)
            assert.matches("queued", message)
        end)
        
        it("should queue envelopes for async sending", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            local success, message = transport:send_envelope("test envelope data")
            
            assert.is_true(success)
            assert.matches("queued", message)
        end)
        
        it("should handle flush operation", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            
            -- Should not error
            assert.has_no.errors(function()
                transport:flush()
            end)
        end)
        
        it("should queue events but not process them without lua-https", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            
            -- Queue some events
            local test_event = {event_id = "test123", message = "test message"}
            transport:send(test_event)
            
            -- Verify event was queued
            assert.equals(1, #transport.event_queue)
            
            -- Flush should return early without lua-https, leaving queues intact
            transport:flush()
            
            -- Queue should still have items since lua-https is not available
            assert.equals(1, #transport.event_queue)
        end)
        
        it("should queue envelopes but not process them without lua-https", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            
            -- Queue some envelopes
            local test_envelope = "test envelope data"
            transport:send_envelope(test_envelope)
            
            -- Verify envelope was queued
            assert.equals(1, #transport.envelope_queue)
            
            -- Flush should return early without lua-https, leaving queues intact
            transport:flush()
            
            -- Queue should still have items since lua-https is not available
            assert.equals(1, #transport.envelope_queue)
        end)
        
        it("should manage both event and envelope queues independently", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            
            -- Queue multiple items
            transport:send({event_id = "event1"})
            transport:send({event_id = "event2"})
            transport:send_envelope("envelope1")
            transport:send_envelope("envelope2")
            
            -- Verify items were queued
            assert.equals(2, #transport.event_queue)
            assert.equals(2, #transport.envelope_queue)
            
            -- Without lua-https, flush returns early and queues remain
            transport:flush()
            
            -- Both queues should still have items
            assert.equals(2, #transport.event_queue)
            assert.equals(2, #transport.envelope_queue)
        end)
        
        it("should handle close operation", function()
            local config = {
                dsn = "https://key@host/123"
            }
            
            local transport = transport_module.create_love2d_transport(config)
            
            -- Should not error
            assert.has_no.errors(function()
                transport:close()
            end)
        end)
    end)
    
    describe("os_detection", function()
        local os_detection
        
        before_each(function()
            package.loaded["sentry.platforms.love2d.os_detection"] = nil
            os_detection = require("sentry.platforms.love2d.os_detection")
        end)
        
        it("should detect OS from Love2D", function()
            local os_info = os_detection.detect_os()
            assert.is_not_nil(os_info)
            assert.equals("macOS", os_info.name)
            assert.is_nil(os_info.version) -- Love2D doesn't provide version
        end)
    end)
    
    describe("context", function()
        local context_module
        
        before_each(function()
            package.loaded["sentry.platforms.love2d.context"] = nil
            context_module = require("sentry.platforms.love2d.context")
        end)
        
        it("should get Love2D context information", function()
            local context = context_module.get_love2d_context()
            
            assert.is_table(context)
            assert.equals("11.5.0.Mysterious Mysteries", context.love_version)
            assert.equals("macOS", context.os)
            assert.is_table(context.screen)
            assert.equals(800, context.screen.width)
            assert.equals(600, context.screen.height)
        end)
        
        it("should handle missing Love2D gracefully", function()
            _G.love = nil
            
            local context = context_module.get_love2d_context()
            assert.is_table(context)
            -- Should be empty but not error
        end)
    end)
    
    describe("integration", function()
        it("should work with main Sentry SDK", function()
            local sentry = require("sentry")
            
            -- Initialize with Love2D transport
            sentry.init({
                dsn = "https://key@host/123",
                environment = "test"
            })
            
            assert.is_not_nil(sentry._client)
            assert.is_not_nil(sentry._client.transport)
            
            -- Should be able to capture events
            local event_id = sentry.capture_message("Test message")
            assert.is_string(event_id)
            assert.not_equals("", event_id)
        end)
        
        it("should work with logger module", function()
            local sentry = require("sentry")
            local logger = require("sentry.logger")
            
            sentry.init({
                dsn = "https://key@host/123"
            })
            
            logger.init({
                enable_logs = true,
                max_buffer_size = 1
            })
            
            -- Should not error
            assert.has_no.errors(function()
                logger.info("Test log from Love2D")
                logger.flush()
            end)
        end)
    end)
    
    describe("without Love2D", function()
        before_each(function()
            _G.love = nil
        end)
        
        it("should not be available", function()
            package.loaded["sentry.platforms.love2d.transport"] = nil
            local transport_module = require("sentry.platforms.love2d.transport")
            assert.is_false(transport_module.is_love2d_available())
        end)
        
        it("should return empty OS detection", function()
            package.loaded["sentry.platforms.love2d.os_detection"] = nil
            local os_detection = require("sentry.platforms.love2d.os_detection")
            local os_info = os_detection.detect_os()
            assert.is_nil(os_info)
        end)
    end)
end)