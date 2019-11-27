local plugin = require("kong.plugins.base_plugin"):extend()
plugin.PRIORITY = 10
plugin.VERSION = "0.1.0"

local http = require ('resty.http')
local json = require('cjson')
local lrucache = require ('resty.lrucache')
local resty_jwt = require ('resty.jwt')
local resty_hmac = require('resty.hmac')

-- per-worker cache of matched UAs
-- we use a weak table, index by the `conf` parameter, so once the plugin config
-- is GC'ed, the cache follows automatically
local caches = setmetatable({}, { __mode = "k" })
local CACHE_SIZE = 10 ^ 4
local ENCRYPTION_KEY_CACHE_KEY = "ENCRYPTION_KEY"


local req_set_header = ngx.req.set_header

local function get_authentication_secret(config)
  if not config.authentication_secret then
    err = "No secret key defined : " .. config.authentication_secret
    kong.log.warn(err)
    return kong.response.exit(403, err)
  else
    return config.authentication_secret
  end
end

function plugin:access(config)
  plugin.super.access(self)
  handle(config)
end


function handle(config)
  local authentication_secret, err = get_authentication_secret(config)
  --
  -- Start X-Client extraction
  --
    local xclient = ngx.req.get_headers()["X-CLIENT"]
    kong.log.debug("X-Client " )
    local contextjwt = string.sub(xclient, xclient:find("context")+10,xclient:find("expiresIn")-4)
    local tab = resty_jwt:load_jwt(contextjwt)
    for key, value in pairs(tab) do
      if (key == "payload"  ) then
        --kong.log.debug("key: " .. key .. "->".. tostring(value))
        local payload = tostring(value)
        --kong.log.debug("payload: " .. payload )
        local universe = string.sub(payload, payload:find("Universe")+11,payload:find("NotBefore")-4)
        kong.log.debug("X-BG-Universe: " .. universe:lower())
        req_set_header("X-BG-Universe", universe:lower())
        local channel = string.sub(payload, payload:find("ChannelId")+12,payload:find("ChannelId")+19)
        if (channel:find("Betclic") ~= nil) then req_set_header("X-BG-Brand", "betclic") end
        if (channel:find("Expekt") ~= nil) then req_set_header("X-BG-Brand", "expekt") end
        local legislation = string.sub(payload, payload:find("Legislation")+14,payload:find("Legislation")+15)
        if (legislation == "Fr") then req_set_header("X-BG-Regulator", "arjel") end
        if (legislation == "Pt") then req_set_header("X-BG-Regulator", "srij") end
        if (legislation == "Pl") then req_set_header("X-BG-Regulator", "plga") end
        if (legislation == "Co") then req_set_header("X-BG-Regulator", "mga") end
        if (legislation == "Se") then req_set_header("X-BG-Regulator", "sga") end
      end
    end

    local authjwt = string.sub(xclient, xclient:find("auth")+7,xclient:find("context")-4)
    local tab = resty_jwt:load_jwt(authjwt)

    for key, value in pairs(tab) do
      if (key == "payload"  ) then
        local payload = tostring(value)
        --kong.log.debug("key: " .. key .. "->".. tostring(value))
        local currency = string.sub(payload, payload:find("CurrencyCode")+15,payload:find("CurrencyCode")+17)
        kong.log.debug("X-BG-Currency: " .. currency)
        req_set_header("X-BG-Currency", currency)
        local language = string.sub(payload, payload:find("LanguageCode")+15,payload:find("LanguageCode")+16)
        kong.log.debug("X-BG-Language: " .. language)
        req_set_header("X-BG-Language", language)
        local userId = string.sub(payload, payload:find("UserId")+8,payload:find("Session")-3)
        kong.log.debug("X-BG-User: " .. userId)
        req_set_header("X-BG-User", userId)
        local session = string.sub(payload, payload:find("Session")+10,payload:find("CountryCode")-4)
        kong.log.debug("X-BG-Session: " .. session)
        req_set_header("X-BG-Session", session)
        local resty_md5 = require "resty.md5"
        local str = require "resty.string"
        local md5 = resty_md5:new()
        if md5 then
          local ok = md5:update( userId .. session .. config.authentication_secret)
          local digest = md5:final()
          req_set_header("X-BG-Hash", str.to_hex(digest))
          kong.log.debug("Hash : " .. str.to_hex(digest))
        end
      end
    end
end

return plugin

