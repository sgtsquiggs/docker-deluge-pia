#!/usr/bin/with-contenv bash

bind_addr="$( cat /opt/piavpn-manual/bind_addr )"
port="$( cat /opt/piavpn-manual/port )"

# If deluge-pre-start.sh exists, run it
if [ -x /config/deluge-pre-start.sh ]; then
  echo "Executing /config/deluge-pre-start.sh"
  /config/deluge-pre-start.sh "$@" || exit 1
fi

if [ -e /config/core.conf ]
then
  log "Updating Deluge conf file: listen_interface=$bind_addr"
  sed -i -e "s/\"listen_interface\": \".*\"/\"listen_interface\": \"$bind_addr\"/" /config/core.conf
fi

echo "Starting Deluge"
s6-svc -u /var/run/s6/services/deluged

echo "Setting Deluge listen_interface"
deluge-console -c /config "config --set listen_interface '$bind_addr'"

echo "Setting Deluge listen_ports"
deluge_peer_port=$(deluge-console -c /config "config listen_ports" | grep listen_ports | grep -oE '[0-9]+' | head -1)
if [ "$port" != "$deluge_peer_port" ]; then
  deluge-console -c /config "config --set listen_ports ($port,$port)"
  deluge-console -c /config "config --set random_port false"
fi


# If deluge-post-start.sh exists, run it
if [ -x /config/deluge-post-start.sh ]; then
  log "Executing /config/deluge-post-start.sh"
  /config/deluge-post-start.sh "$@" || exit 1
fi
