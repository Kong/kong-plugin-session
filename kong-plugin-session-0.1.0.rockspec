package = "kong-plugin-session"

version = "0.1.0-1"

supported_platforms = {"linux", "macosx"}

source = {
  url = "",
  tag = "0.1.0"
}

description = {
  summary = "A Kong plugin to support implementing sessions for auth plugins.",
  homepage = "http://konghq.com",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1",
  "lua-resty-session == 2.22",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.session.handler"] = "kong/plugins/session/handler.lua",
    ["kong.plugins.session.schema"] = "kong/plugins/session/schema.lua"
    ["kong.plugins.session.access"] = "kong/plugins/session/access.lua"
  }
}
