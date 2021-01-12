local kong_session = require("kong.plugins.session.session")
local resty_session = require("resty.session")

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

      kong.log.debug("anonymous: no credential.")
      return
   end

   local credential_id = credential.id
   local consumer_id = consumer and consumer.id



   local s = kong.ctx.shared.authenticated_session
   if s and s.present then
      local session_data = kong_session.retrieve_session_data(s)
      local cid = session_data[1]
      local cred_id = session_data[2]
      if cred_id == credential_id and cid == consumer_id then

         return
      end
   end



   if consumer_id then
      local groups = get_authenticated_groups()
      if not s then
         local opened_session = kong_session.open_session(conf)
         s = opened_session
      end

      kong_session.store_session_data(s,
consumer_id,
credential_id or consumer_id,
groups)



      local todo = {}


      local t = s
      t:save()
   end
end


return _M
