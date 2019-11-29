local typedefs = require "kong.db.schema.typedefs"

local function check_positive(v)
  if v < 0 then
    return false, "should be 0 or greater"
  end

  return true
end

return {
  name = "betclic-xclient-extractor",
  fields = {
    { consumer = typedefs.no_consumer },
    { run_on = typedefs.run_on_first },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { route = { type = "string", required = true, default = "/echo" }, },
          { discovery = { type = "string", required = true, default = "http://core-dev.betclic.net/account/api/secret-token-key" }, },
          { authentication_secret = { type = "string", required = true, default = "82747F3EEE857DFF005ECB72CE9CC7C5869A538F71F112D9ABE8EB251FA0FA56A0D9F8D72B445EDA7A026BD471B016EE1882684E84ED5644A562393C497B6EC3" }, },
          { extract_xclient = { type = "boolean", required = true, default = false }, }
        },
      },
    },
  },
}
