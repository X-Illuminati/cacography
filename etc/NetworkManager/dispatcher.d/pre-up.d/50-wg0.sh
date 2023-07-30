#!/bin/sh
#Routing table setup for wireguard interface

#User Configuration Options:
WG_INTERFACE_NAME="wg0"
ENDPOINT_DNS_NAME="..."
IPV4_INTERNAL_NET="192.168.x.0/24"
IPV6_INTERNAL_NET="...::1/64"

# bail-out if a different interface is being updated
if [ "$DEVICE_IP_IFACE" != "$WG_INTERFACE_NAME" ]; then
        exit 0
fi

echo "$(basename "$0"): $DEVICE_IP_IFACE pre-up script executing"

#Helper Variables:
TMPUP="/run/${WG_INTERFACE_NAME}-route-bringup"
TMPDN="/run/${WG_INTERFACE_NAME}-route-teardown"
if [ ! -z "$ENDPOINT_DNS_NAME" ]; then
	echo "checking $ENDPOINT_DNS_NAME"
	IPV4_ENDPOINT="$(host "${ENDPOINT_DNS_NAME}" | grep -m 1 "has address" | cut -d ' ' -f 4)"
	echo "IPv4: $IPV4_ENDPOINT"
	IPV6_ENDPOINT="$(host "${ENDPOINT_DNS_NAME}" | grep -m 1 "has IPv6 address" | cut -d ' ' -f 5)"
	echo "IPv6: $IPV6_ENDPOINT"
fi
IPV4_DEFAULT_ROUTE="$(ip route show default | grep -v "${WG_INTERFACE_NAME}" | head -n 1)"
IPV6_DEFAULT_ROUTE="$(ip -6 route show default | grep -v "${WG_INTERFACE_NAME}" | head -n 1)"
echo "#${DEVICE_IP_IFACE} Routing Table Bringup" > "$TMPUP"
echo "#${DEVICE_IP_IFACE} Routing Table Teardown" > "$TMPDN"

#GW IP:
IPV4_GW_IP="$(echo "${IPV4_DEFAULT_ROUTE}" | sed -e 's/default via \([[:digit:].]*\) .*/\1/')"
IPV6_GW_IP="$(echo "${IPV6_DEFAULT_ROUTE}" | sed -e 's/default via \([[:alnum:]:]*\) .*/\1/')"

#GW dev:
IPV4_GW_DEV="$(echo "${IPV4_DEFAULT_ROUTE}" | sed -e 's/.*dev \([[:alnum:]]*\).*/\1/')"
IPV6_GW_DEV="$(echo "${IPV6_DEFAULT_ROUTE}" | sed -e 's/.*dev \([[:alnum:]]*\).*/\1/')"

#Calculate Route to GW:
IPV4_GW_ROUTE="$(echo "${IPV4_DEFAULT_ROUTE}" | sed -e 's/default via //;s/ proto [[:alnum:]]*//;s/ metric [[:digit:]]*//')"
IPV6_GW_ROUTE="$(echo "${IPV6_DEFAULT_ROUTE}"  | sed -e 's/default via //;s/ proto [[:alnum:]]*//;s/ metric [[:digit:]]*//')"

#Create TMPUP/TMPDN scripts
###########################
#IPv4 Routes:
#############
if [ -n "$IPV4_DEFAULT_ROUTE" ]; then
	# We need to keep an active route to the gateway via the current
	# interface just in case it will get overridden by other routes that
	# go through wg.
	echo "ip route add ${IPV4_GW_ROUTE} metric 10" >> "$TMPUP"
	echo "ip route del ${IPV4_GW_ROUTE} metric 10" >> "$TMPDN"

	if [ -n "$IPV4_ENDPOINT" ]; then
		# We need to ensure an active route to our endpoint address via the
		# current interface even after the new default route pushes everything
		# through wg.
		echo "ip route add ${IPV4_ENDPOINT}/32 via ${IPV4_GW_IP} dev ${IPV4_GW_DEV} metric 20" >> "$TMPUP"
		echo "ip route del ${IPV4_ENDPOINT}/32 via ${IPV4_GW_IP} dev ${IPV4_GW_DEV} metric 20" >> "$TMPDN"
	fi
fi

# We need to provide a route to the remote "internal" network via wg
# in case the local "internal" network happens to use the same IP
# subnet. However, this will have the side-effect of blocking the local
# addresses on the network.
echo "ip route add ${IPV4_INTERNAL_NET} dev ${DEVICE_IP_IFACE} metric 60" >> "$TMPUP"
echo "ip route del ${IPV4_INTERNAL_NET} dev ${DEVICE_IP_IFACE} metric 60" >> "$TMPDN"

#IPv6 Routes:
#############
if [ -n "$IPV6_DEFAULT_ROUTE" ]; then
	# We need to keep an active route to the gateway via the current
	# interface just in case it will get overridden by other routes that
	# go through wg.
	echo "ip -6 route add ${IPV6_GW_ROUTE} metric 10" >> "$TMPUP"
	echo "ip -6 route del ${IPV6_GW_ROUTE} metric 10" >> "$TMPDN"

	if [ -n "$IPV6_ENDPOINT" ]; then
		# We need to ensure an active route to our endpoint address via the
		# current interface even after the new default route pushes everything
		# through wg.
		echo "ip -6 route add ${IPV6_ENDPOINT}/128 via ${IPV6_GW_IP} dev ${IPV6_GW_DEV} metric 20" >> "$TMPUP"
		echo "ip -6 route del ${IPV6_ENDPOINT}/128 via ${IPV6_GW_IP} dev ${IPV6_GW_DEV} metric 20" >> "$TMPDN"
	fi
fi

# We need to provide a route to the remote "internal" network via wg
# in case the local "internal" network happens to use the same IP
# subnet. However, this will have the side-effect of blocking the local
# addresses on the network.
echo "ip -6 route add ${IPV6_INTERNAL_NET} dev ${DEVICE_IP_IFACE} metric 60" >> "$TMPUP"
echo "ip -6 route del ${IPV6_INTERNAL_NET} dev ${DEVICE_IP_IFACE} metric 60" >> "$TMPDN"

