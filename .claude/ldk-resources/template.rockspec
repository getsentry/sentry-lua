package = "{{PACKAGE_NAME}}"
version = "dev-1"
source = {url = "git+{{REPO_URL}}.git"}
description = {
    summary = "A Lua package built with claude-lua-devkit",
    homepage = "{{HOMEPAGE_URL}}",
    license = "MIT/X11",
    maintainer = "{{MAINTAINER}}"
}
dependencies = {"lua >= 5.1"}
build = {
    type = 'make',
    build_variables = {
        PACKAGE_NAME = "{{PACKAGE_NAME}}",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        CFLAGS = "$(CFLAGS)",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare"
    },
    install_variables = {
        PACKAGE_NAME = "{{PACKAGE_NAME}}",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        BINDIR = "$(BINDIR)",
        LIBDIR = "$(LIBDIR)",
        LUADIR = "$(LUADIR)"
    }
}
