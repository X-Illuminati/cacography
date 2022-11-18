#!/bin/sh
#Routing table teardown for wireguard interface

#User Configuration Options:
WG_INTERFACE_NAME="wg0"

# bail-out if a different interface is being updated
if [ "$DEVICE_IP_IFACE" != "$WG_INTERFACE_NAME" ]; then
        exit 0
fi

# Script location - this is created by the pre-up script
TMPDN="/tmp/${WG_INTERFACE_NAME}-route-teardown"

echo "$(basename "$0"): $DEVICE_IP_IFACE pre-down script executing"
# check file permissions to ensure it hasn't been tampered with
if ! stat "${TMPDN}" --printf "%A %u %g\n" | grep -q ".r...-..-. 0"; then
	if ! stat "${TMPDN}" --printf "%A %u %g\n" | grep -q ".r......-. 0 0"; then
		exit 1
	fi
fi

# source the script to teardown the routes
cat "$TMPDN"
. "$TMPDN"
