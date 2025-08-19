#!/usr/bin/env lua

-- Test script to verify Love2D example modules can be loaded

-- Add build path for modules
package.path = "../../build/?.lua;../../build/?/init.lua;" .. package.path

print("Testing Love2D example module loading...")

-- Test basic Sentry module loading
local success, sentry = pcall(require, "sentry")
if success then
    print("✓ Sentry module loaded successfully")
else
    print("✗ Failed to load Sentry module:", sentry)
    os.exit(1)
end

-- Test logger module
local success, logger = pcall(require, "sentry.logger")  
if success then
    print("✓ Logger module loaded successfully")
else
    print("✗ Failed to load logger module:", logger)
    os.exit(1)
end

-- Test Love2D platform modules
local success, transport = pcall(require, "sentry.platforms.love2d.transport")
if success then
    print("✓ Love2D transport module loaded successfully")
else
    print("✗ Failed to load Love2D transport module:", transport)
    os.exit(1)
end

local success, os_detection = pcall(require, "sentry.platforms.love2d.os_detection")
if success then
    print("✓ Love2D OS detection module loaded successfully")
else
    print("✗ Failed to load Love2D OS detection module:", os_detection)
    os.exit(1)
end

local success, context = pcall(require, "sentry.platforms.love2d.context")
if success then
    print("✓ Love2D context module loaded successfully")
else
    print("✗ Failed to load Love2D context module:", context)
    os.exit(1)
end

print("\nAll Love2D example modules loaded successfully!")
print("The Love2D example should work when run with 'love examples/love2d'")

-- Test that Love2D transport is available (without _G.love it should return false)
print("\nTesting Love2D transport availability (should be false without Love2D runtime):")
print("Love2D transport available:", transport.is_love2d_available())

print("\nModule loading test completed successfully!")