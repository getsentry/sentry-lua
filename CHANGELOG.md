# Changelog

## 0.0.6

### Various fixes & improvements

- manual publish workflow (ebe8a3f5) by @bruno-garcia
- packaging for non luarocks use cases (319fb9e7) by @bruno-garcia
- remove oudated comment (c228ac26) by @bruno-garcia

## 0.0.5

### Various fixes & improvements

- publish as rockspec (22cd9c64) by @bruno-garcia
- luarocks instructions (22694686) by @bruno-garcia
- bump script (e8d2a291) by @bruno-garcia

## 0.0.4

### Various fixes & improvements

- package as .rock (cdced997) by @bruno-garcia
- love.errorhandler integration (a0f22464) by @bruno-garcia

## 0.0.3

### Features

- Add Love2D fatal error handler integration (#love2d)
  - Hooks into `love.errorhandler` to capture fatal crashes
  - Sets `mechanism.handled: false` for proper error classification
  - Automatically installed in Love2D environments
  - Includes comprehensive test coverage

### Various fixes & improvements

- validate rockspec in ci (1635d0d8) by @bruno-garcia
- fix rockspec deps and lua modules (3232de4a) by @bruno-garcia

## 0.0.2

### Various fixes & improvements

- changelog (37433ac9) by @bruno-garcia

## 0.0.1

Sentry Hackweek 2025 - **Experimental** SDK

* Portable Lua SDK, written in Teal, Lua 5.1 compatible.
* CI and tests on Standard Lua and LuaJIT on macOS and Linux
* Sentry Features include:
  * Error reporting with source context and local variable values
  * Context such as runtime and OS information
  * Tracing connecting all telemetry (errors, traces, logs, etc)
    * Integration with pegasus HTTP server for incoming request trace connectiveness
    * integration with luasocket for outgoing HTTP request trace propagation
  * Spans for performance monitoring
  * Log capturing including 'print' function integration
  * LÖVE framework (love2d) integration and example app

Note: This is was all built in 3 days and is likely full of bugs (even though there are 300 units tests). Please open [issues on GitHub](https://github.com/getsentry/sentry-lua/issues). Or reach out on [Sentry's Discord community](https://discord.gg/sentry).