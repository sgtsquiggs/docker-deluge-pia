#!/usr/bin/with-contenv bash


# This function checks the latency you have to a specific region.
# It will print a human-readable message to stderr,
# and it will print the variables to stdout
printServerLatency() {
  serverIP="$1"
  regionID="$2"
  regionName="$(echo ${@:3} |
    sed 's/ false//' | sed 's/true/(geo)/')"
  time=$(LC_NUMERIC=en_US.utf8 curl -o /dev/null -s \
    --connect-timeout $MAX_LATENCY \
    --write-out "%{time_connect}" \
    http://$serverIP:443)
  if [ $? -eq 0 ]; then
    >&2 echo Got latency ${time}s for region: $regionName
    echo $time $regionID $serverIP
  fi
}
export -f printServerLatency

# The default value is 50 milliseconds.
MAX_LATENCY=${MAX_LATENCY:-0.05}
export MAX_LATENCY

serverlist_url='https://serverlist.piaservers.net/vpninfo/servers/v4'

echo -n "Getting the server list... "
# Get all region data since we will need this on multiple occasions
all_region_data=$(curl -s "$serverlist_url" | head -1)

# If the server list has less than 1000 characters, it means curl failed.
if [[ ${#all_region_data} -lt 1000 ]]; then
  echo "Could not get correct region data."
  exit 1
fi
# Notify the user that we got the server list.
echo "OK!"

if [ "$PIA_SERVER" == "auto" ]; then
  # Test one server from each region to get the closest region.
  # If port forwarding is enabled, filter out regions that don't support it.
  echo Port Forwarding is enabled, so regions that do not support
  echo port forwarding will get filtered out.
  summarized_region_data="$( echo $all_region_data |
    jq -r '.regions[] | select(.port_forward==true) |
    .servers.meta[0].ip+" "+.id+" "+.name+" "+(.geo|tostring)' )"

  echo Testing regions that respond \
    faster than $MAX_LATENCY seconds:
  bestRegion="$(echo "$summarized_region_data" |
    xargs -I{} bash -c 'printServerLatency {}' |
    sort | head -1 | awk '{ print $2 }')"

  if [ -z "$bestRegion" ]; then
    echo ...
    echo No region responded within ${MAX_LATENCY}s, consider using a higher timeout.
    exit 1
  fi
else
  bestRegion="$PIA_SERVER"
fi

# Get all data for the best region
regionData="$( echo $all_region_data |
  jq --arg REGION_ID "$bestRegion" -r \
  '.regions[] | select(.id==$REGION_ID)')"


if [ "$PIA_SERVER" == "auto" ]; then
  echo -n The closest region is "$(echo $regionData | jq -r '.name')"
  if echo $regionData | jq -r '.geo' | grep true > /dev/null; then
    echo " (geolocated region)."
  else
    echo "."
  fi
fi

bestServer_meta_IP="$(echo $regionData | jq -r '.servers.meta[0].ip')"
bestServer_meta_hostname="$(echo $regionData | jq -r '.servers.meta[0].cn')"
bestServer_OT_IP="$(echo $regionData | jq -r '.servers.ovpntcp[0].ip')"
bestServer_OT_hostname="$(echo $regionData | jq -r '.servers.ovpntcp[0].cn')"
bestServer_OU_IP="$(echo $regionData | jq -r '.servers.ovpnudp[0].ip')"
bestServer_OU_hostname="$(echo $regionData | jq -r '.servers.ovpnudp[0].cn')"

echo "Trying to get a new token by authenticating with the meta service..."
generateTokenResponse=$(curl -s -u "$PIA_USER:$PIA_PASS" \
  --connect-to "$bestServer_meta_hostname::$bestServer_meta_IP:" \
  --cacert "ca.rsa.4096.crt" \
  "https://$bestServer_meta_hostname/authv3/generateToken")

if [ "$(echo "$generateTokenResponse" | jq -r '.status')" != "OK" ]; then
  echo "Could not get a token. Please check your account credentials."
  exit 1
fi

token="$(echo "$generateTokenResponse" | jq -r '.token')"

serverIP=$bestServer_OU_IP
serverHostname=$bestServer_OU_hostname
if [[ $PIA_MODE == *tcp* ]]; then
serverIP=$bestServer_OT_IP
serverHostname=$bestServer_OT_hostname
fi


PIA_TOKEN="$token"
OVPN_SERVER_IP=$serverIP
OVPN_HOSTNAME=$serverHostname
CONNECTION_SETTINGS=$PIA_MODE

# PIA currently does not support IPv6. In order to be sure your VPN
# connection does not leak, it is best to disabled IPv6 altogether.
# IPv6 can also be disabled via kernel commandline param, so we must
# first check if this is the case.
if [[ -f /proc/net/if_inet6 ]] &&
  [[ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -ne 1 ||
     $(sysctl -n net.ipv6.conf.default.disable_ipv6) -ne 1 ]]
then
  echo 'You should consider disabling IPv6 by running:'
  echo 'sysctl -w net.ipv6.conf.all.disable_ipv6=1'
  echo 'sysctl -w net.ipv6.conf.default.disable_ipv6=1'
fi

# Create a credentials file with the login token
echo "Trying to write /opt/piavpn-manual/pia.ovpn...
"
mkdir -p /opt/piavpn-manual
rm -f /opt/piavpn-manual/credentials /opt/piavpn-manual/route_info
echo ${PIA_TOKEN:0:62}"
"${PIA_TOKEN:62} > /opt/piavpn-manual/credentials || exit 1
chmod 600 /opt/piavpn-manual/credentials

# Translate connection settings variable
IFS='_'
read -ra connection_settings <<< "$CONNECTION_SETTINGS"
IFS=' '
protocol="${connection_settings[1]}"
encryption="${connection_settings[2]}"

prefix_filepath="standard.ovpn"
if [[ $encryption == "strong" ]]; then
  prefix_filepath="strong.ovpn"
fi

if [[ $protocol == "udp" ]]; then
  if [[ $encryption == "standard" ]]; then
    port=1198
  else
    port=1197
  fi
else
  if [[ $encryption == "standard" ]]; then
    port=502
  else
    port=501
  fi
fi

# Create the OpenVPN config based on the settings specified
cat $prefix_filepath > /opt/piavpn-manual/pia.ovpn || exit 1
echo remote $OVPN_SERVER_IP $port $protocol >> /opt/piavpn-manual/pia.ovpn

# Copy the up/down scripts to /opt/piavpn-manual/
cp openvpn_up.sh /opt/piavpn-manual/openvpn_up.sh
cp openvpn_down.sh /opt/piavpn-manual/openvpn_down.sh

# Start the OpenVPN interface.
# If something failed, stop this script.
# If you get DNS errors because you miss some packages,
# just hardcode /etc/resolv.conf to "nameserver 10.0.0.242".
#rm -f /opt/piavpn-manual/debug_info
echo "
Trying to start the OpenVPN connection..."
openvpn --daemon \
  --config "/opt/piavpn-manual/pia.ovpn" \
  --writepid "/opt/piavpn-manual/pia_pid" \
  --log "/opt/piavpn-manual/debug_info" || exit 1

echo "
The OpenVPN connect command was issued.

Confirming OpenVPN connection state... "

# Check if manual PIA OpenVPN connection is initialized.
# Manually adjust the connection_wait_time if needed
connection_wait_time=60
confirmation="Initialization Sequence Complete"
for (( timeout=0; timeout <=$connection_wait_time; timeout++ ))
do
  sleep 1
  if grep -q "$confirmation" /opt/piavpn-manual/debug_info; then
    connected=true
    break
  fi
done

ovpn_pid="$( cat /opt/piavpn-manual/pia_pid )"
gateway_ip="$( cat /opt/piavpn-manual/route_info )"

if [ "$connected" != true ]; then
  echo "The VPN connection was not established within $connection_wait_time seconds."
  kill $ovpn_pid
  exit 1
fi

echo "Initialization Sequence Complete!

At this point, internet should work via VPN.
"

echo "OpenVPN Process ID: $ovpn_pid
VPN route IP: $gateway_ip

To disconnect the VPN, run:

--> sudo kill $ovpn_pid <--
"


PF_GATEWAY="$gateway_ip"
PF_HOSTNAME="$OVPN_HOSTNAME"

echo "Getting new signature..."
payload_and_signature="$(curl -s -m 5 \
  --connect-to "$PF_HOSTNAME::$PF_GATEWAY:" \
  --cacert "ca.rsa.4096.crt" \
  -G --data-urlencode "token=${PIA_TOKEN}" \
  "https://${PF_HOSTNAME}:19999/getSignature")"
echo "$payload_and_signature"
export payload_and_signature

# Check if the payload and the signature are OK.
if [ "$(echo "$payload_and_signature" | jq -r '.status')" != "OK" ]; then
  echo "The payload_and_signature variable does not contain an OK status."
  exit 1
fi

# We need to get the signature out of the previous response.
# The signature will allow the us to bind the port on the server.
signature="$(echo "$payload_and_signature" | jq -r '.signature')"

# The payload has a base64 format. We need to extract it from the
# previous response and also get the following information out:
# - port: This is the port you got access to
# - expires_at: this is the date+time when the port expires
payload="$(echo "$payload_and_signature" | jq -r '.payload')"
port="$(echo "$payload" | base64 -d | jq -r '.port')"

# The port normally expires after 2 months. If you consider
# 2 months is not enough for your setup, please open a ticket.
expires_at="$(echo "$payload" | base64 -d | jq -r '.expires_at')"

# Display some information on the screen for the user.
echo "The signature is OK.

--> The port is $port and it will expire on $expires_at. <--

"

echo "$port" > /opt/piavpn-manual/port || exit 1


# Start deluge
/opt/deluge/up.sh


# Now we have all required data to create a request to bind the port.
# We will repeat this request every 15 minutes, in order to keep the port
# alive. The servers have no mechanism to track your activity, so they
# will just delete the port forwarding if you don't send keepalives.
while true; do
  bind_port_response="$(curl -Gs -m 5 \
    --connect-to "$PF_HOSTNAME::$PF_GATEWAY:" \
    --cacert "ca.rsa.4096.crt" \
    --data-urlencode "payload=${payload}" \
    --data-urlencode "signature=${signature}" \
    "https://${PF_HOSTNAME}:19999/bindPort")"
    echo "$bind_port_response"

    # If port did not bind, just exit the script.
    # This script will exit in 2 months, since the port will expire.
    export bind_port_response
    if [ "$(echo "$bind_port_response" | jq -r '.status')" != "OK" ]; then
      echo "The API did not return OK when trying to bind port. Exiting."
      exit 1
    fi
    echo Port $port refreshed on $(date). \
      This port will expire on $(date --date="$expires_at")

    # sleep 15 minutes
    sleep 900
done
