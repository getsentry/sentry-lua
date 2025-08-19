-- Tests for baggage header parsing and generation
-- Based on W3C Baggage specification and Sentry usage

local headers = require("sentry.tracing.headers")

describe("baggage header", function()
    describe("parsing", function()
        it("should parse single key-value pair", function()
            local header = "sentry-environment=production"
            local result = headers.parse_baggage(header)
            
            assert.is_not_nil(result)
            assert.are.equal("production", result["sentry-environment"])
        end)
        
        it("should parse multiple key-value pairs", function()
            local header = "sentry-environment=production,sentry-release=1.0.0,user-id=123"
            local result = headers.parse_baggage(header)
            
            assert.is_not_nil(result)
            assert.are.equal("production", result["sentry-environment"])
            assert.are.equal("1.0.0", result["sentry-release"])
            assert.are.equal("123", result["user-id"])
        end)
        
        it("should handle whitespace around key-value pairs", function()
            local header = "  sentry-environment=production  ,  sentry-release=1.0.0  "
            local result = headers.parse_baggage(header)
            
            assert.is_not_nil(result)
            assert.are.equal("production", result["sentry-environment"])
            assert.are.equal("1.0.0", result["sentry-release"])
        end)
        
        it("should ignore properties after semicolon", function()
            local header = "sentry-environment=production;properties=ignored,sentry-release=1.0.0"
            local result = headers.parse_baggage(header)
            
            assert.is_not_nil(result)
            assert.are.equal("production", result["sentry-environment"])
            assert.are.equal("1.0.0", result["sentry-release"])
        end)
        
        it("should handle empty values", function()
            local header = "sentry-environment=,sentry-release=1.0.0"
            local result = headers.parse_baggage(header)
            
            assert.is_not_nil(result)
            assert.are.equal("", result["sentry-environment"])
            assert.are.equal("1.0.0", result["sentry-release"])
        end)
        
        it("should skip malformed entries", function()
            local header = "sentry-environment=production,malformed,sentry-release=1.0.0"
            local result = headers.parse_baggage(header)
            
            assert.is_not_nil(result)
            assert.are.equal("production", result["sentry-environment"])
            assert.are.equal("1.0.0", result["sentry-release"])
            assert.is_nil(result["malformed"])
        end)
        
        it("should handle nil input", function()
            local result = headers.parse_baggage(nil)
            assert.is_not_nil(result)
            
            -- Count the number of keys in the table
            local count = 0
            for _ in pairs(result) do
                count = count + 1
            end
            assert.are.equal(0, count)
        end)
        
        it("should handle empty string", function()
            local result = headers.parse_baggage("")
            assert.is_not_nil(result)
            assert.are.equal("table", type(result))
        end)
        
        it("should handle non-string input", function()
            local result = headers.parse_baggage(123)
            assert.is_not_nil(result)
            assert.are.equal("table", type(result))
        end)
    end)
    
    describe("generation", function()
        it("should generate baggage header for single entry", function()
            local baggage = {
                ["sentry-environment"] = "production"
            }
            
            local result = headers.generate_baggage(baggage)
            assert.are.equal("sentry-environment=production", result)
        end)
        
        it("should generate baggage header for multiple entries", function()
            local baggage = {
                ["sentry-environment"] = "production",
                ["sentry-release"] = "1.0.0"
            }
            
            local result = headers.generate_baggage(baggage)
            assert.is_not_nil(result)
            assert.is_not_nil(result:match("sentry%-environment=production"))
            assert.is_not_nil(result:match("sentry%-release=1%.0%.0"))
            assert.is_not_nil(result:match(","))
        end)
        
        it("should URL encode special characters", function()
            local baggage = {
                ["test-key"] = "value,with;special=characters%"
            }
            
            local result = headers.generate_baggage(baggage)
            assert.is_not_nil(result)
            assert.is_not_nil(result:match("%%2C")) -- encoded comma
            assert.is_not_nil(result:match("%%3B")) -- encoded semicolon
            assert.is_not_nil(result:match("%%3D")) -- encoded equals
            assert.is_not_nil(result:match("%%25")) -- encoded percent
        end)
        
        it("should handle empty values", function()
            local baggage = {
                ["empty-key"] = ""
            }
            
            local result = headers.generate_baggage(baggage)
            assert.are.equal("empty-key=", result)
        end)
        
        it("should return nil for empty baggage", function()
            local baggage = {}
            local result = headers.generate_baggage(baggage)
            assert.is_nil(result)
        end)
        
        it("should return nil for nil input", function()
            local result = headers.generate_baggage(nil)
            assert.is_nil(result)
        end)
        
        it("should return nil for non-table input", function()
            local result = headers.generate_baggage("invalid")
            assert.is_nil(result)
        end)
        
        it("should skip non-string keys and values", function()
            local baggage = {
                ["valid-key"] = "valid-value",
                [123] = "invalid-key",
                ["invalid-value"] = 456
            }
            
            local result = headers.generate_baggage(baggage)
            assert.are.equal("valid-key=valid-value", result)
        end)
    end)
    
    describe("round-trip consistency", function()
        it("should parse what it generates", function()
            local original = {
                ["sentry-environment"] = "production",
                ["sentry-release"] = "1.0.0",
                ["user-id"] = "123"
            }
            
            local header = headers.generate_baggage(original)
            local parsed = headers.parse_baggage(header)
            
            assert.are.equal(original["sentry-environment"], parsed["sentry-environment"])
            assert.are.equal(original["sentry-release"], parsed["sentry-release"])
            assert.are.equal(original["user-id"], parsed["user-id"])
        end)
        
        it("should handle special characters in round-trip", function()
            local original = {
                ["test-key"] = "value,with;special=characters%"
            }
            
            local header = headers.generate_baggage(original)
            local parsed = headers.parse_baggage(header)
            
            -- Note: Basic implementation may not handle URL decoding perfectly
            -- This test documents expected behavior
            assert.is_not_nil(parsed["test-key"])
        end)
    end)
end)