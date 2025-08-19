-- Love2D HTTPS connectivity and lua-https integration tests
describe("Love2D HTTPS connectivity", function()
    local sentry
    local http
    
    setup(function()
        -- Mock Love2D environment
        _G.love = {
            filesystem = {
                write = function(filename, data)
                    return true
                end
            }
        }
        
        package.path = "build/?.lua;build/?/init.lua;" .. package.path
        sentry = require("sentry")
        http = require("sentry.utils.http")
    end)
    
    teardown(function()
        _G.love = nil
    end)
    
    describe("HTTP client functionality", function()
        it("should successfully make HTTPS requests to test endpoints", function()
            local response = http.request({
                url = "https://httpbin.org/get",
                method = "GET",
                timeout = 10
            })
            
            assert.is_true(response.success)
            assert.equals(200, response.status)
        end)
        
        it("should handle HTTPS request failures gracefully", function()
            local response = http.request({
                url = "https://nonexistent-domain-for-testing.com/endpoint",
                method = "GET", 
                timeout = 5
            })
            
            assert.is_false(response.success)
            assert.is_not_nil(response.error)
        end)
    end)
    
    describe("Sentry integration", function()
        it("should initialize successfully in Love2D environment", function()
            local result = sentry.init({
                dsn = "https://testkey@test.ingest.sentry.io/123456",
                environment = "love2d-test",
                debug = true
            })
            
            assert.is_not_nil(sentry._client)
        end)
        
        it("should capture messages with proper error handling", function() 
            sentry.init({
                dsn = "https://testkey@test.ingest.sentry.io/123456",
                environment = "love2d-spec-test"
            })
            
            -- Should not throw errors even with invalid DSN in test
            local ok = pcall(function()
                sentry.capture_message("Test message from Love2D spec", "info")
            end)
            
            assert.is_true(ok)
        end)
        
        it("should capture exceptions with stack traces", function()
            sentry.init({
                dsn = "https://testkey@test.ingest.sentry.io/123456", 
                environment = "love2d-spec-test"
            })
            
            local function level3()
                error("Test error for stack trace validation")
            end
            
            local function level2()
                level3()
            end
            
            local function level1() 
                level2()
            end
            
            -- Should capture exception without crashing
            local ok, err = pcall(level1)
            assert.is_false(ok)
            
            local capture_ok = pcall(function()
                sentry.capture_exception(err)
            end)
            
            assert.is_true(capture_ok)
        end)
    end)
    
    describe("Love2D transport selection", function()
        it("should detect Love2D environment properly", function()
            local love2d_transport = require("sentry.platforms.love2d.transport")
            
            -- Should detect Love2D environment when love global exists
            assert.is_true(love2d_transport.is_love2d_available())
            
            -- Should be able to create transport
            local transport = love2d_transport.create_love2d_transport({
                dsn = "https://testkey@test.ingest.sentry.io/123456"
            })
            
            assert.is_not_nil(transport)
        end)
    end)
end)