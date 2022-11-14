#!/bin/bash

[ -z "$PLAYER" ] && PLAYER="/usr/bin/vlc"
[ -z "$PLAYEROPT" ] && PLAYEROPT="-q -f --play-and-exit --no-spu --sub-language=en"
[ -z "$DESCOPT" ] && DESCOPT="--meta-description"
[ -z "$VIDDIR" ] && VIDDIR="$HOME/viddir-bigclive/"
[ -z "$FILTER" ] && FILTER="\.mp4\$|\.mkv\$|\.webm\$"
VIDSTRING="Things worthy of note"
REPLAYSTRING="Big Clive"

BOLD="$(tput bold)"
OFFBOLD="$(tput sgr0)"

#enable presentation mode because systemd-inhibit
#doesn't work on LXDE...
if type xfconf-query > /dev/null 2>&1; then
	PMODE="$(xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode)"
	restore_pmode() {
		xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode -s $PMODE
	}
	trap 'restore_pmode' EXIT
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode -s true
fi

#it appears that vlc traps SIGINT but then exit(0)
#instead of a typical failure code or raise()
trap 'echo interrupted; exit 130' INT

usage() {
	echo "Usage: $0 [-h|-l [QUERY]|FILE [FILE...]]\

Play a random video from \$VIDDIR or play FILE if specified.

FILE can be an exact or partial filename or a number as
returned by the -l option. As a number it can also be negative
to count backwards from the end.

Options:
  -h, --help   Display this help text
  -l, --list   List files in \$VIDDIR, optionally matching a query
  -u, --update Download recent videos
  -U, --full-update
               Download all videos
  -f, --fetch  Fetch a single video (e.g. if playlist not updated)

Environment Variables:
  VIDDIR     The directory containing the videos
             ($VIDDIR)
  FILTER     The 'grep' regex pattern used to find videos in VIDDIR
             ($FILTER)
  PLAYER     The video player application to use
             ($PLAYER)
  PLAYEROPT  General options for the video player
             ($PLAYEROPT)
  DESCOPT    Option to provide the video description to the player
             ($DESCOPT)
"
}

play() {
	local bname
	bname="${1%\.*}"
	if [ -f "$bname.description" -a -n "$DESCOPT" ]; then
		cat "$bname.description"
		echo
		echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
		"$PLAYER" $PLAYEROPT $DESCOPT "$(cat "$bname.description")" "$1" 2>/dev/null
	else
		"$PLAYER" $PLAYEROPT "$1"
	fi
}

random_vid() {
	local filename
	filename=$(ls -1 2>/dev/null | grep -E "$FILTER" | sort -R | head -1)
	echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "${VIDSTRING}: $filename"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
	play "$filename"
}

list_files() {
	local i
	local filenames
	local filelist
	local filenum
	local numfiles

	filelist="$(ls -1rt 2>/dev/null  | grep -E "$FILTER" | nl -s ": ")"

	if [ $# -eq 0 ]; then
		echo "$filelist"
	else
		for i in "$@"; do
			unset filenames
			if [ "$i" -lt 0 ] 2>/dev/null; then
				numfiles=$(echo "$filelist" | tail -n1 | cut -d ":" -f 1)
				# $1 should be a sanely formatted negative number here
				filenum=$(($numfiles + 1 + $i))
			else
				# $1 is possibly not a number here
				filenum="$i"
			fi


			filenames="$(echo "$filelist" | grep -s -E "^ *$filenum:")"

			if [ -z "$filenames" ]; then
				filenames="$(echo "$filelist" | grep -s -i "$i")"
			fi
			echo "$filenames"
		done
	fi
}

named_vid() {
	local i
	local filenames

	filenames="$(list_files "$@" | cut -d ":" -f 2- | cut -d " " -f 2-)"

	if [ -z "$filenames" ]; then
		echo "$1: not found"
		result=1
	else
		IFS=$'\x0a'
		for i in $filenames; do
			unset IFS
			echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			echo "${REPLAYSTRING}: $i"
			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
			play "$i" || echo "Playback failed ($?) for $i"
		done
		unset IFS
	fi
}

fetch_single_vid() {
	local i
	for i in "$@"; do
		youtube-dl -R 5 -i -w --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs $i ||
			echo "Fetch failed ($?) for $i"
	done
}

update_vids() {
	local extra_args
	if [ -z "$1" ]; then
		extra_args="-r 512k"
	else
		extra_args="--playlist-end $1"
	fi
	youtube-dl -R 5 -i -w --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/channel/UCtM5z2gkrGRuWd0JQMx76qA $extra_args
	youtube-dl -R 5 -i -w --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/channel/UClIzWmVzGPm2zhNT2XZ-Rkw $extra_args
}

script_main() {
	local fetch_only_flag
	fetch_only_flag=0

	if [ $# -eq 0 ]; then
		random_vid
	else
		case $1 in
			-h|--help)
				usage
				return 0
			;;
			-l|--list)
				shift
				if [ $# -eq 0 ]; then
					list_files
				else
					list_files "$@"
				fi
				return 0
			;;
			-u|--update)
				update_vids 10
				return $?
			;;
			-U|--full-update)
				update_vids
				return $?
			;;
			-f|--fetch)
				fetch_only_flag=1
				shift
			;;
		esac

		if [ 1 -eq $fetch_only_flag ]; then
			fetch_single_vid "$@"
		else
			named_vid "$@"
		fi
	fi
}

cd "$VIDDIR" &&
script_main "$@"
