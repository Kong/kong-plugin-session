local constants = require "kong.constants"
local session = require "kong.plugins.session.session"
local kong = kong

local _M = {}


local function load_consumer(consumer_id)
  local result, err = kong.db.consumers:select { id = consumer_id }
  if not result then
    return nil, err
  end
  return result
end


local function set_consumer(consumer, credential_id)
  local set_header = kong.service.request.set_header

  set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  kong.ctx.authenticated_consumer = consumer
  if credential_id then
    kong.ctx.authenticated_credential = { id = credential_id or consumer.id,
                                         consumer_id = consumer.id }
    set_header(constants.HEADERS.ANONYMOUS, true)
  end
end


function _M.execute(conf)
  local s = session.open_session(conf)

  if not s.present then
    kong.log.debug("Session not present")
    return
  end

  -- check if incoming request is trying to logout
  if session.logout(conf) then
    kong.log.debug("Session logging out")
    s:destroy()
    return kong.response.exit(200)
  end


  local cid, credential = session.retrieve_session_data(s)

  local consumer_cache_key = kong.db.consumers:cache_key(cid)
  local consumer, err = kong.cache:get(consumer_cache_key, nil,
                                       load_consumer, cid)

  if err then
    kong.log.err("Error loading consumer: ", err)
    return
  end

  -- destroy sessions with invalid consumer_id
  if not consumer then
    kong.log.debug("No consumer, destroying session")
    return s:destroy()
  end

  s:start()

  set_consumer(consumer, credential)
  kong.ctx.authenticated_session = s
end


return _M
