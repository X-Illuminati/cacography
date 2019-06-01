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
declare -r uri_test_list="podcast youtube peertube default"

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
	[ -d "$HOME/Videos2" ] &&
		findmnt --target="$HOME/Videos2/" -O rw > /dev/null && {
			viddir="$HOME/Videos2"
		}
	[ -d "$HOME/Videos" ] &&
		findmnt --target="$HOME/Videos/" -O rw > /dev/null && {
			viddir="$HOME/Videos"
		}

	/usr/bin/flock -n "${viddir}/$2.mp4.part" youtube-dl -o "${viddir}/$2.mp4" "$1"
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
  elif [ -e "$HOME/Videos2/$vid.mp4" ]; then
   run_vlc "$HOME/Videos2/$vid.mp4"
  else
   if [ "$YOUTUBE_FUNC" = "LS" ]; then
    [ -e "$HOME/Videos/$vid.temp" ] && return 0
    [ -e "$HOME/Videos2/$vid.temp" ] && return 0
    run_ls "$1" "$vid"
   elif [ "$YOUTUBE_FUNC" = "YDL" ]; then
    run_ydl "$1" "$vid"
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
  #match https://<domain>/videos/watch/<video-uuid>
  case "$1" in
   https://${domain}/videos/watch/*)
    return 0
    ;;
  esac
 done
 return 1
}

function run_peertube ()
{
 local vid

 case "$1" in
  #match https://<domain>/videos/watch/<video-uuid>
  https://*/videos/watch/*)
   vid=$(echo "$1" | /usr/bin/sed -nre 's_^https://[^/]+/videos/watch/__p')
   ;;
 esac

 if [ -n "$vid" ]; then
  if [ -e "$HOME/Videos/$vid.mp4" ]; then
   run_vlc "$HOME/Videos/$vid.mp4"
  elif [ -e "$HOME/Videos2/$vid.mp4" ]; then
   run_vlc "$HOME/Videos2/$vid.mp4"
  else
   run_ydl "$1" "$vid"
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

main "$@"
