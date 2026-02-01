define(`DEFSERVICE',`dnl
divert(-1)
pushdef(`SCHEME',`patsubst($2,`://.*')')

pushdef(`HOST',`patsubst(patsubst(patsubst($2,`^.*://'),`^.*:.*@'),`/.*$')')
pushdef(`HOSTPART',`patsubst(HOST,`:.*$')')

pushdef(`IP',`ifelse($3,,dnl
`pushdef(`ip',`esyscmd(dig +short HOSTPART|tail -1|tr -d \\n)')dnl
ifelse(ip,,HOSTPART,ip)dnl
popdef(`ip')',$3)')

pushdef(`PORT',`ifelse($4,,dnl
`pushdef(`p',`patsubst(HOST,`^.*:')')dnl
ifelse(p,HOST,`ifelse(SCHEME,`https',443,80)',p)dnl
popdef(`p')',$4)')
divert(0)dnl
	Service "camera:$1"
		LuaMatch "bearer.check_service" "$1"
		Rewrite request
			LuaModify "authinject.inject" "$2"
		End
		Rewrite response
			LuaModify "authinject.reauth" "$2"
			SetHeader "Access-Control-Allow-Origin: *"
		End
		Backend
			Address IP
			Port PORT
ifelse(SCHEME,`https',`dnl
			HTTPS
ifelse(HOSTPART,IP,,`dnl
			ServerName "HOSTPART"'
)')dnl			
		End
	End`'dnl
popdef(`SCHEME')dnl
popdef(`HOST')dnl
popdef(`HOSTPART')dnl
popdef(`IP')dnl
popdef(`PORT')dnl
')dnl
