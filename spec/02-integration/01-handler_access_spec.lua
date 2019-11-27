local helpers = require "spec.helpers"

for _, strategy in helpers.each_strategy() do
  describe("Plugin: betclic-xclient-extractor (access) ["..strategy.."]", function()
    local proxy_client

    setup(function()
      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/nginx.template",
        declarative_config = "spec/fixtures/kong.yml",
        plugins = "bundled,betclic-xclient-extractor",
      }))
      proxy_client = helpers.proxy_client()
    end)

    teardown(function()
      helpers.stop_kong()
      if proxy_client then proxy_client:close() end
    end)

    before_each(function()
    end)

    after_each(function()
    end)

    describe("GET /echo", function()
      assert.truthy(proxy_client)
      local res = assert(proxy_client:send {
        method  = "GET",
        path    = "/echo",
        headers = {
          ["Authorization"] = "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI1NDYyODUxMjIiLCJzdWIiOiIxMTM4MTEyOCIsImxhbmciOiJmciIsImN1ciI6ImV1ciIsImlzcyI6ImJldGNsaWMuYXJqZWwiLCJleHAiOjE1NzQxNzYyMDYsIm5iZiI6MTU3NDE3NTc4Nn0.wNE4lmfICEbp0tEH08QAGoHtkV53w2BLQ6ZMxuqS0qM"
        }
      })

      it("should return 200", function()
        assert.response(res).has.status(200)
      end)
    end)

  end)
end
