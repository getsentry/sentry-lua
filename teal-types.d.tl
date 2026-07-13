-- Global type declarations used by `make lint` (tl check), passed via the
-- --global-env-def CLI flag. NOT referenced by tlconfig, so `tl gen` (the build)
-- is unaffected. Host-platform globals are typed `any` because their real shapes
-- come from the host runtime and the SDK accesses them defensively.

global game: any
global love: any
global ngx: any
global redis: any
global jit: any
global sys: any
global script: any
global helpers: any
global defines: any
global corona: any
