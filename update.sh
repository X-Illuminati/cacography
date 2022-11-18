#!/bin/sh -e

[ -z "$DIFF" ] && DIFF="/usr/bin/diff"
[ -z "$XDG_CONFIG_HOME" ] && XDG_CONFIG_HOME="$HOME/.config"
[ -z "$XDG_DATA_HOME" ] && XDG_DATA_HOME="$HOME/.local"
BOLD="$(tput bold)"
OFFBOLD="$(tput sgr0)"

access_test ()
{
	/bin/dd if="$1" bs=1 count=1 > /dev/null 2>&1
}

compare_links()
{
	local l1
	local l2
	local i

	[ -h "$1" ] || {
		echo "${BOLD}$1${OFFBOLD} is not a symbolic link"
		return 1
	}
	l1="$(readlink "$1")"

	if [ -h "$2" ]; then
		l2="$(readlink "$2")"
		[ "$l1" = "$l2" ] || {
			echo "Symbolic links ${BOLD}$1${OFFBOLD} and ${BOLD}$2${OFFBOLD} do not match."
			echo "${BOLD}$1${OFFBOLD} is a symbolic link to $l1"
			echo "${BOLD}$2${OFFBOLD} is a symbolic link to $l2"
			while :; do
				read -p "[U]pdate [S]kip ? " i
				case $i in
				u*|u*)
					echo "Updating link ${BOLD}$1${OFFBOLD} to ${BOLD}$l2${OFFBOLD}"
					/bin/ln -sf -T "$l2" "$1"
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
	elif [ -f "$2" ]; then
		echo "File types for ${BOLD}$1${OFFBOLD} and ${BOLD}$2${OFFBOLD} do not match."
		echo "${BOLD}$1${OFFBOLD} is a symbolic link to $l1"
		echo "${BOLD}$2${OFFBOLD} is a regular file"
		while :; do
			read -p "[R]eplace [S]kip ? " i
			case $i in
			r*|R*)
				/bin/rm "$1"
				/bin/cp "$2" "$1"
				return 0
				;;
			s*|S*)
				return 1
				;;
			*)
				;;
			esac
		done
	else
		if [ -d "$2" ]; then
			l2="is a directory"
		elif [ -f "$2" ]; then
			l2="is a regular file"
		elif [ -e "$2" ]; then
			l2="is an unknown type"
		else
			l2="does not exist"
		fi
		echo "File types for ${BOLD}$1${OFFBOLD} and ${BOLD}$2${OFFBOLD} do not match."
		echo "${BOLD}$1${OFFBOLD} is a symbolic link to $l1"
		echo "${BOLD}$2${OFFBOLD} $l2"
		while :; do
			read -p "[S]kip ? " i
			case $i in
			s*|S*)
				return 1
				;;
			*)
				;;
			esac
		done
	fi
}

compare_files ()
{
	local i

	access_test "$2" || {
		echo "Unable to access ${BOLD}$2${OFFBOLD}"
		return 1
	}

	if [ -h "$1" ]; then
		compare_links "$@"
		return $?
	fi

	/usr/bin/cmp -s "$1" "$2" || {
		echo "Files ${BOLD}$1${OFFBOLD} and ${BOLD}$2${OFFBOLD} do not match."
		while :; do
			read -p "[V]iew [C]opy [S]kip ? " i
			case $i in
			v*|V*)
				echo "Comparing ${BOLD}$2${OFFBOLD} to ${BOLD}$1${OFFBOLD}"
				"$DIFF" "$2" "$1"
				compare_files "$1" "$2"
				return $?
				;;
			c*|C*)
				echo "Copying ${BOLD}$2${OFFBOLD} to ${BOLD}$1${OFFBOLD}"
				/bin/cp "$2" "$1"
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
	local dirlist
	local fname
	count=0
	skips=0
	matches=0

	# Places a list of pairs of files into the positional argument array
	# The first file in each pair is the location of the file in the git
	# repository. The second is the location of the file in the filesystem.
	set -- \
	 "home/.bash_alias"               "$HOME/.bash_alias" \
	 "home/.bash_alias"               "$HOME/.bash_aliases" \
	 "home/.bashrc"                   "$HOME/.bashrc" \
	 "home/bigclive.sh"               "$HOME/bigclive.sh" \
	 "home/happy-trees.sh"            "$HOME/happy-trees.sh" \
	 "home/randi-scandi.sh"           "$HOME/randi-scandi.sh" \
	 "home/good-news.sh"              "$HOME/good-news.sh" \
	 "home/swedish_murder_machine.sh" "$HOME/swedish_murder_machine.sh" \
	 "home/that-pudgy-tummy.sh"       "$HOME/that-pudgy-tummy.sh" \
	 "home/.config/screenlayout"      "$XDG_CONFIG_HOME/screenlayout" \
	 "home/.config/OpenSCAD/OpenSCAD.conf" \
		"$XDG_CONFIG_HOME/OpenSCAD/OpenSCAD.conf" \
	 "home/.config/pianobar"          "$XDG_CONFIG_HOME/pianobar" \
	 "home/.local/file-manager-actions/" \
		"$XDG_DATA_HOME/share/file-manager/actions/" \
	 "home/.local/kde-service-menus/" \
		"$XDG_DATA_HOME/share/kservices5/ServiceMenus/" \
	 "notes/linux_array_setup.txt"    "$HOME/linux_array_setup.txt" \
	 "bin/dumptemps.sh"               "/usr/local/bin/dumptemps.sh" \
	 "bin/folder-compare.sh"          "/usr/local/bin/folder-compare.sh" \
	 "bin/compare-helper.sh"          "/usr/local/bin/compare-helper.sh" \
	 "bin/uri-open.sh"                "/usr/local/bin/uri-open.sh" \
	 "bin/repeat.sh"                  "/usr/local/bin/repeat.sh" \
	 "bin/spstart.sh"                 "/usr/local/bin/spstart.sh" \
	 "bin/raid-check"                 "/usr/sbin/raid-check" \
	 "bin/mdadm-syslog-events"        "/usr/sbin/mdadm-syslog-events" \
	 "bin/notify-all.sh"              "/usr/local/sbin/notify-all.sh" \
	 "cron.d/md-compare"              "/etc/cron.d/md-compare" \
	 "cron.d/raid-check"              "/etc/cron.d/raid-check" \
	 "cron.d/temp-report"             "/etc/cron.d/temp-report" \
	 "etc/raid-check"                 "/etc/sysconfig/raid-check" \
	 "etc/mdadm.conf"                 "/etc/mdadm.conf" \
	 "etc/smb.conf"                   "/etc/samba/smb.conf" \
	 "etc/ssh_config"                 "/etc/ssh/ssh_config" \
	 "etc/sshd_config"                "/etc/ssh/sshd_config" \
	 "etc/NetworkManager/dispatcher.d/50-wg0.sh" \
		"/etc/NetworkManager/dispatcher.d/50-wg0.sh" \
	 "etc/NetworkManager/dispatcher.d/pre-down.d/50-wg0.sh" \
		"/etc/NetworkManager/dispatcher.d/pre-down.d/50-wg0.sh" \
	 "etc/NetworkManager/dispatcher.d/pre-up.d/50-wg0.sh" \
		"/etc/NetworkManager/dispatcher.d/pre-up.d/50-wg0.sh" \

	while [ $# -gt 1 ]; do
		if [ -d "$1" ]; then
			dirlist="$1/*"
			for fname in $dirlist; do
				count=$((count+1))
				compare_files "$fname" "$2/$(basename "$fname")" \
					&& matches=$((matches+1)) \
					|| skips=$((skips+1))
			done
		else
			count=$((count+1))
			compare_files "$1" "$2" \
				&& matches=$((matches+1)) \
				|| skips=$((skips+1))
		fi
		shift 2
	done
	echo "Compared $count files."
	echo "  $matches are identical"
	[ $skips -eq 0 ] \
		&& echo "  none are different" \
		|| echo "  ${BOLD}$skips skipped${OFFBOLD}"
}

script_main "$@"
