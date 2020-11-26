#!/usr/bin/with-contenv bash

# If deluge-pre-stop.sh exists, run it
if [ -x /config/deluge-pre-stop.sh ]; then
   log "Executing /config/deluge-pre-stop.sh"
   /config/deluge-pre-stop.sh "$@" || exit 1
fi

echo "Stopping deluge"
s6-svc -d /var/run/s6/services/deluged

# If deluge-post-stop.sh exists, run it
if [ -x /config/deluge-post-stop.sh ]; then
   log "Executing /config/deluge-post-stop.sh"
   /config/deluge-post-stop.sh "$@" || exit 1
fi
