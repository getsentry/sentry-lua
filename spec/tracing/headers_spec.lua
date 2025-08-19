local headers = require("sentry.tracing.headers")

describe("sentry.tracing.headers", function()
    describe("parse_sentry_trace", function()
        it("should parse valid sentry-trace header", function()
            local trace_data = headers.parse_sentry_trace("1234567890abcdef1234567890abcdef-1234567890abcdef-1")
            
            assert.is_not_nil(trace_data)
            assert.equal("1234567890abcdef1234567890abcdef", trace_data.trace_id)
            assert.equal("1234567890abcdef", trace_data.span_id)
            assert.equal(true, trace_data.sampled)
        end)
        
        it("should parse valid sentry-trace header without sampled flag", function()
            local trace_data = headers.parse_sentry_trace("abcdef1234567890abcdef1234567890-abcdef1234567890")
            
            assert.is_not_nil(trace_data)
            assert.equal("abcdef1234567890abcdef1234567890", trace_data.trace_id)
            assert.equal("abcdef1234567890", trace_data.span_id)
            assert.is_nil(trace_data.sampled)
        end)
        
        it("should parse sampled=0 as false", function()
            local trace_data = headers.parse_sentry_trace("1234567890abcdef1234567890abcdef-1234567890abcdef-0")
            
            assert.is_not_nil(trace_data)
            assert.equal(false, trace_data.sampled)
        end)
        
        it("should normalize trace_id and span_id to lowercase", function()
            local trace_data = headers.parse_sentry_trace("ABCDEF1234567890ABCDEF1234567890-ABCDEF1234567890-1")
            
            assert.is_not_nil(trace_data)
            assert.equal("abcdef1234567890abcdef1234567890", trace_data.trace_id)
            assert.equal("abcdef1234567890", trace_data.span_id)
        end)
        
        it("should handle whitespace", function()
            local trace_data = headers.parse_sentry_trace("  1234567890abcdef1234567890abcdef-1234567890abcdef-1  ")
            
            assert.is_not_nil(trace_data)
            assert.equal("1234567890abcdef1234567890abcdef", trace_data.trace_id)
            assert.equal("1234567890abcdef", trace_data.span_id)
            assert.equal(true, trace_data.sampled)
        end)
        
        it("should return nil for invalid header values", function()
            assert.is_nil(headers.parse_sentry_trace(nil))
            assert.is_nil(headers.parse_sentry_trace(""))
            assert.is_nil(headers.parse_sentry_trace("   "))
            assert.is_nil(headers.parse_sentry_trace("invalid-format"))
            assert.is_nil(headers.parse_sentry_trace("too-short"))
            assert.is_nil(headers.parse_sentry_trace("not-hex-characters-here123456789012-1234567890abcdef"))
        end)
        
        it("should return nil for invalid trace_id length", function()
            assert.is_nil(headers.parse_sentry_trace("short-1234567890abcdef-1"))
            assert.is_nil(headers.parse_sentry_trace("toolong1234567890abcdef1234567890ab-1234567890abcdef-1"))
        end)
        
        it("should return nil for invalid span_id length", function()
            assert.is_nil(headers.parse_sentry_trace("1234567890abcdef1234567890abcdef-short-1"))
            assert.is_nil(headers.parse_sentry_trace("1234567890abcdef1234567890abcdef-toolong567890abcdef-1"))
        end)
        
        it("should ignore invalid sampled values", function()
            local trace_data = headers.parse_sentry_trace("1234567890abcdef1234567890abcdef-1234567890abcdef-invalid")
            
            assert.is_not_nil(trace_data)
            assert.is_nil(trace_data.sampled) -- Should defer sampling decision
        end)
    end)
    
    describe("generate_sentry_trace", function()
        it("should generate valid sentry-trace header", function()
            local trace_data = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "1234567890abcdef",
                sampled = true
            }
            
            local header = headers.generate_sentry_trace(trace_data)
            assert.equal("1234567890abcdef1234567890abcdef-1234567890abcdef-1", header)
        end)
        
        it("should generate header without sampled flag when sampled is nil", function()
            local trace_data = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "1234567890abcdef"
            }
            
            local header = headers.generate_sentry_trace(trace_data)
            assert.equal("1234567890abcdef1234567890abcdef-1234567890abcdef", header)
        end)
        
        it("should generate header with sampled=0 when sampled is false", function()
            local trace_data = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "1234567890abcdef",
                sampled = false
            }
            
            local header = headers.generate_sentry_trace(trace_data)
            assert.equal("1234567890abcdef1234567890abcdef-1234567890abcdef-0", header)
        end)
        
        it("should normalize to lowercase", function()
            local trace_data = {
                trace_id = "ABCDEF1234567890ABCDEF1234567890",
                span_id = "ABCDEF1234567890"
            }
            
            local header = headers.generate_sentry_trace(trace_data)
            assert.equal("abcdef1234567890abcdef1234567890-abcdef1234567890", header)
        end)
        
        it("should return nil for invalid input", function()
            assert.is_nil(headers.generate_sentry_trace(nil))
            assert.is_nil(headers.generate_sentry_trace({}))
            assert.is_nil(headers.generate_sentry_trace({trace_id = "invalid"}))
            assert.is_nil(headers.generate_sentry_trace({span_id = "invalid"}))
            assert.is_nil(headers.generate_sentry_trace({
                trace_id = "short",
                span_id = "1234567890abcdef"
            }))
        end)
    end)
    
    describe("parse_baggage", function()
        it("should parse simple baggage header", function()
            local baggage = headers.parse_baggage("key1=value1,key2=value2")
            
            assert.equal("value1", baggage.key1)
            assert.equal("value2", baggage.key2)
        end)
        
        it("should parse baggage with properties (ignore properties)", function()
            local baggage = headers.parse_baggage("key1=value1;property=prop,key2=value2")
            
            assert.equal("value1", baggage.key1)
            assert.equal("value2", baggage.key2)
        end)
        
        it("should handle whitespace", function()
            local baggage = headers.parse_baggage("  key1=value1  ,  key2=value2  ")
            
            assert.equal("value1", baggage.key1)
            assert.equal("value2", baggage.key2)
        end)
        
        it("should return empty table for invalid input", function()
            local baggage1 = headers.parse_baggage(nil)
            local baggage2 = headers.parse_baggage("")
            local baggage3 = headers.parse_baggage("   ")
            
            assert.same({}, baggage1)
            assert.same({}, baggage2)
            assert.same({}, baggage3)
        end)
        
        it("should ignore invalid key-value pairs", function()
            local baggage = headers.parse_baggage("key1=value1,invalid_entry,key2=value2")
            
            assert.equal("value1", baggage.key1)
            assert.equal("value2", baggage.key2)
            assert.is_nil(baggage.invalid_entry)
        end)
    end)
    
    describe("generate_baggage", function()
        it("should generate valid baggage header", function()
            local baggage_data = {
                key1 = "value1",
                key2 = "value2"
            }
            
            local header = headers.generate_baggage(baggage_data)
            
            -- Order is not guaranteed, so check both possibilities
            local expected1 = "key1=value1,key2=value2"
            local expected2 = "key2=value2,key1=value1"
            
            assert.is_true(header == expected1 or header == expected2)
        end)
        
        it("should URL encode special characters", function()
            local baggage_data = {
                key1 = "value,with,commas",
                key2 = "value;with;semicolons",
                key3 = "value=with=equals"
            }
            
            local header = headers.generate_baggage(baggage_data)
            
            assert.is_true(header:find("value%%2Cwith%%2Ccommas") ~= nil)
            assert.is_true(header:find("value%%3Bwith%%3Bsemicolons") ~= nil)
            assert.is_true(header:find("value%%3Dwith%%3Dequals") ~= nil)
        end)
        
        it("should return nil for empty or invalid input", function()
            assert.is_nil(headers.generate_baggage(nil))
            assert.is_nil(headers.generate_baggage({}))
            assert.is_nil(headers.generate_baggage({key1 = 123})) -- Non-string value
        end)
    end)
    
    describe("generate_trace_id", function()
        it("should generate valid trace IDs", function()
            local id1 = headers.generate_trace_id()
            local id2 = headers.generate_trace_id()
            
            assert.equal(32, #id1)
            assert.equal(32, #id2)
            assert.is_not_equal(id1, id2) -- Should be unique
            assert.is_true(id1:match("^[0-9a-f]+$") ~= nil) -- Should be hex
        end)
    end)
    
    describe("generate_span_id", function()
        it("should generate valid span IDs", function()
            local id1 = headers.generate_span_id()
            local id2 = headers.generate_span_id()
            
            assert.equal(16, #id1)
            assert.equal(16, #id2)
            assert.is_not_equal(id1, id2) -- Should be unique
            assert.is_true(id1:match("^[0-9a-f]+$") ~= nil) -- Should be hex
        end)
    end)
    
    describe("extract_trace_headers", function()
        it("should extract sentry-trace header", function()
            local http_headers = {
                ["sentry-trace"] = "1234567890abcdef1234567890abcdef-1234567890abcdef-1",
                ["content-type"] = "application/json"
            }
            
            local trace_info = headers.extract_trace_headers(http_headers)
            
            assert.is_not_nil(trace_info.sentry_trace)
            assert.equal("1234567890abcdef1234567890abcdef", trace_info.sentry_trace.trace_id)
        end)
        
        it("should extract baggage header", function()
            local http_headers = {
                ["baggage"] = "key1=value1,key2=value2"
            }
            
            local trace_info = headers.extract_trace_headers(http_headers)
            
            assert.is_not_nil(trace_info.baggage)
            assert.equal("value1", trace_info.baggage.key1)
            assert.equal("value2", trace_info.baggage.key2)
        end)
        
        it("should be case-insensitive for header names", function()
            local http_headers = {
                ["SENTRY-TRACE"] = "1234567890abcdef1234567890abcdef-1234567890abcdef-1",
                ["Baggage"] = "key1=value1"
            }
            
            local trace_info = headers.extract_trace_headers(http_headers)
            
            assert.is_not_nil(trace_info.sentry_trace)
            assert.is_not_nil(trace_info.baggage)
        end)
        
        it("should extract traceparent header", function()
            local http_headers = {
                ["traceparent"] = "00-1234567890abcdef1234567890abcdef-1234567890abcdef-01"
            }
            
            local trace_info = headers.extract_trace_headers(http_headers)
            
            assert.equal("00-1234567890abcdef1234567890abcdef-1234567890abcdef-01", trace_info.traceparent)
        end)
        
        it("should return empty table for invalid input", function()
            local trace_info1 = headers.extract_trace_headers(nil)
            local trace_info2 = headers.extract_trace_headers({})
            
            assert.same({}, trace_info1)
            assert.same({}, trace_info2)
        end)
    end)
    
    describe("inject_trace_headers", function()
        it("should inject sentry-trace header", function()
            local http_headers = {}
            local trace_data = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "1234567890abcdef",
                sampled = true
            }
            
            headers.inject_trace_headers(http_headers, trace_data)
            
            assert.equal("1234567890abcdef1234567890abcdef-1234567890abcdef-1", http_headers["sentry-trace"])
        end)
        
        it("should inject baggage header", function()
            local http_headers = {}
            local trace_data = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "1234567890abcdef"
            }
            local baggage_data = {
                key1 = "value1",
                key2 = "value2"
            }
            
            headers.inject_trace_headers(http_headers, trace_data, baggage_data)
            
            assert.is_not_nil(http_headers["baggage"])
            assert.is_true(http_headers["baggage"]:find("key1=value1") ~= nil)
            assert.is_true(http_headers["baggage"]:find("key2=value2") ~= nil)
        end)
        
        it("should inject traceparent header when requested", function()
            local http_headers = {}
            local trace_data = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "1234567890abcdef",
                sampled = true
            }
            local options = {
                include_traceparent = true
            }
            
            headers.inject_trace_headers(http_headers, trace_data, nil, options)
            
            assert.equal("00-1234567890abcdef1234567890abcdef-1234567890abcdef-01", http_headers["traceparent"])
        end)
        
        it("should not modify headers for invalid input", function()
            local http_headers = {existing = "value"}
            
            headers.inject_trace_headers(http_headers, nil)
            
            assert.equal("value", http_headers.existing)
            assert.is_nil(http_headers["sentry-trace"])
        end)
    end)
end)