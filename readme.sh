#!/usr/bin/env bash
set -e

server_table="#### Valid server IDs (as of $(date "+%B %d, %Y"))
id | name | geolocated
:-- | :-- | :--
$(curl https://serverlist.piaservers.net/vpninfo/servers/v4 | head -n1 \
  | jq -r '.regions |
    sort_by(.name)
      | .[]
      | select(.port_forward==true)
      | .id+" | "+.name+" | "+(.geo|tostring)')"

quoteSubst() {
  IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
  printf %s "${REPLY%$'\n'}"
}

readme=$(sed "/./{H;\$!d} ; x ; s/#### Valid server IDs.*/$(quoteSubst "$server_table")/" README.md)

echo "$readme" | tail --lines=+2 > README.md
