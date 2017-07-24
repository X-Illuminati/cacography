#!/bin/sh -e

[ -z "$DIFF" ] && DIFF="/usr/bin/diff"
[ -z "$BASH" ] || shopt -s xpg_echo

access_test ()
{
	/usr/bin/dd if="$1" bs=1 count=1 > /dev/null 2>&1
}

compare_files ()
{
	access_test "$2" || {
		echo "Unable to access \033[1m$2\033[0m"
		return 1
	}

	/usr/bin/cmp -s "$1" "$2" || {
		echo "Files \033[1m$1\033[0m and \033[1m$2\033[0m do not match."
		while :; do
			read -p "[V]iew [C]opy [S]kip ? " i
			case $i in
			v*|V*)
				echo "Comparing \033[1m$2\033[0m to \033[1m$1\033[0m"
				"$DIFF" "$2" "$1"
				compare_files "$1" "$2"
				break
				;;
			c*|C*)
				echo "Copying \033[1m$2\033[0m to \033[1m$1\033[0m"
				/usr/bin/cp "$2" "$1"
				return 0
				;;
			s*|S*)
				return 1
				;;
			*)
				;;
			esac
		done
	}
}

script_main ()
{
	local count
	local skips
	local matches
	count=0
	skips=0
	matches=0

	# Places a list of pairs of files into the positional argument array
	# The first file in each pair is the location of the file in the git
	# repository. The second is the location of the file in the filesystem.
	set -- \
	 "home/.bash_alias"            "$HOME/.bash_alias" \
	 "notes/linux_array_setup.txt" "$HOME/linux_array_setup.txt" \
	 "bin/dumptemps.sh"            "/usr/local/bin/dumptemps.sh" \
	 "bin/folder-compare.sh"       "/usr/local/bin/folder-compare.sh" \
	 "bin/uri-open.sh"             "/usr/local/bin/uri-open.sh" \
	 "bin/raid-check"              "/usr/sbin/raid-check" \
	 "bin/mdadm-syslog-events"     "/usr/sbin/mdadm-syslog-events" \
	 "bin/notify-all.sh"           "/usr/local/sbin/notify-all.sh" \
	 "cron.d/md-compare"           "/etc/cron.d/md-compare" \
	 "cron.d/raid-check"           "/etc/cron.d/raid-check" \
	 "cron.d/temp-report"          "/etc/cron.d/temp-report" \
	 "etc/raid-check"              "/etc/sysconfig/raid-check" \
	 "etc/mdadm.conf"              "/etc/mdadm.conf" \
	 "etc/smb.conf"                "/etc/samba/smb.conf" \

	while [ $# -gt 1 ]; do
		count=$((count+1))
		compare_files "$1" "$2" \
			&& matches=$((matches+1)) \
			|| skips=$((skips+1))
		shift 2
	done
	echo "Compared $count files."
	echo "  $matches are identical"
	[ $skips -eq 0 ] \
		&& echo "  none are different" \
		|| echo "  \033[1m$skips skipped\033[0m"
}

script_main "$@"
