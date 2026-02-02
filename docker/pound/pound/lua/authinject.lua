local M = {}
local auth_digest = require "http-auth-digest"

local sockurl = require "socket.url"

local function normalize_url(host)
   local url = sockurl.parse(host)
   local username, password = url.user, url.password
   url.user, url.password, url.authority, url.userinfo, url.query =
      nil, nil, nil, nil, nil
   return sockurl.build(url), username, password
end

local function get_id()
   local ok,sig = pcall(function () return stash.bearer.jwt.raw.signature end)
   if ok then
      return sig
   else
      return tostring(pound.tid)
   end
end

function M.inject(base_url)
   local digest = pound.gcall("digest_retrieve", get_id(),
			      normalize_url(base_url),
			      http.req.path)
   if digest then
      auth_digest.cast(digest)
--      pound.log(pound.INFO, "Digest="..pound.dump(digest))
      http.req.headers['Authorization'] = {
	 digest:create_header(http.req.url, http.req.method)
      }
   end
end

local sockhttp = require "socket.http"
local http_reason = {
   [100] = "Continue",
   [101] = "Switching Protocols",
   [102] = "Processing",
   [103] = "Early Hints",
   [200] = "OK",
   [201] = "Created",
   [202] = "Accepted",
   [203] = "Non-Authoritative Information",
   [204] = "No Content",
   [205] = "Reset Content",
   [206] = "Partial Content",
   [207] = "Multi-Status",
   [208] = "Already Reported",
   [226] = "IM Used",
   [300] = "Multiple Choices",
   [301] = "Moved Permanently",
   [302] = "Found",
   [303] = "See Other",
   [305] = "Use Proxy",
   [306] = "Switch Proxy",
   [307] = "Temporary Redirect",
   [308] = "Permanent Redirect",
}

function M.reauth(base_url)   
   if http.resp.code ~= 401 then
      return
   end
   if not http.resp.headers["www-authenticate"] then
      pound.log(pound.INFO, "ignoring 401 without www-authenticate")
      return
   end

   local host, username, password = normalize_url(base_url)
   
   digest, utab, err = auth_digest.redo(username, password,
				        http.resp.headers["www-authenticate"])
   if not digest then
      pound.log(pound.INFO, err)
      return
   end

   pound.gcall("digest_store", get_id(), host, utab, digest)
   
   http.resp.headers['Authorization'] = {
      digest:create_header(http.req.url, http.req.method)
   }
   http.resend = true
   return
end

return M
