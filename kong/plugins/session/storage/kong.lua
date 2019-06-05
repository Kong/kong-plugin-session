local concat       = table.concat
local tonumber     = tonumber
local setmetatable = setmetatable
local floor        = math.floor
local now          = ngx.now
local kong         = kong

local kong_storage = {}

kong_storage.__index = kong_storage

function kong_storage.new(config)
  return setmetatable({
    db          = kong.db,
    encode      = config.encoder.encode,
    decode      = config.encoder.decode,
    delimiter   = config.cookie.delimiter,
    lifetime    = config.cookie.lifetime,
  }, kong_storage)
end


local function load_session(sid)
  local session, err = kong.db.sessions:select_by_session_id(sid)
  if not session then
    return nil, err
  end

  return session
end


function kong_storage:get(sid)
  local cache_key = kong.db.sessions:cache_key(sid)
  local s, err = kong.cache:get(cache_key, nil, load_session, sid)

  if err then
    kong.log.err("could not find session:", err)
  end

  return s, err
end


function kong_storage:cookie(c)
  local r, d = {}, self.delimiter
  local i, p, s, e = 1, 1, c:find(d, 1, true)
  while s do
      if i > 2 then
          return nil
      end
      r[i] = c:sub(p, e - 1)
      i, p = i + 1, e + 1
      s, e = c:find(d, p, true)
  end
  if i ~= 3 then
      return nil
  end
  r[3] = c:sub(p)
  return r
end


function kong_storage:open(cookie, lifetime)
  local c = self:cookie(cookie)

  if c and c[1] and c[2] and c[3] then
    local id, expires, hmac = self.decode(c[1]), tonumber(c[2]), self.decode(c[3])
    local data

    if ngx.get_phase() ~= 'header_filter' then
      local db_s = self:get(c[1])
      if db_s then
        data = self.decode(db_s.data)
        expires = db_s.expires
      end
    end

    return id, expires, data, hmac
  end

  return nil, "invalid"
end


function kong_storage:insert_session(sid, data, expires)
  local _, err = self.db.sessions:insert({
    session_id = sid,
    data = data,
    expires = expires,
  }, { ttl = self.lifetime })

  if err then
    kong.log.err("could not insert session: ", err)
  end
end


function kong_storage:update_session(id, params, ttl)
  local _, err = self.db.sessions:update({ id = id }, params, { ttl = ttl })
  if err then
    kong.log.err("could not update session: ", err)
  end
end


function kong_storage:save(id, expires, data, hmac)
  local life, key = floor(expires - now()), self.encode(id)
  local value = concat({key, expires, self.encode(hmac)}, self.delimiter)

  if life > 0 then
    if ngx.get_phase() == 'header_filter' then
      ngx.timer.at(0, function()
        self:insert_session(key, self.encode(data), expires)
      end)
    else
      self:insert_session(key, self.encode(data), expires)
    end

    return value
  end

  return nil, "expired"
end


function kong_storage:destroy(id)
  local db_s = self:get(self.encode(id))

  if not db_s then
    return
  end

  local _, err = self.db.sessions:delete({
    id = db_s.id
  })

  if err then
    kong.log.err("could not delete session: ", err)
  end
end


-- used by regenerate strategy to expire old sessions during renewal
function kong_storage:ttl(id, ttl)
  if ngx.get_phase() == 'header_filter' then
    ngx.timer.at(0, function()
      local s = self:get(self.encode(id))
      if s then
        self:update_session(s.id, {session_id = s.session_id}, ttl)
      end
    end)
  else
    local s = self:get(self.encode(id))
    if s then
      self:update_session(s.id, {session_id = s.session_id}, ttl)
    end
  end
end

return kong_storage
