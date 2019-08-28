#!/bin/sh

if [ "$USER" != "root" ]; then
	echo "You must run this script using sudo"
else
	pgrep -x spacenavd > /dev/null && {
		echo "Killing existing spacenavd"

		systemctl stop spacenavd.service
		killall spacenavd
	}

	echo "Discovered spacenav devices:"
	grep 3Dconnexion /proc/bus/input/devices

	mousedev=$(grep 3Dconnexion /proc/bus/input/devices -A10 | grep -o -E "mouse[0-9]+")
	for file in $mousedev; do
		[ -c "/dev/input/$file" ] && {
			echo "Removing $mousedev from /dev/input"
			rm "/dev/input/$mousedev"
		}
	done

	echo "Starting spacenavd (log at /var/log/spnavd.log)"
	spacenavd -v && {
		sleep 1
		echo "Verify performance:"
		sptest
	}
fi
