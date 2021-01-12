local resty = require('types.resty')
local resty_session = require "resty.session"
local type UUID = string
local type TODO = any

global record Consumer
  id: UUID
  custom_id: string
  username: string
end

global record Credential
  id: UUID
  consumer_id: UUID
end

global record kong
  record ctx
    record shared
      authenticated_session: resty_session.Session<KongPluginSessionData>
    end
  end
  record log
    err: function(...: any)
    debug: function(...: any)
  end
  record client
    authenticate: function(Consumer, Credential)
    get_credential: function(): Credential
    get_consumer: function(): Consumer
    load_consumer: function(): Consumer
  end
  record service
    record request
      set_header: function(k: string, v: string|boolean)
      clear_header: function(k: string)
    end
  end
  record request
    get_method: function(): HttpMethod
    get_query_arg: function(query_arg_key: string): string
    get_body: function(): {string:any}
  end
  record response
    exit: function(statusCode: number)
  end
  record cache
    get: function(cache, k: string, any, any, any): any, TODO
  end
  record db
    record consumers
      cache_key: function(consumers, id: string): string
    end
  end
end
