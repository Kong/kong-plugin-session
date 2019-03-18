local constants = require "kong.constants"
local session = require "kong.plugins.session.session"
local ngx_set_header = ngx.req.set_header
local log = ngx.log
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
  ngx_set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  ngx_set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  ngx_set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  ngx.ctx.authenticated_consumer = consumer
  if credential_id then
    ngx.ctx.authenticated_credential = { id = credential_id or consumer.id, 
                                         consumer_id = consumer.id }
    ngx_set_header(constants.HEADERS.ANONYMOUS, true)
  end
end


function _M.execute(conf)
  local s = session.open_session(conf)

  if not s.present then
    log(ngx.DEBUG, "Session not present")
    return
  end

  -- check if incoming request is trying to logout
  if session.logout(conf) then
    log(ngx.DEBUG, "Session logging out")
    s:destroy()
    return ngx.exit(200)
  end


  local cid, credential = session.retrieve_session_data(s)

  local consumer_cache_key = kong.db.consumers:cache_key(cid)
  local consumer, err = kong.cache:get(consumer_cache_key, nil,
                                       load_consumer, cid)

  if err then
    ngx.log(ngx.ERR, "Error loading consumer: ", err)
    return
  end

  -- destroy sessions with invalid consumer_id
  if not consumer then
    ngx.log(ngx.DEBUG, "No consumer, destroying session")
    return s:destroy()
  end

  s:start()

  set_consumer(consumer, credential)
  ngx.ctx.authenticated_session = s
end


return _M
