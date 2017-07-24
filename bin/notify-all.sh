#!/bin/sh

DISPLAYS=$(
	for envfile in /proc/*/environ; do
# 		cat $envfile | tr '\0' '\n' | grep -e "^DISPLAY="
		grep -z -e "^DISPLAY=" "$envfile"
	done | sort -zu | tr '\0' '\n'
)

USERS=$(
	for envfile in /proc/*/environ; do
# 		cat $envfile | tr '\0' '\n' | grep -e "^USER="
		grep -z -e "^USER=" "$envfile"
	done | sort -zu | tr '\0' '\n'
)

for disp in $DISPLAYS; do
	for user in $USERS; do
		eval "CUR_$disp"
		eval "CUR_$user"
		echo "Sending notification to user $CUR_USER on display $CUR_DISPLAY"
		sudo -u "$CUR_USER" DISPLAY="$CUR_DISPLAY" /usr/bin/notify-send "$@"
	done
done
