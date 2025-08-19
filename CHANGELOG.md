# Changelog

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