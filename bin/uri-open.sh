#!/bin/bash
# Examine a URI passed in $1 and open it using
# an appropriate application

# might be better to use python for this...

# source a user config file
[ -z "$XDG_CONFIG_HOME" ] && XDG_CONFIG_HOME="$HOME/.config"
if [ -f "$XDG_CONFIG_HOME/uri-open" ]; then
	source "$XDG_CONFIG_HOME/uri-open"
elif [ -f "$HOME/.uri-open" ]; then
	source "$HOME/.uri-open"
fi
[ -z "$TMPDIR" ] && TMPDIR="/tmp/"

# List of test cases to run; keep default test last
declare -r uri_test_list="podcast youtube peertube twitch general_video default"

# for each test, declare an array with keys test, testname, run, runname
# test and run are functions that will be executed
# testname and runname are optional labels that will be printed

declare -Ar default=(
	[test]="true"
	[runname]="Default Browser"
	[run]="run_xdg_open"
)

declare -Ar youtube=(
	[testname]="YouTube"
	[test]="test_youtube"
	[runname]="Youtube"
	[run]="run_youtube"
)

declare -Ar podcast=(
	[testname]="Podcast Audio"
	[test]="test_podcast"
	[runname]="Podcast Download"
	[run]="run_podcast"
)

declare -Ar peertube=(
	[testname]="PeerTube"
	[test]="test_peertube"
	[runname]="PeerTube"
	[run]="run_peertube"
)

declare -Ar twitch=(
	[testname]="Twitch.tv"
	[test]="test_twitch"
	[runname]="Twitch.tv"
	[run]="run_twitch"
)

declare -Ar general_video=(
	[testname]="General Video"
	[test]="test_video"
	[runname]="Video Download"
	[run]="run_video"
)

# helper functions

# test whether $1 ends in a file extension that is in the list provided in $2
# $2 should be space separated list of extensions without a leading "."
# if the function returns 0, ${BASH_REMATCH[2]} will contain the matching
# extension, ${BASH_REMATCH[1]} will contain the prefix, and ${BASH_REMATCH[3]}
# will contain any remainder (starting with a ?)
function file_extension_test ()
{
	# clean up multiple white space in $2 and white space at the end
	set -- "$1" "$(echo -n $2)"

	# explanation of the following line noise:
	# if $2 is "mp3 mp4 mkv", evaluate as ^[^?]*\.(mp3|mp4|mkv)(\?.*)?
	# this matches globs like *.mp3 *.mp3\?* *.mp4 *.mp4\?* *.mkv *.mkv\?*
	# but not *\?*.mp3 *\?*.mp4 *\?*.mkv
	[[ "$1" =~ ^([^?]*)\.(${2// /|})(\?.*)?$ ]] # && echo ${BASH_REMATCH[*]}
}

# test whether $1 is a URI matching the list of domain names provided in $2
# $2 should be space separated list of domain names
# if the domain might start with www. then that must be explicitly listed
# the elements of $2 can also include a path prefix like a.com/watch
# if the function returns 0, ${BASH_REMATCH[2]} will contain the matching
# domain portion and ${BASH_REMATCH[3]} will contain the remainder
function domain_path_test ()
{
	# clean up multiple white space in $2 and white space at the end
	set -- "$1" "$(echo -n $2)"

	# explanation of the following line noise:
	# if $2 is "a.com b.net", evaluate as ^([^/]*://)?(a.com|b.net)/.+
	# this matches globs like a.com/* *://a.com/* b.net/* *://b.net/*
	# but not */*://a.com/* */*://b.net/*
	[[ "$1" =~ ^([^/]*://)?(${2// /|})/(.+) ]] # && echo ${BASH_REMATCH[*]}
}

# locate a writeable video directory
# TODO: make configurable
function find_viddir ()
{
	[ -d "$HOME/Videos" ] &&
		findmnt --target="$HOME/Videos/" -O rw > /dev/null && {
			echo "$HOME/Videos"
			return 0
		}

	[ -d "$HOME/Videos2" ] &&
		findmnt --target="$HOME/Videos2/" -O rw > /dev/null && {
			echo "$HOME/Videos2"
			return 0
		}

	echo "$HOME"
	return 1
}

# check the potential video directories for a video ID
# $1 is the video ID
function check_viddir ()
{
	if [ -e "$HOME/Videos/"*"$1"* ]; then
		echo "$HOME/Videos/"*"$1"*
		return 0
	elif [ -e "$HOME/Videos2/"*"$1"* ]; then
		echo "$HOME/Videos2/"*"$1"*
		return 0
	elif [ -e "$HOME/"*"$1"* ]; then
		echo "$HOME/"*"$1"*
		return 0
	fi

	return 1
}

# test and exec functions

function run_xdg_open ()
{
	/usr/bin/xdg-open "$1"
}

function test_youtube ()
{
	#match http[s]://[www.]youtube.com/watch?v=<video>
	#match http[s]://[www.]youtube.com/shorts/<video>
	#match http[s]://youtu.be/<video>
	#where <video> is [[:alnum:]_-]{11}
	#/usr/bin/grep -q -E '^https?://(www\.)?youtu((\.be/)|(be\.com/watch\?.*v=))[[:alnum:]_-]{11}' <<< "$1"
	domain_path_test "$1" "youtube.com www.youtube.com youtu.be www.youtu.be"
}

function run_vlc ()
{
	/usr/bin/vlc -f "$1"
}

function run_ydl ()
{
	local viddir
	local ydl_bin
	local ydl_out
	local i
	i=0
	ydl_bin="yt-dlp"
	ydl_out="[%(channel)s] %(title)s [%(id)s].%(ext)s"

	viddir="$(find_viddir)"

	if [ -z "${YDL_QUEUE}" -o 0 -eq $YDL_QUEUE ]; then
		echo flock "${viddir}/$2.part" $ydl_bin -o "${viddir}/${ydl_out}" "$1"
		/usr/bin/flock "${viddir}/$2.part" $ydl_bin -o "${viddir}/${ydl_out}" "$1"
		[ -f "${viddir}/$2.part" -a ! -s "${viddir}/$2.part" ] && rm "${viddir}/$2.part"
	else
		[ -f "${viddir}/ydl.lock" ] && {
			echo "queueing $1"
			echo "$1" >> "${viddir}/ydl.lock"
		} || {
			echo "starting ydl queue with $1"
			echo "$1" >> "${viddir}/ydl.lock"
			while [ $i -ne $(stat -c %s "${viddir}/ydl.lock") ]; do
				i=$(stat -c %s "${viddir}/ydl.lock")
				$ydl_bin -o "${viddir}/${ydl_out}" --batch-file "${viddir}/ydl.lock" --download-archive "${viddir}/ydl.archive"
			done
			rm "${viddir}/ydl.lock" "${viddir}/ydl.archive"
		}
	fi

	true #at this point we are committed
}

function run_youtube ()
{
	local vid
	local i

	#extract video unique ID
	#match URLs like youtube.com/watch?v=<video>
	vid=$(echo "$1" | /usr/bin/sed -nre 's/^.*((\?v=)|(&v=))([[:alnum:]_-]{11}).*$/\4/p')
	if [ -z "$vid" ]; then
		#match URLs like youtu.be/<video>
		vid=$(echo "$1" | /usr/bin/sed -nre 's/^.*\/([[:alnum:]_-]{11})($|\?.*$)/\1/p')
	fi

	[ -z "$vid" ] && return 1

	i="$(check_viddir "[${vid}].")" && {
		run_vlc "$i"
	} || {
		run_ydl "$1" "$vid"
	}
}

function test_podcast ()
{
	file_extension_test "$1" "${PODCAST_EXTENSIONS:=mp3}"
}

function wget_cleanup ()
{
	kill ${WGET_PID}
	rm "$WGET_TEMP"
	rm "$WGET_LOCKFILE"
}

function run_wget ()
{
	touch "$3" || return 1
	WGET_LOCKFILE="$3"
	WGET_TEMP="$(mktemp --tmpdir="$TMPDIR")"
	chmod a+r "$WGET_TEMP"
	trap wget_cleanup EXIT
	wget "$1" -O "$WGET_TEMP" &
	WGET_PID=$!
	wait $WGET_PID
	trap EXIT
	sleep 1
	[ -f "$WGET_TEMP" ] && mv "$WGET_TEMP" "$2"
	rm "$WGET_LOCKFILE"
	unset WGET_PID
	unset WGET_TEMP
	unset WGET_LOCKFILE
}

function run_podcast ()
{
	local pod
	local hash
	local ext
	local longname
	local i

	pod="$(basename "${1%\?*}")"
	for i in ${PODCAST_EXTENSIONS}; do
		[ ${pod} = "${pod%.$i}" ] && continue
		pod="${pod%.$i}"
		ext="$i"
		break
	done
	ext="${ext:-mp3}"

	if [ -n "${pod}" ]; then
		shopt -s extglob
		hash="[$(echo -n "${1/#http:/https:}" | md5sum | cut -b 1-6)]"

		[ -e "$HOME/Podcasts/${hash}.temp" ] && return 0

		if [ -e "$HOME/Podcasts/"*"${hash}."* ]; then
			echo "Opening" "$HOME/Podcasts/"*"${hash}."*
			run_xdg_open "$HOME/Podcasts/"*"${hash}."*
		else
			i="$HOME/Podcasts/${pod}${hash}.${ext}"
			echo "Downloading $1 to $i"
			run_wget "$1" "$i" "$HOME/Podcasts/${hash}.temp"
			longname="$(ffprobe -of json -show_format "$i" 2>/dev/null | jq -r ".format.tags | (if .track then .track+\"-\" else if .TDAT then .TDAT|.[:10]+\"-\" else if .date then .date|.[:10]+\"-\" else \"\" end end end)+(if .artist then .artist+\"-\" else if .album then .album+\"-\" else \"\" end end)+(if .title then .title else \"\" end)")"
			longname="${longname//\?/}"
			longname="${longname//\:/-}"
			longname="${longname#-}"
			if [ -n "$longname" ]; then
				echo "Renaming download to ${longname}${hash}.${ext}"
				mv "$i" "$HOME/Podcasts/${longname}${hash}.${ext}"
			fi
		fi
	fi
}

function test_peertube ()
{
	local domainlist
	[ -n "${PEERTUBE_DOMAINS}" ] &&
	{
		# clean up multiple white space and ensure the list ends with a space
		domainlist="$(echo -n ${PEERTUBE_DOMAINS}) "
		# match https://<domain>/videos/watch/<video-uuid>
		# match https://<domain>/w/<video-uuid>
		domain_path_test "$1" "${domainlist// /\/videos\/watch }${domainlist// /\/videos\/w }"
	}
}

function run_peertube ()
{
 local vid
 local uri

 case "$1" in
  #match https://<domain>/videos/watch/<video-uuid>
  https://*/videos/watch/*)
   vid=$(echo "$1" | /usr/bin/sed -nre 's_^https://[^/]+/videos/watch/__p')
   uri="$1"
   ;;
  #match https://<domain>/w/<video-uuid>
  https://*/w/*)
   vid=$(echo "$1" | /usr/bin/sed -nre 's_^https://[^/]+/w/__p')
   uri=$(echo "$1" | /usr/bin/sed -nre 's_/w/_/videos/watch/_p')
   ;;
 esac

 if [ -n "$vid" ]; then
  if [ -e "$HOME/Videos/$vid.mp4" ]; then
   run_vlc "$HOME/Videos/$vid.mp4"
  elif [ -e "$HOME/Videos2/$vid.mp4" ]; then
   run_vlc "$HOME/Videos2/$vid.mp4"
  else
   run_ydl "$uri" "$vid"
  fi
 fi
}

function test_twitch ()
{
	#match http[s]://[www.]twitch.tv/videos/<video>
	#where <video> is [[:digit:]]+
	/usr/bin/grep -q -E '^https?://(www\.)?twitch\.tv/videos/[[:digit:]]+' <<< "$1"
}

function run_twitch ()
{
 local vid

 #match http[s]://[www.]twitch.tv/videos/<video>
 /usr/bin/grep -q -E '^https?://(www\.)?twitch\.tv/videos/[[:digit:]]+' <<< "$1" && {
  vid=$(echo "$1" | /usr/bin/sed -nre 's_^https://[^/]+/videos/__p')
 }

 if [ -n "$vid" ]; then
  if [ -e "$HOME/Videos/$vid.mp4" ]; then
   run_vlc "$HOME/Videos/$vid.mp4"
  elif [ -e "$HOME/Videos/$vid.mkv" ]; then
   run_vlc "$HOME/Videos/$vid.mkv"
  elif [ -e "$HOME/Videos2/$vid.mp4" ]; then
   run_vlc "$HOME/Videos2/$vid.mp4"
  elif [ -e "$HOME/Videos2/$vid.mkv" ]; then
   run_vlc "$HOME/Videos2/$vid.mkv"
  else
   run_ydl "$1" "$vid"
  fi
 fi
}

function test_video ()
{
	file_extension_test "$1" "${VIDEO_EXTENSIONS:=mp4 mkv webm}"
}

function run_video ()
{
	local viddir
	local vid
	local ext
	local hash
	local longname
	local i

	vid="$(basename "${1%\?*}")"
	for i in ${VIDEO_EXTENSIONS}; do
		[ ${vid} = "${vid%.$i}" ] && continue
		vid="${vid%.$i}"
		ext="$i"
		break
	done
	ext="${ext:-mp4}"

	[ -z "${vid}" ] && return 1

	shopt -s extglob
	hash="[$(echo -n "${1/#http:/https:}" | md5sum | cut -b 1-6)]"

	check_viddir "${hash}.temp" 1>&2 && return 0
	i="$(check_viddir "${hash}.")" &&
	{
		echo "Opening" "$i"
		run_vlc "$i"
	} || {
		viddir="$(find_viddir)"
		i="${viddir}/${vid}${hash}.${ext}"

		echo "Downloading $1 to $i"
		run_wget "$1" "$i" "${viddir}/${hash}.temp"

		longname="$(ffprobe -of json -show_format "$i" 2>/dev/null | jq -r ".format.tags | (if .track then .track+\"-\" else if .TDAT then .TDAT|.[:10]+\"-\" else if .date then .date|.[:10]+\"-\" else \"\" end end end)+(if .artist then .artist+\"-\" else if .album then .album+\"-\" else \"\" end end)+(if .title then .title else \"\" end)")"
		longname="${longname//\?/}"
		longname="${longname//\:/-}"
		longname="${longname#-}"
		if [ -n "$longname" ]; then
			echo "Renaming download to ${longname}${hash}.${ext}"
			mv "$i" "${viddir}/${longname}${hash}.${ext}"
		fi
	}
}

# script main
# parameters: any number of URI's -- each will be processed in-turn
function main ()
{
	local i
	local -n j
	for i in "$@"; do
		echo "Testing $i"
		for j in $uri_test_list; do
			[ -n "${j[test]}" ] || continue
			[ -n "${j[testname]}" ] &&
				echo "Checking ${j[testname]}"
			${j[test]} "$i" || continue
			[ -n "${j[run]}" ] || continue
			if [ -n "${j[runname]}" ]; then
				echo "Launching ${j[runname]}"
			else
				echo "Running ${j[run]}"
			fi
			${j[run]} "$i" && break
		done
	done
}

#for some reason, plasmashell has its stdout redirected to /dev/null
#so applications launched from the menu also have no stdout
#use first parameter -d to duplicate stderr
if [ "$1" = "-d" ]; then
	shift
	main "$@" 1>&2
else
	main "$@"
fi

