local type TODO = any

global enum HttpMethod
  "GET"
  "POST"
  "PUT"
  "PATCH"
  "DELETE"
  "OPTIONS"
  "TRACE"
end

local record resty
  enum Phase
    "set"
    "rewrite"
    "access"
    "content"
    "log"
    "header_filter"
    "body_filter"
    "timer"
    "init_worker"
    "balancer"
    "ssl_cert"
    "ssl_session_store"
    "ssl_session_fetch"
  end
end


global record ngx
  record ctx
    authenticated_groups: {string}
  end

  encode_base64: function (bytes: any): string

  record timer
    at: function()
  end

  get_phase: function(): resty.Phase
end

return resty
