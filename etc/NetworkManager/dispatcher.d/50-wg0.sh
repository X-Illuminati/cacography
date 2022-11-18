#!/bin/sh
#Interface up/down setup for wireguard interface
#Configures routing tables since NetworkManager doesn't quite do the job on its own

#User Configuration Options:
WG_INTERFACE_NAME="wg0"

# bail-out if a different interface is being updated
if [ "$DEVICE_IP_IFACE" != "$WG_INTERFACE_NAME" ]; then
	exit 0
fi

case $2 in
	up)
		echo "$(basename "$0"): $DEVICE_IP_IFACE going up"

		# Script location - this is created by the pre-up script
	        TMPUP="/tmp/${WG_INTERFACE_NAME}-route-bringup"

		# check file permissions to ensure it hasn't been tampered with
		if ! stat "${TMPUP}" --printf "%A %u %g\n" | grep -q ".r...-..-. 0"; then
			if ! stat "${TMPUP}" --printf "%A %u %g\n" | grep -q ".r......-. 0 0"; then
				exit 1
			fi
		fi

		# source the script to setup the routes
		cat "$TMPUP"
		. "$TMPUP"
	;;

	down)
		echo "$(basename "$0"): $DEVICE_IP_IFACE going down"
	;;

	*)
		echo "$(basename "$0"): $DEVICE_IP_IFACE -> $2"
	;;
esac
