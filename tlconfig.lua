return {
   source_dir = "src",
   build_dir = "build",
   module_name = "sentry",
   include_dir = {
      "src",
   },
   external_libs = {
      "busted",
   },
   target_extension = "lua",
   gen_compat = "optional",
   gen_target = "5.1"
}