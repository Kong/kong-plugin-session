local session = require "resty.session"
local var = ngx.var
local log = ngx.log
local read_body = ngx.req.read_body
local get_uri_args = ngx.req.get_uri_args
local get_post_args = ngx.req.get_post_args

local _M = {}

local function get_opts(conf)
  return {
    name = conf.cookie_name,
    cookie = {
      lifetime = conf.cookie_lifetime,
      path     = conf.cookie_path,
      domain   = conf.cookie_domain,
      samesite = conf.cookie_samesite,
      httponly = conf.cookie_httponly,
      secure   = conf.cookie_secure,
    }
  }
end

function _M.open_session(conf)
  local opts = get_opts(conf)
  local s
  
  if conf.storage == 'kong' then
    s = session.new(opts)
    s.storage = require("kong.plugins.session.storage.kong").new(s)
    s:open()
  else
    opts.storage = conf.storage
    s = session.open(opts)
  end
  
  return s
end


--- Determine is incoming request is trying to logout
-- @return boolean should logout of the session?
function _M.logout(conf)
  local logout = false

  local logout_methods = conf.logout_methods
  if logout_methods then
    local request_method = var.request_method
    for _, logout_method in ipairs(logout_methods) do
      if logout_method == request_method then
        logout = true
        break
      end
    end
    if logout then
      logout = false

      local logout_query_arg = conf.logout_query_arg
      if logout_query_arg then
        local uri_args = get_uri_args()
        if uri_args[logout_query_arg] then
          logout = true
        end
      end

      if logout then
        log(ngx.DEBUG, "logout by query argument")
      else
        local logout_post_arg = conf.logout_post_arg
        if logout_post_arg then
          read_body()
          local post_args = get_post_args()
          if post_args[logout_post_arg] then
            logout = true
          end
          
          if logout then
            log(ngx.DEBUG, "logout by post argument")
          end
        end
      end
    end
  end

  return logout
end


return _M
