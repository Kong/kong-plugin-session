package = "kong-plugin-session"

version = "2.2.0-1"

supported_platforms = {"linux", "macosx"}

source = {
  url = "git://github.com/Kong/kong-plugin-session",
  tag = "2.2.0"
}

description = {
  summary = "A Kong plugin to support implementing sessions for auth plugins.",
  homepage = "http://konghq.com",
  license = "Apache 2.0"
}

dependencies = {
  "lua >= 5.1",
  "lua-resty-session == 2.24",
  --"kong >= 1.2.0",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.session.handler"] = "kong/plugins/session/handler.lua",
    ["kong.plugins.session.schema"] = "kong/plugins/session/schema.lua",
    ["kong.plugins.session.access"] = "kong/plugins/session/access.lua",
    ["kong.plugins.session.session"] = "kong/plugins/session/session.lua",
    ["kong.plugins.session.daos"] = "kong/plugins/session/daos.lua",
    ["kong.plugins.session.storage.kong"] = "kong/plugins/session/storage/kong.lua",
    ["kong.plugins.session.migrations.000_base_session"] = "kong/plugins/session/migrations/000_base_session.lua",
    ["kong.plugins.session.migrations.init"] = "kong/plugins/session/migrations/init.lua",
  }
}
