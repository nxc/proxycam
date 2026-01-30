local _M = {}

function _M.IsOptions()
   return string.lower(http.req.method) == "options"
end

function _M.BackEnd()
   http.resp.code = 200
   http.resp.headers['Access-Control-Allow-Origin'] = '*'
   http.resp.headers['Access-Control-Allow-Methods'] = "GET,POST,PUT,DELETE,OPTIONS"
   http.resp.headers['Access-Control-Max-Age'] = 3600
   http.resp.headers['Access-Control-Allow-Headers'] = '*'
end

return _M
