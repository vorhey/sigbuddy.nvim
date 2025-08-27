std = "luajit"
cache = true

read_globals = {
  "vim"
}

globals = {
  "describe",
  "it",
  "before_each",
  "after_each",
  "setup",
  "teardown",
}

exclude_files = {
  ".luarocks/",
  "lua_modules/",
}

ignore = {
  "212/_.*",  -- unused argument, for vars with "_" prefix
}