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

function M.inject(base_url)
   local digest = pound.gcall("digest_retrieve", "id", normalize_url(base_url),
			      http.req.path)
   if digest then
      auth_digest.cast(digest)
--      pound.log(pound.INFO, "Digest="..pound.dump(digest))
      http.req.headers['Authorization'] =
	 digest:create_header(http.req.url, http.req.method)
   end
end

local sockhttp = require "socket.http"
local sockurl = require "socket.url"
local ltn12 = require "ltn12"

local function hdrdup(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

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
   local host, username, password = normalize_url(base_url)
   if http.resp.code ~= 401 then
      return
   end
   if not http.resp.headers["www-authenticate"] then
      pound.log(pound.INFO, "ignoring 401 without www-authenticate")
      return
   end
   digest, utab, err = auth_digest.redo(username, password,
				        http.resp.headers["www-authenticate"])
   if not digest then
      pound.log(pound.INFO, err)
      return
   end

   local headers = hdrdup(http.req.headers)
   headers['Authorization'] = digest:create_header(http.req.url, http.req.method)
   
   local source
   if #http.req.body > 0 then
      -- FIXME: That won't work for chunked.
      source = ltn12.source.string(http.req.body)
   end
   
   local content = {}
   local params = {
	 method = http.req.method,
	 url = host .. http.req.url,
	 headers = headers,
	 sink = ltn12.sink.table(content),
	 source = source
   }
   
   local _, c, h = sockhttp.request(params)

   if c ~= nil and type(c) == 'number' and c < 400 then
      -- save the digest
      pound.gcall("digest_store", "id", host, utab, digest)
      
      http.resp.code = c
      http.resp.reason = http_reason[c]
      http.resp.headers = h
      http.resp.body = table.concat(content)
   end
end

return M
