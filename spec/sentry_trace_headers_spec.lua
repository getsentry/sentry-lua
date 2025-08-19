-- Tests for Sentry trace header parsing and generation
-- Based on Sentry distributed tracing specification

local headers = require("sentry.tracing.headers")

describe("sentry-trace header", function()
    describe("parsing", function()
        it("should parse valid header with trace_id and span_id only", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000"
            local result = headers.parse_sentry_trace(header)
            
            assert.is_not_nil(result)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", result.trace_id)
            assert.are.equal("1000000000000000", result.span_id)
            assert.is_nil(result.sampled)
        end)
        
        it("should parse valid header with sampled=1", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1"
            local result = headers.parse_sentry_trace(header)
            
            assert.is_not_nil(result)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", result.trace_id)
            assert.are.equal("1000000000000000", result.span_id)
            assert.is_true(result.sampled)
        end)
        
        it("should parse valid header with sampled=0", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-0"
            local result = headers.parse_sentry_trace(header)
            
            assert.is_not_nil(result)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", result.trace_id)
            assert.are.equal("1000000000000000", result.span_id)
            assert.is_false(result.sampled)
        end)
        
        it("should normalize trace_id and span_id to lowercase", function()
            local header = "75302AC48A024BDE9A3B3734A82E36C8-1000000000000000-1"
            local result = headers.parse_sentry_trace(header)
            
            assert.is_not_nil(result)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", result.trace_id)
            assert.are.equal("1000000000000000", result.span_id)
        end)
        
        it("should handle whitespace around header value", function()
            local header = "  75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1  "
            local result = headers.parse_sentry_trace(header)
            
            assert.is_not_nil(result)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", result.trace_id)
            assert.are.equal("1000000000000000", result.span_id)
            assert.is_true(result.sampled)
        end)
        
        it("should ignore invalid sampled values and defer sampling", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-invalid"
            local result = headers.parse_sentry_trace(header)
            
            assert.is_not_nil(result)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", result.trace_id)
            assert.are.equal("1000000000000000", result.span_id)
            assert.is_nil(result.sampled) -- Deferred sampling
        end)
        
        -- Invalid header tests
        it("should return nil for nil input", function()
            local result = headers.parse_sentry_trace(nil)
            assert.is_nil(result)
        end)
        
        it("should return nil for empty string", function()
            local result = headers.parse_sentry_trace("")
            assert.is_nil(result)
        end)
        
        it("should return nil for whitespace only", function()
            local result = headers.parse_sentry_trace("   ")
            assert.is_nil(result)
        end)
        
        it("should return nil for non-string input", function()
            local result = headers.parse_sentry_trace(123)
            assert.is_nil(result)
        end)
        
        it("should return nil for header with missing span_id", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
        
        it("should return nil for trace_id that is too short", function()
            local header = "75302ac48a024bde-1000000000000000"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
        
        it("should return nil for trace_id that is too long", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8ab-1000000000000000"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
        
        it("should return nil for span_id that is too short", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-10000000000000"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
        
        it("should return nil for span_id that is too long", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000ab"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
        
        it("should return nil for non-hex characters in trace_id", function()
            local header = "75302ac48a024bdg9a3b3734a82e36c8-1000000000000000"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
        
        it("should return nil for non-hex characters in span_id", function()
            local header = "75302ac48a024bde9a3b3734a82e36c8-1000000000000g00"
            local result = headers.parse_sentry_trace(header)
            assert.is_nil(result)
        end)
    end)
    
    describe("generation", function()
        it("should generate valid sentry-trace header without sampled flag", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8-1000000000000000", result)
        end)
        
        it("should generate valid sentry-trace header with sampled=true", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000",
                sampled = true
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1", result)
        end)
        
        it("should generate valid sentry-trace header with sampled=false", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000",
                sampled = false
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8-1000000000000000-0", result)
        end)
        
        it("should normalize trace_id to lowercase", function()
            local trace_data = {
                trace_id = "75302AC48A024BDE9A3B3734A82E36C8",
                span_id = "1000000000000000"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8-1000000000000000", result)
        end)
        
        it("should normalize span_id to lowercase", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000ABC"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8-1000000000000abc", result)
        end)
        
        it("should omit sampled flag when sampled is nil", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000",
                sampled = nil
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8-1000000000000000", result)
        end)
        
        -- Error cases
        it("should return nil for nil input", function()
            local result = headers.generate_sentry_trace(nil)
            assert.is_nil(result)
        end)
        
        it("should return nil for non-table input", function()
            local result = headers.generate_sentry_trace("invalid")
            assert.is_nil(result)
        end)
        
        it("should return nil for missing trace_id", function()
            local trace_data = {
                span_id = "1000000000000000"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.is_nil(result)
        end)
        
        it("should return nil for missing span_id", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.is_nil(result)
        end)
        
        it("should return nil for invalid trace_id length", function()
            local trace_data = {
                trace_id = "75302ac48a024bde",
                span_id = "1000000000000000"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.is_nil(result)
        end)
        
        it("should return nil for invalid span_id length", function()
            local trace_data = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000"
            }
            
            local result = headers.generate_sentry_trace(trace_data)
            assert.is_nil(result)
        end)
    end)
    
    describe("round-trip consistency", function()
        it("should parse what it generates", function()
            local original = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000",
                sampled = true
            }
            
            local header = headers.generate_sentry_trace(original)
            local parsed = headers.parse_sentry_trace(header)
            
            assert.are.equal(original.trace_id, parsed.trace_id)
            assert.are.equal(original.span_id, parsed.span_id)
            assert.are.equal(original.sampled, parsed.sampled)
        end)
        
        it("should handle deferred sampling in round-trip", function()
            local original = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000"
                -- sampled is nil (deferred)
            }
            
            local header = headers.generate_sentry_trace(original)
            local parsed = headers.parse_sentry_trace(header)
            
            assert.are.equal(original.trace_id, parsed.trace_id)
            assert.are.equal(original.span_id, parsed.span_id)
            assert.is_nil(parsed.sampled)
        end)
    end)
end)