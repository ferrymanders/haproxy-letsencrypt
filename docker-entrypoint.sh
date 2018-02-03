#!/bin/sh
set -e

# Setup Dehydrated directories
[ -d /config/dehydrated/certs ] || mkdir -p /config/dehydrated/certs
[ -d /config/dehydrated/accounts ] || mkdir -p /config/dehydrated/accounts

# Register with letsencrypt
if [ "$LE_ACCEPT" == "YES" ]; then
  /usr/bin/dehydrated --register --accept-terms
fi

#Run tiny syslog to stdio redirector
/usr/bin/syslog-stdout &

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	shift # "haproxy"
	# if the user wants "haproxy", let's add a couple useful flags
	#   -W  -- "master-worker mode" (similar to the old "haproxy-systemd-wrapper"; allows for reload via "SIGUSR2")
	#   -db -- disables background mode
	set -- haproxy -W -db "$@"
fi

exec "$@"