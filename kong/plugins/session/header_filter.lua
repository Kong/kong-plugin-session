local kong_session = require "kong.plugins.session.session"


local ngx = ngx
local kong = kong
local type = type
local assert = assert


local function get_authenticated_groups()
  local authenticated_groups = ngx.ctx.authenticated_groups
  if authenticated_groups == nil then
    return nil
  end

  assert(type(authenticated_groups) == "table",
         "invalid authenticated_groups, a table was expected")

  return authenticated_groups
end


local _M = {}


function _M.execute(conf)
  local credential = kong.client.get_credential()
  local consumer = kong.client.get_consumer()

  if not credential then
    -- don't open sessions for anonymous users
    kong.log.debug("anonymous: no credential.")
    return
  end

  local credential_id = credential.id
  local consumer_id = consumer and consumer.id

  -- if session exists and the data in the session matches the ctx then
  -- don't worry about saving the session data or sending cookie
  local s = kong.ctx.shared.authenticated_session
  if s and s.present then
    local cid, cred_id = kong_session.retrieve_session_data(s)
    if cred_id == credential_id and cid == consumer_id
    then
      return
    end
  end

  -- session is no longer valid
  -- create new session and save the data / send the Set-Cookie header
  if consumer_id then
    local groups = get_authenticated_groups()
    s = s or kong_session.open_session(conf)
    kong_session.store_session_data(s,
                                    consumer_id,
                                    credential_id or consumer_id,
                                    groups)
    s:save()
  end
end


return _M
