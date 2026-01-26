local M = {}

local fmt = string.format
local md5 = require "md5"
local http = require "socket.http"
local sockurl = require "socket.url"
local ltn12 = require "ltn12"

local function hash(...)
   return md5.sumhexa(table.concat({...}, ":"))
end

local function dequote(s)
   local m = s:match('^"(.*)"$')
   if m then
      return m
   else
      return s
   end
end

local function parse_www_authenticate(h)
   local r = {}
   for k, v in (h .. ','):gmatch("(%w+)=(.-),") do
      r[k:lower()] = dequote(v)
   end
   return r
end

local function create_digest_header(t, url, method)
   local uri = sockurl.parse(url)
   uri = sockurl.build({path = uri.path, query = uri.query})
   if not method then method = "GET" end

   local nc = fmt("%08x", t.nc)
   
   local response = hash(
      hash(t.username, t.realm, t.password),
      t.nonce,
      nc,
      t.cnonce,
      t.qop,
      hash(method, uri)
   )

   local ent = function(k,v) return fmt('%s="%s"', k,v) end
   
   local r = {
      ent("username", t.username),
      ent("realm", t.realm),
      ent("nonce", t.nonce),
      ent("uri", uri),
      ent("cnonce", t.cnonce),
      "nc="..nc,
      ent("qop", t.qop),
      ent("algorithm", t.algorithm),
      ent("response", response)
   }

   if t.opaque then
      table.insert(r, ent("opaque", t.opaque))
   end
   
   return "Digest " .. table.concat(r, ', ')
end

local digest_metatable = {
   __index = {
      create_header = create_digest_header
   }
}

function M.cast(t)
   setmetatable(t, digest_metatable)
   return t
end

local function new_digest_auth(username, password, realm, nonce)
   t = {
      nc = 1,
      username = username,
      password = password,
      realm = realm,
      nonce = nonce,
      cnonce = fmt("%08x", os.time()),
      qop = "auth",
      algorithm = "MD5",
   }   
   setmetatable(t, digest_metatable)
   return t
end

local function urltable(domain)
   local r = {}
   if domain then
      for url in dequote(domain):gmatch("%S+") do
	 table.insert(r, url)
      end
   else
      r[1] = '/'
   end
   return r
end   

function M.try_auth(params)
   local url = sockurl.parse(params.url)

   local username = params.user or url.user
   if not username then return nil, fmt("username missing") end
   local password = params.password or url.password
   if not password then password = '' end

   url.user, url.password, url.authority, url.userinfo = nil, nil, nil, nil
   url = sockurl.build(url)

   local b, c, h = http.request({
	 url = url,
	 sink = ltn12.sink.table({})
   })
   pound.log(pound.INFO, "got b="..pound.dump(b)..", c="..tostring(c)..", h="..pound.dump(h))
   if c == 401 and h["www-authenticate"] then
      local ht = parse_www_authenticate(h["www-authenticate"])
      if not (ht.realm and ht.nonce) then
	 return nil, fmt("realm and/or nonce is not supplied")
      end
      if ht.qop ~= "auth" then
	 return nil, fmt("unsupported qop (%s)", tostring(ht.qop))
      end
      if ht.algorithm and (ht.algorithm:lower() ~= "md5") then
	 return nil, fmt("unsupported algorithm (%s)", tostring(ht.algorithm))
      end

      return new_digest_auth(username, password, ht.realm, ht.nonce), urltable(ht.domain)
   else
      return nil
   end
end

function M.redo(username, password, www_auth_header)
   local ht = parse_www_authenticate(www_auth_header)
   if ht.stale and ht.state == "false" then
      return nil, fmt("nonce is neither new nor stale")
   end
   if not (ht.realm and ht.nonce) then
      return nil, fmt("realm and/or nonce is not supplied")
   end
   if ht.qop ~= "auth" then
      return nil, fmt("unsupported qop (%s)", tostring(ht.qop))
   end
   if ht.algorithm and (ht.algorithm:lower() ~= "md5") then
      return nil, fmt("unsupported algorithm (%s)", tostring(ht.algorithm))
   end

   return new_digest_auth(username, password, ht.realm, ht.nonce), urltable(ht.domain)
end   

return M
