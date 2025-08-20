rockspec_format = "3.0"
package = "sentry"
version = "0.0.4-1"
source = {
   url = "git+https://github.com/getsentry/sentry-lua.git",
   tag = "0.0.4"
}
description = {
   summary = "Sentry SDK for Lua - Platform agnostic error tracking",
   detailed = [[
      A comprehensive Sentry SDK for Lua that works across multiple platforms
      including Redis, nginx, Roblox, Defold and other game engines and standard Lua environments.
      Written in Teal Language for better type safety and developer experience.
   ]],
   license = "MIT",
   homepage = "https://github.com/getsentry/sentry-lua",
   maintainer = "Bruno Garcia"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson >= 2.1.0"
}
build_dependencies = {
   "tl"
}
build = {
   type = "command",
   build_command = "find src/sentry -name '*.tl' -type f -exec dirname {} \\; | sed 's|^src/sentry|build/sentry|' | sort -u | xargs -I {} mkdir -p {} && find src/sentry -name '*.tl' -type f -exec sh -c 'for f; do outfile=$(echo \"$f\" | sed \"s|^src/sentry|build/sentry|\" | sed \"s|\\.tl$|\\.lua|\"); echo \"Compiling $f -> $outfile\"; tl gen \"$f\" -o \"$outfile\"; done' _ {} +",
   install_command = "mkdir -p $(LUADIR)/sentry && cp -r build/sentry/* $(LUADIR)/sentry/"
}