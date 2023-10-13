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

# List of test cases to run; keep default test last
declare -r uri_test_list="podcast youtube peertube twitch default"

# for each test, declare an array struct like this:
declare -Ar youtube=(
	[testname]="YouTube"
	[test]="test_youtube"
	[runname]="Youtube"
	[run]="run_youtube"
)

declare -Ar default=(
	[test]="true"
	[runname]="Default Browser"
	[run]="run_xdg_open"
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

# declare the helper functions here:
function test_youtube ()
{
	#match http[s]://[www.]youtube.com/watch?v=<video>
	#match http[s]://youtu.be/<video>
	#where <video> is [[:alnum:]_-]{11}
	/usr/bin/grep -q -E '^https?://(www\.)?youtu((\.be/)|(be\.com/watch\?.*v=))[[:alnum:]_-]{11}' <<< "$1"
}

function run_vlc ()
{
	/usr/bin/vlc -f "$1"
}

function ls_cleanup ()
{
	kill "$LS_PID"
	rm -f "$HOME/Videos${LS_VID}.temp"
	rm -f "$HOME/Videos${LS_VID}.mp4"
}

function run_ls ()
{
	[ -d "$HOME/Videos2" ] &&
		findmnt --target="$HOME/Videos2/" -O rw > /dev/null && {
			LS_VID="2/$2"
		}
	[ -d "$HOME/Videos" ] &&
		findmnt --target="$HOME/Videos/" -O rw > /dev/null && {
			LS_VID="/$2"
		}
	trap ls_cleanup EXIT

	python3-livestreamer --no-version-check "$1" best -o "$HOME/Videos${LS_VID}.temp" -f &
	LS_PID=$!
	wait $LS_PID
	mv "$HOME/Videos${LS_VID}.temp" "$HOME/Videos${LS_VID}.mp4"
	trap EXIT
	unset LS_PID
	unset LS_VID
}

function run_ydl ()
{
	local viddir
	local ydl_bin
	local ydl_out
	local i
	i=0
	if [ "$YOUTUBE_FUNC" == "YDL" ]; then
		ydl_bin="youtube-dl"
		ydl_out="$2.mp4"
	else
		ydl_bin="yt-dlp"
		ydl_out="%(id)s.%(ext)s"
	fi
	[ -d "$HOME/Videos2" ] &&
		findmnt --target="$HOME/Videos2/" -O rw > /dev/null && {
			viddir="$HOME/Videos2"
		}
	[ -d "$HOME/Videos" ] &&
		findmnt --target="$HOME/Videos/" -O rw > /dev/null && {
			viddir="$HOME/Videos"
		}

	echo flock "${viddir}/$2.part" $ydl_bin -o "${viddir}/${ydl_out}" "$1"

	while ! /usr/bin/flock "${viddir}/$2.part" $ydl_bin -o "${viddir}/${ydl_out}" "$1"; do
		i=$((i+1))
		[ $i -ge ${3:-0} ] && break
	done
	[ -f "${viddir}/$2.part" -a ! -s "${viddir}/$2.part" ] && rm "${viddir}/$2.part"
	true #at this point we are committed
}

function run_youtube ()
{
 local vid

 #match http[s]://[www.]youtube.com/watch?v=<video>
 /usr/bin/grep -q -E '^https?://(www\.)?youtube\.com/watch\?.*v=[[:alnum:]_-]{11}' <<< "$1" && {
  vid=$(echo $1 | /usr/bin/sed -nre 's/^.*((\?v=)|(&v=))([[:alnum:]_-]{11}).*$/\4/p')
 } || {
  #match http[s]://youtu.be/<video>
  /usr/bin/grep -q -E '^https?://(www\.)?youtu\.be/[[:alnum:]_-]{11}' <<< "$1" && {
   vid=$(echo $1 | /usr/bin/sed -nre 's/^.*\/([[:alnum:]_-]{11}).*$/\1/p')
  }
 }

 if [ -n "$vid" ]; then
  if [ -e "$HOME/Videos/$vid.mp4" ]; then
   run_vlc "$HOME/Videos/$vid.mp4"
  elif [ -e "$HOME/Videos/$vid.mkv" ]; then
   run_vlc "$HOME/Videos/$vid.mkv"
  elif [ -e "$HOME/Videos/$vid.webm" ]; then
   run_vlc "$HOME/Videos/$vid.webm"
  elif [ -e "$HOME/Videos2/$vid.mp4" ]; then
   run_vlc "$HOME/Videos2/$vid.mp4"
  elif [ -e "$HOME/Videos2/$vid.mkv" ]; then
   run_vlc "$HOME/Videos2/$vid.mkv"
  elif [ -e "$HOME/Videos2/$vid.webm" ]; then
   run_vlc "$HOME/Videos2/$vid.webm"
  else
   if [ "$YOUTUBE_FUNC" = "LS" ]; then
    [ -e "$HOME/Videos/$vid.temp" ] && return 0
    [ -e "$HOME/Videos2/$vid.temp" ] && return 0
    run_ls "$1" "$vid"
   elif [ "$YOUTUBE_FUNC" = "YDL" ]; then
    run_ydl "$1" "$vid" ${YDL_RETRIES}
   elif [ "$YOUTUBE_FUNC" = "YTDLP" ]; then
    run_ydl "$1" "$vid" ${YDL_RETRIES}
   else
    run_vlc "$1"
   fi
  fi
 fi
}

function run_xdg_open ()
{
	/usr/bin/xdg-open "$1"
}

function test_podcast ()
{
	case "$1" in
	*.mp3)
		return 0
	;;
	*.mp3\?*)
		return 0
	;;
	esac
	return 1
}

function wget_cleanup ()
{
	kill "$WGET_PID"
	rm -f "$WGET_FILE.temp"
	rm -f "$WGET_FILE"
}

function run_wget ()
{
	WGET_FILE="$2"
	trap wget_cleanup EXIT
	wget "$1" -O "$2.temp" &
	WGET_PID=$!
	wait $wGET_PID
	mv "$2.temp" "$2"
	trap EXIT
	unset WGET_PID
	unset WGET_FILE
}

function run_podcast ()
{
 local mp3
 mp3="$(basename "${1%\?*}")"
 if [ -n "$mp3" ]; then
  if [ -e "$HOME/Podcasts/$mp3" ]; then
   run_xdg_open "$HOME/Podcasts/$mp3"
  else
   [ -e "$HOME/Podcasts/$mp3.temp" ] && return 0
   run_wget "$1" "$HOME/Podcasts/$mp3"
  fi
 fi
}

function test_peertube ()
{
 for domain in ${PEERTUBE_DOMAINS}; do
  case "$1" in
   #match https://<domain>/videos/watch/<video-uuid>
   https://${domain}/videos/watch/*)
    return 0
    ;;
   #match https://<domain>/w/<video-uuid>
   https://${domain}/w/*)
    return 0
    ;;
  esac
 done
 return 1
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
   if [ "$YOUTUBE_FUNC" = "LS" ]; then
    [ -e "$HOME/Videos/$vid.temp" ] && return 0
    [ -e "$HOME/Videos2/$vid.temp" ] && return 0
    run_ls "$1" "$vid"
   elif [ "$YOUTUBE_FUNC" = "YDL" ]; then
    run_ydl "$1" "$vid"
   elif [ "$YOUTUBE_FUNC" = "YTDLP" ]; then
    run_ydl "$1" "$vid"
   else
    run_vlc "$1"
   fi
  fi
 fi
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
