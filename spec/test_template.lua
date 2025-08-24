-- Copy this template for new tests
-- 1. Copy this file to your test name (e.g., transport_spec.lua)
-- 2. Change the require and module names  
-- 3. Add your test cases

require("spec")

describe("Your Module Name", function()
    local your_module

    before_each(function()
        your_module = require("core.your_module")
    end)

    describe("Feature Group", function()
        it("should do something", function()
            -- Your test here
            assert.are.equal(expected, actual)
        end)
    end)
end)