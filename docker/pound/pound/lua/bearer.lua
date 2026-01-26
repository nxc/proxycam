local _M = {}
local json = require 'dkjson'

local url = os.getenv('JWKS_JSON')
local filename = '/tmp/jwks.json'

if url and pound.loadctx == 1 then
   local conn = require 'socket.http'

   local body, status, headers = conn.request(url)

   local type = headers['content-type']
   if type ~= nil and type:find("application/json") == 1 then
      local val, _, err = json.decode(body)
      if err == nil then
	    if val['keys'] ~= nil then
	       keys = val['keys']
	       file = io.open(filename, "w")
	       file:write(body)
	       file:close()
	    elseif val.message then
	       pound.log(pound.ERR, val.message)
	    end
      end
   end
end

local file = io.open(filename, "r")
if file == nil then
   pound.log(pound.ERR, "can't open " + filename)
   return nil
end
local text = file:read("a")
local val, _, err = json.decode(text)
if err then
   pound.log(pound.ERR, "can't parse keyfile: " + tostring(err))
   return nil
else
   _M.keys = val['keys']
end

local jwt = require 'jwt'

function _M.authorized()
   local bh = http.req.headers['X-Proxy-Authorization']
   if bh == nil then
      stash.bearer = { error = 'invalid_request' }
      return false
   end
   local token, n = bh:gsub("^%s*[bB][eE][aA][rR][eE][rR]*%s+([A-Za-z0-9_-]+[.][A-Za-z0-9_-]+[.][A-Za-z0-9_-]+)$", "%1")
   if n == 0 then
      stash.bearer = { error = 'invalid_request' }
      return false
   end
   local j, err = jwt.new(token)
   if err ~= nil then
      stash.bearer = { error = 'invalid_token' }
      pound.log(pound.ERR, "bad token: " .. err)
      return false
   end

   if j.header.kid == nil then
      stash.bearer = { error = 'invalid_token' }
      pound.log(pound.ERR, "bad token: kid not supplied")
      return false
   end

   for _, k in ipairs(_M.keys) do
      if k.kid == j.header.kid and j:verify(k) then
	 break
      end
   end

   if not j.verified then
      stash.bearer = { error = 'invalid_token' }
      return false
   end

   if j.payload.exp ~= nil then
      local exp = tonumber(j.payload.exp)
      if exp == nil then
	 stash.bearer = { error = 'invalid_token',
			  error_description = 'malformed payload' }
	 return false
      elseif os.time() > j.payload.exp then
	 stash.bearer = { error = 'invalid_token',
			  error_description = 'access token expired' }
	 return false
      end
   end

   stash.bearer = { jwt = j }
   
   return true
end

function _M.check_service(service)
   return stash.bearer.jwt ~= nil and
      stash.bearer.jwt.payload.cameraAddress == service
end

function _M.verbose_notauth()
   http.resp.code = 401
   http.resp.reason = stash.bearer.error
   http.resp.body = stash.bearer.error_description
end

return _M
