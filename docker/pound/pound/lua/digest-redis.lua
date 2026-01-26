local M = {}
local redis = require 'redis'

M.cli = redis.connect(os.getenv('REDIS_HOST') or 'redis',
		      os.getenv('REDIS_PORT') or 6379)
M.ttl = os.getenv('REDIS_TTL') or 60

function M.retrieve(key)
   val = M.cli:get(key)
   if val then
      local digest
      local chunk, err = load("return "..val)
      if chunk then
	 local ok, result = pcall(chunk)
	 if ok then
	    digest = result
	 else
	    pound.log(pound.INFO, "retrieving key "..key..": "..tostring(result))
	 end
      else	 
	 pound.log(pound.INFO, "retrieving key "..key..": "..tostring(err))
      end
      return digest
   end
   return nil
end

function M.store(key, digest)
   t, e = pound.dump(digest)
   if not t then
      pound.log(pound.NOTICE, "can't dump digest: "..e)
   else
      M.cli:set(key, t, "EX", M.ttl)
   end
end

function M.delete(key)
   M.cli:del(key)
end

return M

      

	 
