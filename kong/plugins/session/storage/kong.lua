local singletons   = require "kong.singletons"
local concat       = table.concat
local tonumber     = tonumber
local setmetatable = setmetatable
local floor        = math.floor
local now          = ngx.now

local kong_storage = {}

kong_storage.__index = kong_storage

function kong_storage.new(config)
  return setmetatable({
      dao         = singletons.dao,
      prefix      = "session:cache",
      encode      = config.encoder.encode,
      decode      = config.encoder.decode,
      delimiter   = config.cookie.delimiter
  }, kong_storage)
end


function kong_storage:get(k)
  local s, err = self.dao.sessions:find({ id = k })

  if err then
    ngx.log(ngx.ERR, "Error finding session:", err)
  end

  return s, err
end


function kong_storage:cookie(c)
  local r, d = {}, self.delimiter
  local i, p, s, e = 1, 1, c:find(d, 1, true)
  while s do
    if i > 3 then
        return nil
    end
    r[i] = c:sub(p, e - 1)
    i, p = i + 1, e + 1
    s, e = c:find(d, p, true)
  end
  if i ~= 4 then
      return nil
  end
  r[4] = c:sub(p)
  return r
end


function kong_storage:open(cookie, lifetime)
  local c = self:cookie(cookie)

  if c and c[1] and c[2] and c[3] and c[4] then
    local id, expires, d, hmac = self.decode(c[1]), tonumber(c[2]), 
                                 self.decode(c[3]), self.decode(c[4])
    local data = d

    if ngx.get_phase() ~= 'header_filter' then
      local db_s = self:get(id)
      if db_s then
        local _, err = self.dao.sessions:update({ id = db_s.id }, {
          expires = floor(now() - lifetime),
        })

        if err then
          ngx.log(ngx.ERR, "Error updating expiry of session: ", err)
        end

        data = self.decode(db_s.data)
      end
    end
    
    return id, expires, data, hmac
  end

  return nil, "invalid"
end


function kong_storage:save(id, expires, data, hmac)
  local life = floor(expires - now())
  local value = concat({self.encode(id), expires, self.encode(data),
                        self.encode(hmac)}, self.delimiter)
  
  if life > 0 then
    ngx.timer.at(0, function()
      local s = self:get(id)
      local err, _
      
      if s then
        _, err = self.dao.sessions:update({ id = id }, {
          data = self.encode(data),
          expires = expires,
        })
      else
        _, err = self.dao.sessions:insert({
          id = id,
          data = self.encode(data),
          expires = expires,
        })
      end

      if err then
        ngx.log(ngx.ERR, "Error inserting session: ", err)
      end
    end)

    return value
  end
  
  return nil, "expired" 
end


function kong_storage:destroy(id)
  local db_s = self:get(id)

  if not db_s then
    return
  end
  
  local _, err = self.dao.sessions:delete({
    id = db_s.id
  })

  if err then
    ngx.log(ngx.ERR, "Error deleting session: ", err)
  end
end

return kong_storage
