#!/bin/bash

[ -z "$PLAYER" ] && PLAYER="/usr/bin/vlc"
[ -z "$PLAYEROPT" ] && PLAYEROPT="-q -f --play-and-exit --no-spu --sub-language=en"
[ -z "$DESCOPT" ] && DESCOPT="--meta-description"
[ -z "$VIDDIR" ] && VIDDIR="$HOME/viddir-bigclive/"
[ -z "$FILTER" ] && FILTER="\.mp4\$|\.mkv\$|\.webm\$"
[ -z "$FETCHOPT" ] && FETCHOPT="-i -w --compat-options filename-sanitization,filename"
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
	echo "Usage: \

$0 [OPTIONS] [FILE [FILE...]]
$0 [OPTIONS] -l [QUERY]]
$0 [OPTIONS] -f URL

Play a random video from \$VIDDIR or play FILE if specified.
FILE can be an exact or partial filename or a number as
returned by the -l option. As a number it can also be negative
to count backwards from the end.

-l or --list will list files in \$VIDDIR, taking an
optional query parameter.

-f or --fetch will download the video specified by the URL.

Options:
  -h, --help   Display this help text
  -u, --update Download recent videos
  -U, --full-update
               Download all videos
  -L, --live   Only play/list bigclivelive videos (also modifies -f)
  -t, --tattoo Only play/list Royal Edinburgh Military Tattoo Videos (also modifies -f)
  --announcements
               Only play/list announcement videos (also modifies -f)
  -a, --all    Include bigclivelive, tattoo, and announcement videos

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
		"$PLAYER" $PLAYEROPT "$1" 2>/dev/null
	fi
}

get_file_list() {
	#ls -1 2>/dev/null | grep -E "$FILTER" #old file list method for single dir

	#new file list method supporting subdirs
	#$1 passes the list of -P and -I options for tree
	#note: may need to set -f here if $1 includes * or ?
	tree $1 -NDifU --prune --noreport --timefmt %s |
		sort |
		cut -d '/' -f 1 --complement |
		grep -E "$FILTER"
}

random_vid() {
	local filename

	filename=$(get_file_list "$1" | sort -R | head -1)
	shift

	echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "${VIDSTRING}:"
	echo "${filename}${OFFBOLD}"
	echo -n "Released: "; date -f <(stat -c "%y" "$filename")
	echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
	play "$filename"
}

list_files() {
	local i
	local filenames
	local filelist
	local filenum
	local numfiles

	filelist="$(get_file_list "$1" | nl -s ": ")"
	shift

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
	shift

	if [ -z "$filenames" ]; then
		echo "No matches found: $@"
		result=1
	else
		IFS=$'\x0a'
		for i in $filenames; do
			unset IFS
			echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			echo "${REPLAYSTRING}:"
			echo "${i}${OFFBOLD}"
			echo -n "Released: "; date -f <(stat -c "%y" "$i")
			echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
			play "$i" || echo "Playback failed ($?) for $i"
		done
		unset IFS
	fi
}

fetch_single_vid() {
	local i
	local retval
	retval=0
	for i in "$@"; do
		yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs $i || {
			echo "Fetch failed ($?) for $i"
			retval=$((retval+1))
		}
	done
	return $retval
}

update_vids() {
	local extra_args
	if [ -z "$1" ]; then
		extra_args="-r 512k"
	else
		extra_args="--playlist-end $1"
	fi

#	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/c/Bigclive/videos $extra_args
	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/playlist?list=UUtM5z2gkrGRuWd0JQMx76qA $extra_args
#	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/watch?list=UUlIzWmVzGPm2zhNT2XZ-Rkw $extra_args

	cd bigclivelive
#	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/c/BigCliveLive/videos $extra_args
	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/@BigCliveLive $extra_args
#	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/channel/UCtM5z2gkrGRuWd0JQMx76qA $extra_args
#	yt-dlp $FETCHOPT --download-archive archive.txt --write-description --write-info-json --write-thumbnail --write-sub --all-subs https://www.youtube.com/channel/UClIzWmVzGPm2zhNT2XZ-Rkw $extra_args
	cd ..
}

script_main() {
	local fetch_only_flag
	local include_live_flag
	local include_announce_flag
	local include_tattoo_flag
	local include_all_flag
	local include_none_flag
	local tree_match_pattern
	local i
	fetch_only_flag=0
	include_live_flag=0
	include_announce_flag=0
	include_tattoo_flag=0
	include_all_flag=0
	include_none_flag=1
	tree_match_pattern="--matchdirs"

	if [ $# -gt 0 ]; then
		case $1 in
			-h|--help)
				usage
				return 0
			;;
			-u|--update)
				update_vids 20
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
			-L|--live)
				include_live_flag=1
				include_none_flag=0
				shift
			;;
			--announcements)
				include_announce_flag=1
				include_none_flag=0
				shift
			;;
			-t|--tattoo)
				include_tattoo_flag=1
				include_none_flag=0
				shift
			;;
			-a|--all)
				include_all_flag=1
				include_none_flag=0
				shift
			;;
		esac

		if [ 1 -eq $fetch_only_flag ]; then
			fetch_single_vid "$@"
			return $?
		fi
	fi

	if [ 0 -eq $include_all_flag ]; then
		if [ 0 -eq $include_none_flag ]; then
			tree_match_pattern="${tree_match_pattern} -P ."
			if [ 1 -eq $include_announce_flag ]; then
				tree_match_pattern="${tree_match_pattern}|announcements"
			fi
			if [ 1 -eq $include_tattoo_flag ]; then
				tree_match_pattern="${tree_match_pattern}|tattoo"
			fi
			if [ 1 -eq $include_live_flag ]; then
				tree_match_pattern="${tree_match_pattern}|bigclivelive"
			fi
		fi

		tree_match_pattern="${tree_match_pattern} -I ."
		if [ 0 -eq $include_announce_flag ]; then
			tree_match_pattern="${tree_match_pattern}|announcements"
		fi
		if [ 0 -eq $include_tattoo_flag ]; then
			tree_match_pattern="${tree_match_pattern}|tattoo"
		fi
		if [ 0 -eq $include_live_flag ]; then
			tree_match_pattern="${tree_match_pattern}|bigclivelive"
		fi
	fi

	if [ $# -eq 0 ]; then
		random_vid "$tree_match_pattern"
		return $?
	else
		case $1 in
			-h|--help)
				usage
				return 0
			;;
			-l|--list)
				shift
				if [ $# -eq 0 ]; then
					list_files "$tree_match_pattern"
				else
					list_files "$tree_match_pattern" "$@"
				fi
				return 0
			;;
			-f|--fetch)
				fetch_only_flag=1
				shift
			;;
		esac

		if [ 1 -eq $fetch_only_flag ]; then
			if [ 1 -eq $include_live_flag ]; then
				echo "Fetching video into bigclivelive subdir"
				cd bigclivelive
			elif [ 1 -eq $include_announce_flag ]; then
				echo "Fetching video into announcements subdir"
				cd announcements
			elif [ 1 -eq $include_tattoo_flag ]; then
				echo "Fetching video into tattoo subdir"
				cd tattoo
			fi
			fetch_single_vid "$@"
			return $?
		else
			named_vid "$tree_match_pattern" "$@"
			return $?
		fi
	fi
}

cd "$VIDDIR" &&
script_main "$@"
