local plugin = require("kong.plugins.base_plugin"):extend()
plugin.PRIORITY = 10
plugin.VERSION = "0.1.0"

local http = require ('resty.http')
local json = require('cjson')
local lrucache = require ('resty.lrucache')
local resty_jwt = require ('resty.jwt')
local resty_hmac = require('resty.hmac')
local resty_md5 = require "resty.md5"
local resty_str = require "resty.string"

-- per-worker cache of matched UAs
-- we use a weak table, index by the `conf` parameter, so once the plugin config
-- is GC'ed, the cache follows automatically
local caches = setmetatable({}, { __mode = "k" })
local CACHE_SIZE = 10 ^ 4
local ENCRYPTION_KEY_CACHE_KEY = "ENCRYPTION_KEY"

local req_clear_header = ngx.req.clear_header
local req_set_header = ngx.req.set_header

local function encrypt_payload(secret_key, message )
  local result =  resty_hmac:new(secret_key, resty_hmac.ALGOS.SHA256):final(message)
  return resty_jwt:jwt_encode(result)
end

local function get_encryption_key(config)
  -- Call http to get the secret token key
  local httpc = http.new()
  local res, err = httpc:request_uri(config.discovery , {
    method = "GET"
  })

  if not res.body or res.status ~= 200  then
    kong.log.debug("failed to request: " .. config.discovery, "error : " .. err)
    return
  end

  return res.body
end

local function splitJwt(jwt)
  local raw = {}
   for result in  string.gmatch(jwt, "[^.]+") do
   table.insert(raw, result)
   end
   return raw[1], raw[2], raw[3]
end

local function get_authentication_secret(config)
  if not config.authentication_secret then
    err = "No secret key defined : " .. config.authentication_secret
    kong.log.warn(err)
    return kong.response.exit(403, err)
  else
    return config.authentication_secret
  end
end

local function validateDate(vardate)
  local y,m,d,h,i,s,z = string.match(vardate, '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)')
  kong.log.debug("Expiration date: " .. string.format('%s/%s/%s %s:%s:%s', y,m,d,h,i,s))
  local reference = os.time({day=d,month=m,year=y,hour=h,min=i,sec=s})
  local offset = reference - os.time()
  kong.log.debug("offset: " .. offset)
  if offset >= 0 then
    return true
  else
    return false
  end
end

function plugin:access(config)
  plugin.super.access(self)
  handle(config)
end

function handle(config)
  local authentication_secret, err = get_authentication_secret(config)
  local cache = caches[config]
  if not cache then
    cache = lrucache.new(CACHE_SIZE)
    caches[config] = cache
  end
  --
  -- Start X-Client extraction
  --
  -- X-CLIENT Context
  local xclient = ngx.req.get_headers()["X-CLIENT"]
  kong.log.debug("X-Client " )
  if xclient ~= nil then
    local xclient_obj = json.decode(tostring(xclient))

    -- Extract Context Headers
    local context_jwt = resty_jwt:load_jwt(xclient_obj["context"])
    local context_obj = json.decode(tostring(context_jwt["payload"]))
    req_set_header("X-BG-Universe", tostring(context_obj["Universe"]):lower())
    local channel = tostring(context_obj["ChannelId"])
    if (channel:find("Betclic") ~= nil) then req_set_header("X-BG-Brand", "betclic") end
    if (channel:find("Expekt") ~= nil) then req_set_header("X-BG-Brand", "expekt") end
    local legislation = tostring(context_obj["Legislation"])
    if (legislation == "Fr") then req_set_header("X-BG-Regulator", "arjel") end
    if (legislation == "Pt") then req_set_header("X-BG-Regulator", "srij") end
    if (legislation == "Pl") then req_set_header("X-BG-Regulator", "plga") end
    if (legislation == "Co") then req_set_header("X-BG-Regulator", "mga") end
    if (legislation == "Se") then req_set_header("X-BG-Regulator", "sga") end

    --
    -- X-CLIENT Auth
    local auth_jwt = resty_jwt:load_jwt(xclient_obj["auth"])
    local auth_obj = json.decode(tostring(auth_jwt["payload"]))


    -- Validate token
    local rawHeader, rawPayload, rawSign = splitJwt(xclient_obj["auth"])
    local jwt_encryption_key = cache:get(ENCRYPTION_KEY_CACHE_KEY)
    if not jwt_encryption_key then
      jwt_encryption_key, err = get_encryption_key(config)
      cache:set(ENCRYPTION_KEY_CACHE_KEY, jwt_encryption_key)
    end
    local key = resty_hmac:new(authentication_secret, resty_hmac.ALGOS.SHA256):final(jwt_encryption_key)
    local calculatedSignature = encrypt_payload(key, rawHeader.."."..rawPayload)
    if tostring(calculatedSignature) ~= tostring(rawSign) then
      return kong.response.exit(401, "invalid token")
    end


    -- Validate expiration date
    local expdate = tostring(auth_obj["ExpirationTime"])
    kong.log.debug("X-BG-Expdate: " .. expdate)
    if not validateDate(expdate) then kong.response.exit(401, "Expired token") end

    -- Extract Auth Headers
    kong.log.debug("X-BG-Currency: " ..  tostring(auth_obj["CurrencyCode"]))
    req_set_header("X-BG-Currency", tostring(auth_obj["CurrencyCode"]))
    kong.log.debug("X-BG-Language: " ..  tostring(auth_obj["LanguageCode"]))
    req_set_header("X-BG-Language",  tostring(auth_obj["LanguageCode"]))
    kong.log.debug("X-BG-User: " .. tostring(auth_obj["UserId"]))
    req_set_header("X-BG-User", tostring(auth_obj["UserId"]))
    kong.log.debug("X-BG-Session: " .. tostring(auth_obj["Session"]))
    req_set_header("X-BG-Session", tostring(auth_obj["Session"]))

    -- Hash generation
    local md5 = resty_md5:new()
    if md5 then
      local ok = md5:update( tostring(auth_obj["UserId"]) .. tostring(auth_obj["Session"]) .. config.authentication_secret)
      local digest = md5:final()
      req_set_header("X-BG-Hash", resty_str.to_hex(digest))
      kong.log.debug("Hash : " .. resty_str.to_hex(digest))
    end
    req_clear_header("X-CLIENT")
  else
    return kong.response.exit(401, err)
  end
end

return plugin

