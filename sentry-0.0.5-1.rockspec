rockspec_format = "3.0"
package = "sentry"
version = "0.0.5-1"
source = {
   url = "git+https://github.com/getsentry/sentry-lua.git",
   tag = "0.0.5"
}
description = {
   summary = "Platform-agnostic Sentry SDK for Lua",
   detailed = [[
      A comprehensive Sentry SDK for Lua environments with distributed tracing,
      structured logging, and cross-platform support. Written in Teal Language
      for type safety and compiled to Lua during installation.
   ]],
   homepage = "https://github.com/getsentry/sentry-lua",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson",
   "luasocket"
}
build_dependencies = {
   "tl"
}
build = {
   type = "command",
   build_command = [[
      mkdir -p build/sentry && 
      find src/sentry -type d | sed 's|src/sentry|build/sentry|' | xargs mkdir -p && 
      find src/sentry -name '*.tl' -type f | while read tl_file; do 
         lua_file=$(echo "$tl_file" | sed 's|src/sentry|build/sentry|' | sed 's|\.tl$|\.lua|'); 
         echo "Compiling $tl_file -> $lua_file"; 
         tl gen "$tl_file" -o "$lua_file" || exit 1; 
      done
   ]],
   install_command = "mkdir -p $(LUADIR)/sentry && cp -r build/sentry/* $(LUADIR)/sentry/"
}