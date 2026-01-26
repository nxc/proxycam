local storage = require 'digest-redis'

local function key(id, host, url)
   return id .. '@' .. host .. url
end

local function suburl(url)
   if url ~= '/' then
      url = string.match(url, "(.-)[/]?$")
   end
   return function ()
      r = url
      if r then
	 url = string.match(r, "(.*)/[^/]+$")
      end
      if r == '' then
	 return '/'
      else
	 return r
      end
   end
end   
	 
function digest_retrieve(id, host, url)
   for s in suburl(url) do
      local k = key(id,host,s)
      v = storage.retrieve(k)
      pound.log(pound.INFO, "retrieving "..k.." = "..pound.dump(v))
      if v then
	 local d = v
	 v.nc = v.nc + 1
	 storage.store(k,v)
	 return d
      end
   end
   return nil
end

function digest_store(id, host, utab, v)
   for _, url in ipairs(utab) do
      local k = key(id,host,url)
      pound.log(pound.INFO, "storing "..k.." = "..pound.dump(v))
      storage.store(k, v)
   end
end

function digest_delete(id, host, utab)
   for url in ipairs(utab) do
      storage.delete(key(id,host,url))
   end
end

return M
