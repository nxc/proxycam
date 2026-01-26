-- Simple implementation of JWT for Pound documentation.
-- Supports only HMAC and RS signing algorithms.

local _M = {}

local json = require 'dkjson'
local base64 = require 'base64'

local base64url_encoder = base64.makeencoder( '-', '_' )
local base64url_decoder = base64.makedecoder( '-', '_' )

-- base64url encoding. RFC 7515, Appendix C.
local function base64url_encode(s)
   b = base64.encode(s, base64url_encoder)
   return b:gsub('=*$','')
end

-- base64url encoding. RFC 7515, Appendix C.
local function base64url_decode(s)
   n = #s % 4
   if n == 3 then
      s = s .. '='
   elseif n == 2 then
      s = s .. '=='
   elseif n ~= 0 then
      return nil, 'invalid base64 encoding'
   end
   ok, val = pcall(base64.decode, s, base64url_decoder)
   if ok then
      return val
   else
      return nil, val
   end
end

local openssl = require 'openssl'

-- Constant declarator
local constant = {}
function constant.declare(t)
   return setmetatable(t, {
	 __index = function (table, key)
	    if t[key] then
	       return t[key]
	    else
	       error("No such constant: "..tostring(key))
	    end
	 end;
	 __newindex = function(table, key, value)
	    error("Attempt to modify read-only table")
	 end;
	 __metatable = false;
   });
end

setmetatable(constant, {
		__call = function(_, ...) return constant.declare(...) end
})

local S = constant {
   JWT = "JWT",
}

local function hmac(alg, secret, message)
   return openssl.hmac.hmac(alg, message, secret, true)
end

local function rsa_verify(alg, message, signature, secret)
   local pubkey
   if type(secret) == 'table' then
      pubkey = openssl.pkey.new({alg='rsa',
			         n = openssl.bn.text(base64url_decode(secret.n)),
			         e = openssl.bn.text(base64url_decode(secret.e))})
   elseif type(secret) == 'string' then
      pubkey = secret
   else
      return nil -- FIXME
   end
   local ctx = openssl.digest.verifyInit(alg, pubkey)
   ctx:update(message)
   return ctx:verifyFinal(signature)
end

local sign_algo = constant {
   HS256 = {
      signer = function (secret, message)
	 return hmac('SHA256', secret, message)
      end;
      verifier = function (message, signature, secret)
	 return hmac('SHA256', secret, message) == signature
      end;
   };
   HS384 = {
      signer = function (secret, message)
	 return hmac('SHA384', secret, message)
      end;
      verifier = function (message, signature, secret)
	 return hmac('SHA384', secret, message) == signature
      end;
   };
   HS512 = {
      signer = function (secret, message)
	 return hmac('SHA512', secret, message)
      end;
      verifier = function (message, signature, secret)
	 return hmac('SHA512', secret, message) == signature
      end;
   };
   RS256 = {
      verifier = function (message, signature, secret)
	 return rsa_verify('SHA256', message, signature, secret)
      end;
   };
   RS512 = {
      verifier = function (message, signature, secret)
	 return rsa_verify('SHA512', message, signature, secret)
      end;
   }
}

-- Sign a JWT using supplied secret.
local function jwt_sign(jwt, secret)
   input = jwt.raw.header .. '.' .. jwt.raw.payload
   return sign_algo[jwt.header.alg].signer(secret, input)
end

-- Verify JWT using supplied secret.  Cache result in the
-- "verified" field.
local function jwt_verify(jwt, secret)
   if secret ~= nil then
      input = jwt.raw.header .. '.' .. jwt.raw.payload
      jwt.verified = sign_algo[jwt.header.alg].verifier(input, jwt.signature,
							secret)
   end
   return jwt.verified
end

local jwt_metatable = {
   __index = {
      sign = jwt_sign,
      verify = jwt_verify
   }
}

-- Create new JWT object from the encoded JWT input.
-- Return the created object, or nil and textual error description on
-- error.
function _M.new(input)
   function split(s, n)
      i = s:find("[.]")
      if i == nil then
	 return s, true
      elseif n == 0 then
	 return s, false
      else
	 return s:sub(1,i-1), split(s:sub(i+1),n-1)
      end
   end

   local r = {}
   r['header'], r['payload'], r['signature'], ok = split(input,2)
   if not ok then
      return nil, 'required JWT parts missing'
   end

   local j = { ['raw'] = r }
   local val, err = base64url_decode(r['header'], base64url_decoder)
   if err ~= nil then
      return nil, 'header fails to decode'
   end

   j['header'], _, err = json.decode(val)
   if err then
      return nil, 'malformed header JSON'
   end
   if j.header.typ ~= S.JWT then
      return nil, 'unsupported type'
   end

   val, err = base64url_decode(r['payload'], base64url_decoder)
   if err ~= nil then
      return nil, 'paiload fails to decode'
   end
   j['payload'], _, err = json.decode(val)
   if err then
      return nil, 'malformed payload JSON'
   end

   j.signature, err = base64url_decode(r['signature'], base64url_decoder)
   if err ~= nil then
      return nil, 'paiload fails to decode'
   end

   setmetatable(j, jwt_metatable)
   return j, nil
end

function _M.build(payload, secret)
   local j = {}
   j.header = {
      typ = S.JWT,
      alg = "HS256"
   }
   j.payload = payload
   j.raw = {}
   j.raw.header = base64url_encode(json.encode(j.header))
   j.raw.payload = base64url_encode(json.encode(j.payload))
   j.signature = jwt_sign(j, secret)
   return j.raw.header .. '.' .. j.raw.payload .. '.' .. base64url_encode(j.signature)
end

return _M
