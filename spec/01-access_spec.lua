local utils = require "kong.tools.utils"
local helpers = require "spec.helpers"
local cjson = require "cjson.safe"

for _, strategy in helpers.each_strategy() do
  describe("Plugin: Session (access) [#" .. strategy .. "]", function()
    local client

    setup(function()
      local bp = helpers.get_db_utils(strategy)

      local service = assert(bp.services:insert {
        path = "/",
        protocol = "http",
        host = "httpbin.org",
      })

      local route1 = bp.routes:insert {
        paths    = {"/test1"},
        service = service1,
      }

      local route2 = bp.routes:insert {
        paths    = {"/test2"},
        service = service1,
      }

      local route3 = bp.routes:insert {
        paths    = {"/test3"},
        service = service1,
      }

      assert(bp.plugins:insert {
        name = "session",
        route_id = route1.id,
      })

      assert(bp.plugins:insert {
        name = "session",
        route_id = route2.id,
        config = {
          cookie_name = "da_cookie",
          cookie_samesite = "Lax",
          cookie_httponly = false,
          cookie_secure = false,
        }
      })

      assert(bp.plugins:insert {
        name = "session",
        route_id = route3.id,
      })

      assert(helpers.start_kong {
        custom_plugins = "session",
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
      })
    end)

    teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_ssl_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    describe("request", function()
      it("plugin attaches Set-Cookie and cookie response headers", function()
        local res = assert(client:send {
          method = "GET",
          path = "/test1/status/200",
          headers = {
            host = "httpbin.org",
          },
        })

        assert.response(res).has.status(200)

        local cookie = assert.response(res).has.header("Set-Cookie")
        local cookie_name = utils.split(cookie, "=")[1]
        assert.equal("session", cookie_name)
        
        -- e.g. ["Set-Cookie"] = 
        --    "session=m1EL96jlDyQztslA4_6GI20eVuCmsfOtd6Y3lSo4BTY.|1543472406|U
        --    5W4A6VXhvqvBSf4G_v0-Q..|DFJMMSR1HbleOSko25kctHZ44oo.; Path=/; Same
        --    Site=Strict; Secure; HttpOnly"
        local cookie_parts = utils.split(cookie, "; ")
        assert.equal("SameSite=Strict", cookie_parts[3])
        assert.equal("Secure", cookie_parts[4])
        assert.equal("HttpOnly", cookie_parts[5])
      end)

      it("plugin attaches cookie from configs", function()
        local res = assert(client:send {
          method = "GET",
          path = "/test2/status/200",
          headers = {
            host = "httpbin.org",
          },
        })

        assert.response(res).has.status(200)
        
        local cookie = assert.response(res).has.header("Set-Cookie")
        local cookie_name = utils.split(cookie, "=")[1]
        assert.equal("da_cookie", cookie_name)
        
        local cookie_parts = utils.split(cookie, "; ")
        assert.equal("SameSite=Lax", cookie_parts[3])
        assert.equal(nil, cookie_parts[4])
        assert.equal(nil, cookie_parts[5])
      end)
    end)
    
    describe("response", function()
      it("attach Set-Cookie and then use cookie in subsequent request", function()
        local res = assert(client:send {
          method = "GET",
          path = "/test3/status/200",
          headers = {
            host = "httpbin.org",
          },
        })
  
        assert.response(res).has.status(200)
  
        local cookie = assert.response(res).has.header("Set-Cookie")
        local cookie_name = utils.split(cookie, "=")[1]
        local cookie_val = utils.split(utils.split(cookie, "=")[2], ";")[1]
        assert.equal("session", cookie_name)
  
        res = assert(client:send {
          method = "GET",
          path = "/test3/status/201",
          headers = {
            host = "httpbin.org",
          },
        })
  
        assert.response(res).has.status(201)
        local cookie2 = assert.response(res).has.header("Set-Cookie")
        local cookie_val2 = utils.split(utils.split(cookie, "=")[2], ";")[1]
        assert.equal(cookie_val, cookie_val2)
      end)
    end)
  end)

  describe("Plugin: Session (authentication) [#" .. strategy .. "]", function()
    local client

    setup(function()
      local bp = helpers.get_db_utils(strategy)

      local service = assert(bp.services:insert {
        path = "/",
        protocol = "http",
        host = "httpbin.org",
      })

      local route1 = bp.routes:insert {
        paths    = {"/status/200"},
        service = service1,
        strip_path = false,
      }

      assert(bp.plugins:insert {
        name = "session",
        route_id = route1.id,
        config = {
          cookie_name = "da_cookie",
        }
      })

      local consumer = bp.consumers:insert { username = "coop", }
      bp.keyauth_credentials:insert {
        key = "kong",
        consumer_id = consumer.id,
      }

      local anonymous = bp.consumers:insert { username = "anon", }
      bp.plugins:insert {
        name = "key-auth",
        route_id = route1.id,
        config = {
          anonymous = anonymous.id
        }
      }

      bp.plugins:insert {
        name = "request-termination",
        consumer_id = anonymous.id,
        config = {
          status_code = 403,
          message = "So it goes.",
        }
      }

      assert(helpers.start_kong {
        custom_plugins = "session",
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
      })
    end)

    teardown(function()
      helpers.stop_kong(nil, true)
    end)

    before_each(function()
      client = helpers.proxy_ssl_client()
    end)

    after_each(function()
      if client then client:close() end
    end)

    describe("request", function()
      it("cookie works as authentication after initial auth plugin", function()
        local res, body, cookie
        local request = {
          method = "GET",
          path = "/status/200",
          headers = { host = "httpbin.org", },
        }

        -- make sure anonymous consumers can't get in
        res = assert(client:send(request))
        assert.response(res).has.status(403)

        -- make a request with a valid key, grab the cookie for later
        request.headers.apikey = "kong"
        res = assert(client:send(request))
        body = assert.response(res).has.status(200)
        cookie = assert.response(res).has.header("Set-Cookie")

        -- use the cookie without the key
        request.headers.apikey = nil
        request.headers.cookie = cookie
        res = assert(client:send(request))
        assert.response(res).has.status(200)
      end)
    end)
  end)
end
