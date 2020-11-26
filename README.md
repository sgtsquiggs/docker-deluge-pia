# [sgtsquiggs/deluge-pia](https://hub.docker.com/repository/docker/sgtsquiggs/deluge-pia)

For deluge configuration please see [linuxserver/deluge](https://docs.linuxserver.io/images/docker-deluge).

## OpenVPN Configuration:

### Environment Variables (-e)
```
PIA_SERVER         server id to connect to (default: auto)
MAX_LATENCY        server autoselect max latency in seconds (default: 0.05)
PIA_USER           pia username
PIA_PASS           pia password
PIA_MODE           one of:
                      - openvpn_udp_standard (default)
                      - openvpn_tcp_standard
                      - openvpn_udp_strong
                      - openvpn_tcp_strong
```

#### Notes:
* MAX_LATENCY is ignored when PIA_SERVER is not `auto`
* PIA_MODE:
  * "standard" means aes-128-cbc cipher, sha1
  * "strong" means aes-256-cbc cipher, sha256

#### Valid server IDs (as of November 25, 2020)
id | name | geolocated
:-- | :-- | :--
aus_melbourne | AU Melbourne | false
aus_perth | AU Perth | false
aus | AU Sydney | false
al | Albania | false
dz | Algeria | true
ad | Andorra | true
ar | Argentina | false
yerevan | Armenia | true
austria | Austria | false
bahamas | Bahamas | true
bangladesh | Bangladesh | true
belgium | Belgium | false
br | Brazil | true
sofia | Bulgaria | false
ca | CA Montreal | false
ca_ontario | CA Ontario | false
ca_toronto | CA Toronto | false
ca_vancouver | CA Vancouver | false
cambodia | Cambodia | true
china | China | true
cyprus | Cyprus | true
czech | Czech Republic | false
de_berlin | DE Berlin | false
de-frankfurt | DE Frankfurt | false
denmark | Denmark | false
egypt | Egypt | true
ee | Estonia | false
fi | Finland | false
france | France | false
georgia | Georgia | true
gr | Greece | false
greenland | Greenland | true
hk | Hong Kong | true
hungary | Hungary | false
is | Iceland | false
in | India | false
ireland | Ireland | false
man | Isle of Man | true
israel | Israel | false
italy | Italy | false
japan | Japan | false
kazakhstan | Kazakhstan | true
lv | Latvia | false
liechtenstein | Liechtenstein | true
lt | Lithuania | false
lu | Luxembourg | false
macau | Macao | true
mk | Macedonia | false
malta | Malta | true
mexico | Mexico | true
md | Moldova | false
monaco | Monaco | true
mongolia | Mongolia | true
montenegro | Montenegro | true
morocco | Morocco | true
nl_amsterdam | Netherlands | false
nz | New Zealand | false
nigeria | Nigeria | false
no | Norway | false
panama | Panama | true
philippines | Philippines | true
poland | Poland | false
pt | Portugal | false
qatar | Qatar | true
ro | Romania | false
saudiarabia | Saudi Arabia | true
rs | Serbia | false
sg | Singapore | false
sk | Slovakia | false
za | South Africa | false
spain | Spain | false
srilanka | Sri Lanka | true
sweden | Sweden | false
swiss | Switzerland | false
taiwan | Taiwan | true
tr | Turkey | true
uk | UK London | false
uk_manchester | UK Manchester | false
uk_southampton | UK Southampton | false
ua | Ukraine | false
ae | United Arab Emirates | true
venezuela | Venezuela | true
vietnam | Vietnam | true
