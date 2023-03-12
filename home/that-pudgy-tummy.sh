#!/bin/bash

[ -z "$PLAYER" ] && PLAYER="/usr/bin/vlc"
[ -z "$PLAYEROPT" ] && PLAYEROPT="-q -f --play-and-exit --sub-language=en"
[ -z "$DESCOPT" ] && DESCOPT="--meta-description"
[ -z "$VIDDIR" ] && VIDDIR="$HOME/viddir-aria"
[ -z "$FILTER" ] && FILTER="-1 *.mkv *.mp4 */*.mkv */*.m4v"
VIDSTRING=""
REPLAYSTRING=""

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
  -h,  --help        Display this help text
  -l,  --list        List files in \$VIDDIR, optionally matching a query
  -a,  --autumn      Select from episodes set in the Autumn
  -aw, --aunter      Select from episodes set in between Autumn and Winter
  -b,  --bittersweet Select from episodes with a bittersweet feeling
  -sa, --summtumn    Select from episodes set in between Summer and Autumn
  -si, --sickday     Select from episodes appropriate for a sickday
  -sp, --spring      Select from episodes set in the Spring
  -ss, --sprummer    Select from episodes set in between Spring and Summer
  -su, --summer      Select from episodes set in the Summer
  -w,  --winter      Select from episodes set in the Winter
  -ws, --winting     Select from episodes set in between Winter and Spring

Environment Variables:
  VIDDIR     The directory containing the videos
             ($VIDDIR)
  FILTER     The glob filter used to find and sort videos in VIDDIR
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
	local description
	description="$(ffprobe -show_format -of json "$1" 2>/dev/null \
		| jq -r '.format.tags |
			if .title then
				.title
			else empty end,
			if .comment then
				.comment
			elif .COMMENT then
				.COMMENT
			else empty end,
			if .album_artist then
				"Directed by " + .album_artist
			elif .DIRECTOR then
				"Directed by " + .DIRECTOR
			else empty end,
			if .date then
				"Original Airdate: " + .date
			elif .DATE then
				"Original Airdate: " + .DATE
			else empty end')"

	if [ -n "$description" ]; then
		echo "$description"
		echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
	fi
	if [ -n "$description" -a -n "$DESCOPT" ]; then
		"$PLAYER" $PLAYEROPT $DESCOPT "$description" "$1" 2>/dev/null
	else
		"$PLAYER" $PLAYEROPT "$1" 2>/dev/null
	fi
}

random_vid() {
	local filename
	filename=$(ls -1 $FILTER 2>/dev/null | sort -R | head -1)
	echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "${VIDSTRING}$filename"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
	play "$filename"
}

list_files() {
	local i
	local filenames
	local filelist
	local filenum
	local numfiles

	filelist="$(ls $FILTER 2>/dev/null | nl -s ": ")"

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
		false
	else
		IFS=$'\x0a'
		for i in $filenames; do
			unset IFS
			echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			echo "${REPLAYSTRING}$i"
			echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
			play "$i" || echo "Playback failed ($?) for $i"
		done
		unset IFS
	fi
}

script_main() {
	while [ $# -gt 0 ]; do
		case $1 in
			-h|--help)
				usage
				return 0
			;;
			-a|--autumn)
				shift
				VIDDIR="${VIDDIR}/.autumn"
			;;
			-aw|--aunter)
				shift
				VIDDIR="${VIDDIR}/.aunter"
			;;
			-b|--bittersweet)
				shift
				VIDDIR="${VIDDIR}/.bittersweet"
			;;
			-sa|--summtumn)
				shift
				VIDDIR="${VIDDIR}/.summtumn"
			;;
			-si|--sickday)
				shift
				VIDDIR="${VIDDIR}/.sickday"
			;;
			-sp|--spring)
				shift
				VIDDIR="${VIDDIR}/.spring"
			;;
			-ss|--sprummer)
				shift
				VIDDIR="${VIDDIR}/.sprummer"
			;;
			-su|--summer)
				shift
				VIDDIR="${VIDDIR}/.summer"
			;;
			-w|--winter)
				shift
				VIDDIR="${VIDDIR}/.winter"
			;;
			-ws|--winting)
				shift
				VIDDIR="${VIDDIR}/.winting"
			;;
			-l|--list)
				shift
				if [ $# -eq 0 ]; then
					cd "$VIDDIR" &&
					list_files
				else
					cd "$VIDDIR" &&
					list_files "$@"
				fi
				return 0
			;;
			*)
				cd "$VIDDIR" &&
				named_vid "$@"
				return $?
			;;
		esac
	done

	cd "$VIDDIR" &&
	random_vid
}

script_main "$@"
