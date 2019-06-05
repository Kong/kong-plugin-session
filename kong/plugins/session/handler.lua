local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.session.access"
local session = require "kong.plugins.session.session"

local kong = kong

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

local KongSessionHandler = {
  PRIORITY = 1900,
  VERSION = "1.0.0",
}


function KongSessionHandler:header_filter(conf)
  local ctx = kong.ctx.shared

  if not ctx.authenticated_credential then
    -- don't open sessions for anonymous users
    kong.log.debug("Anonymous: No credential.")
    return
  end

  local credential_id = ctx.authenticated_credential and ctx.authenticated_credential.id
  local consumer_id = ctx.authenticated_consumer and ctx.authenticated_consumer.id
  local s = ctx.authenticated_session

  -- if session exists and the data in the session matches the ctx then
  -- don't worry about saving the session data or sending cookie
  if s and s.present then
    local cid, cred_id = session.retrieve_session_data(s)
    if cred_id == credential_id and cid == consumer_id
    then
      return
    end
  end

  -- session is no longer valid
  -- create new session and save the data / send the Set-Cookie header
  if consumer_id then
    s = s or session.open_session(conf)
    session.store_session_data(s, consumer_id, credential_id or consumer_id)
    s:save()
  end
end


function KongSessionHandler:access(conf)
  access.execute(conf)
end


return KongSessionHandler
