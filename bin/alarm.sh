#!/bin/bash -m
# apparently, have to use bash because sh will only
# allow job control when running from a TTY

ALARM="/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

script_main()
{
    set -o monitor
    echo "alarm.sh started"

    { while true; do paplay "${ALARM}" ; done } &

    notify-send -t 0 -A Acknowledge -a "Alarm" "Alarm Expired"

    kill %1
} # >>test.log 2>&1

script_main "$@"
