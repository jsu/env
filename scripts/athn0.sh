#!/bin/sh
#nwid 'Nanjing-2014'
#wpakey 8dcdb11e66d3462681838fbc0da9d658
#nwid 'Lakewood 2.4GHz'
#wpakey loveyouteina
#nwid 'Candlewood Suites Herndon'
#nwid 'epals-guest'
#wpakey apple123
#nwid 'Lakewood'
#wpakey loveyoualiyun

epals="nwid 'epals-guest' wpakey 'apple123'"
lakewood="nwid 'AirPort Wifi' wpakey 'a13ebadd7dedf777c99928d3af5d0ab7262a59d147f3061eea01920a15d347e'"
home="nwid 'Lakewood 2.4GHz' wpakey 'loveyouteina'"
tinkerbell="nwid 'Tinkerbell' wpakey 'holkvyrn'"

if [ $# -ne 1 ]
then
    echo "sh athn0 <settings>"
    exit 0
fi

eval SSID=\$${1}

if [ "x${SSID}" = "x" ]
then
    echo "Invalid settings: ${1}"
    exit 0
fi

echo "ifconfig athn0 ${SSID}"
sudo ifconfig athn0 ${SSID}
sudo dhclient athn0
