#!/bin/bash

echo "Begin sync-videos-ods.sh"
if [ ! -f Shares/boxy/MOVIES/VIDEOS.ods ]; then
	# first attempt to access remote share may trigger the service to
	# notice it is no longer connected
	# wait a few seconds and then trigger the remount
	/usr/bin/sleep $((RANDOM * 100/32767))
	/usr/bin/systemctl --user start home-cbaker-Shares-boxy.mount
fi

if [ ! -f Shares/boxy/MOVIES/VIDEOS.ods ]; then
	echo "Could not find VIDEOS.ods or boxy is unmounted"
	exit 1
fi

if [ -f Shares/boxy/MOVIES/.~lock.VIDEOS.ods# ]; then
	echo "Warning: lockfile exists when copying VIDEOS.ods ($(cat Shares/boxy/MOVIES/.~lock.VIDEOS.ods#))"
fi

if [ -f Videos/.~lock.VIDEOS.ods# ]; then
	echo "Error: lockfile for VIDEOS.ods exists at destination ($(cat Videos/.~lock.VIDEOS.ods#))"
	exit 1
fi

if [ Videos/VIDEOS.ods -nt Shares/boxy/MOVIES/VIDEOS.ods ]; then
	echo "Warning: local VIDEOS.ods is newer than remote copy; aborting"
	exit 1
fi

rm -f Videos/.~VIDEOS.ods
cp -a Shares/boxy/MOVIES/VIDEOS.ods Videos/.~VIDEOS.ods
if [ -s Videos/.~VIDEOS.ods ]; then
	mv Videos/.~VIDEOS.ods Videos/VIDEOS.ods
	echo "Successfully copied VIDEOS.ods from boxy"
else
	rm -f Videos/.~VIDEOS.ods
	echo "Error: failed to copy VIDEOS.ods from boxy"
fi

