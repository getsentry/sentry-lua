require("spec")

describe("DSN Parsing", function()
   local dsn_utils

   before_each(function()
      dsn_utils = require("core.dsn")
   end)

   describe("Valid DSN parsing", function()
      it("should parse a standard valid DSN with secret", function()
         local dsn_string = "https://public_key:secret_key@sentry.io/123456"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)

         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("https", dsn.protocol)
         assert.are.equal("public_key", dsn.public_key)
         assert.are.equal("secret_key", dsn.secret_key)
         assert.are.equal("sentry.io", dsn.host)
         assert.are.equal(443, dsn.port)
         assert.are.equal("/123456", dsn.path)
         assert.are.equal("123456", dsn.project_id)
      end)

      it("should parse a valid DSN without secret key", function()
         local dsn_string = "https://public_key@sentry.io/789"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)

         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("https", dsn.protocol)
         assert.are.equal("public_key", dsn.public_key)
         assert.are.equal("", dsn.secret_key)
         assert.are.equal("sentry.io", dsn.host)
         assert.are.equal("789", dsn.project_id)
      end)

      it("should parse HTTP DSN with default port 80", function()
         local dsn_string = "http://public_key@localhost/456"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)

         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("http", dsn.protocol)
         assert.are.equal("localhost", dsn.host)
         assert.are.equal(80, dsn.port)
         assert.are.equal("456", dsn.project_id)
      end)

      it("should parse DSN with custom port", function()
         local dsn_string = "https://public_key@sentry.example.com:9000/123"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("sentry.example.com", dsn.host)
         assert.are.equal(9000, dsn.port)
      end)
      
      it("should parse DSN with path prefix", function()
         local dsn_string = "https://public_key@sentry.io/path/to/123"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("/path/to/123", dsn.path)
         assert.are.equal("123", dsn.project_id)
      end)
      
      it("should parse DSN with subdomain", function()
         local dsn_string = "https://abc123@org.ingest.sentry.io/456789"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("abc123", dsn.public_key)
         assert.are.equal("org.ingest.sentry.io", dsn.host)
         assert.are.equal("456789", dsn.project_id)
      end)
      
      it("should handle numeric project IDs correctly", function()
         local dsn_string = "https://key@host.com/1234567890"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("1234567890", dsn.project_id)
      end)
   end)
   
   describe("Invalid DSN parsing", function()
      it("should reject nil DSN", function()
         local dsn, error = dsn_utils.parse_dsn(nil)
         
         assert.is_not_nil(error)
         assert.are.equal("DSN is required", error)
      end)
      
      it("should reject empty string DSN", function()
         local dsn, error = dsn_utils.parse_dsn("")
         
         assert.is_not_nil(error)
         assert.are.equal("DSN is required", error)
      end)
      
      it("should reject DSN without protocol", function()
         local dsn, error = dsn_utils.parse_dsn("public_key@sentry.io/123")
         
         assert.is_not_nil(error)
         assert.are.equal("Invalid DSN format", error)
      end)
      
      it("should reject DSN without public key", function()
         local dsn, error = dsn_utils.parse_dsn("https://@sentry.io/123")
         
         assert.is_not_nil(error)
         assert.are.equal("Invalid DSN format", error)
      end)
      
      it("should reject DSN without host", function()
         local dsn, error = dsn_utils.parse_dsn("https://public_key@/123")
         
         assert.is_not_nil(error)
         assert.are.equal("Invalid DSN format", error)
      end)
      
      it("should reject DSN without path", function()
         local dsn, error = dsn_utils.parse_dsn("https://public_key@sentry.io")
         
         assert.is_not_nil(error)
         assert.are.equal("Invalid DSN format", error)
      end)
      
      it("should reject DSN without project ID", function()
         local dsn, error = dsn_utils.parse_dsn("https://public_key@sentry.io/")
         
         assert.is_not_nil(error)
         assert.are.equal("Could not extract project ID from DSN", error)
      end)
      
      it("should reject DSN with non-numeric project ID", function()
         local dsn, error = dsn_utils.parse_dsn("https://public_key@sentry.io/project")
         
         assert.is_not_nil(error)
         assert.are.equal("Could not extract project ID from DSN", error)
      end)
      
      it("should reject malformed URLs", function()
         local malformed_dsns = {
            "not-a-url",
            "://missing-scheme",
            "https://",
            "https:///path/only",
            "ftp://wrong-scheme@host.com/123",
         }
         
         for _, dsn_string in ipairs(malformed_dsns) do
            local dsn, error = dsn_utils.parse_dsn(dsn_string)
            assert.is_not_nil(error, "Expected error for DSN: " .. dsn_string)
         end
      end)
      
      it("should handle invalid port gracefully", function()
         -- This tests the port parsing - invalid ports should fallback to default
         local dsn_string = "https://key@host.com:invalid/123"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal(443, dsn.port) -- Should fallback to default HTTPS port
      end)
   end)
   
   describe("Auth header building", function()
      it("should build auth header with secret key", function()
         local dsn = {
            public_key = "public123",
            secret_key = "secret456"
         }
         
         local header = dsn_utils.build_auth_header(dsn)
         
         -- Check that all required parts are present (version-agnostic)
         assert.is_true(header:find("Sentry sentry_version=7") ~= nil)
         assert.is_true(header:find("sentry_key=public123") ~= nil)
         assert.is_true(header:find("sentry_secret=secret456") ~= nil)
         assert.is_true(header:find("sentry_client=sentry%-lua/") ~= nil)  -- Version-agnostic check
      end)
      
      it("should build auth header without secret key", function()
         local dsn = {
            public_key = "public123",
            secret_key = ""
         }
         
         local header = dsn_utils.build_auth_header(dsn)
         
         -- Should not include secret
         assert.is_true(header:find("sentry_key=public123") ~= nil)
         assert.is_true(header:find("sentry_secret") == nil)
      end)
      
      it("should build auth header with nil secret key", function()
         local dsn = {
            public_key = "public123",
            secret_key = nil
         }
         
         local header = dsn_utils.build_auth_header(dsn)
         
         -- Should not include secret
         assert.is_true(header:find("sentry_key=public123") ~= nil)
         assert.is_true(header:find("sentry_secret") == nil)
      end)
   end)
   
   describe("Edge cases and security", function()
      it("should handle special characters in keys", function()
         local dsn_string = "https://key-with.dots_and-dashes@host.com/123"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("key-with.dots_and-dashes", dsn.public_key)
      end)
      
      it("should handle IPv4 addresses", function()
         local dsn_string = "https://key@192.168.1.1/123"
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal("192.168.1.1", dsn.host)
      end)
      
      it("should handle very long project IDs", function()
         local long_id = "123456789012345678901234567890"
         local dsn_string = "https://key@host.com/" .. long_id
         local dsn, error = dsn_utils.parse_dsn(dsn_string)
         
         assert.is_nil(error or (error ~= "" and error or nil))
         assert.are.equal(long_id, dsn.project_id)
      end)
   end)
end)