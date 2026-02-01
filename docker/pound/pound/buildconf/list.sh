#! /bin/sh

while :
do
    if nc -z 127.0.0.1 8080 2>/dev/null; then
	break
    fi
    sleep 1
done

poundctl -t /etc/pound/buildconf/cameras.tmpl
tail -f /dev/null

