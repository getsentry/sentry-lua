rockspec_format = "3.0"
package = "sentry"
version = "0.0.6-1"
source = {
   url = "git+https://github.com/getsentry/sentry-lua.git",
   tag = "0.0.6"
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
      echo "=== Starting Teal compilation ==="

      # Compile all Teal files to Lua, creating output directories as needed.
      find src/sentry -name "*.tl" -type f | while read -r tl_file; do
         lua_file=$(echo "$tl_file" | sed 's|^src/|build/|' | sed 's|\.tl$|.lua|')
         mkdir -p "$(dirname "$lua_file")"
         echo "Compiling: $tl_file -> $lua_file"
         tl gen "$tl_file" -o "$lua_file"
         if [ $? -ne 0 ]; then
            echo "ERROR: Failed to compile $tl_file"
            exit 1
         fi
      done

      echo "=== Teal compilation completed ==="
   ]],
   install_command = [[
      echo "=== Installing compiled Lua files ==="
      
      # Create target directory
      mkdir -p "$(LUADIR)/sentry"
      
      # Copy all compiled Lua files preserving directory structure
      cd build && find sentry -name "*.lua" -type f | while read -r lua_file; do
         target_dir=$(dirname "$(LUADIR)/$lua_file")
         mkdir -p "$target_dir"
         cp "$lua_file" "$(LUADIR)/$lua_file"
         echo "Installed: $lua_file -> $(LUADIR)/$lua_file"
      done
      
      echo "=== Installation completed ==="
   ]]
}