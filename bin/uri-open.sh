#!/bin/bash
# Examine a URI passed in $1 and open it using
# an appropriate application

# might be better to use python for this...

# source a user config file
source ~/.uri-open

# List of test cases to run; keep default test last
declare -r uri_test_list="podcast youtube default"

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
	/usr/bin/vlc "$1"
}

function ydl_cleanup ()
{
	kill "$YDL_PID"
	rm -f "$HOME/Videos${YDL_VID}.temp"
	rm -f "$HOME/Videos${YDL_VID}.mp4"
}

function run_ydl ()
{
	findmnt --target="$HOME/Videos2/" -O rw > /dev/null && {
		YDL_VID="2/$2"
	}
	findmnt --target="$HOME/Videos/" -O rw > /dev/null && {
		YDL_VID="/$2"
	}
	trap ydl_cleanup EXIT

	python3-livestreamer --no-version-check "$1" best -o "$HOME/Videos${YDL_VID}.temp" -f &
	YDL_PID=$!
	wait $YDL_PID
	mv "$HOME/Videos${YDL_VID}.temp" "$HOME/Videos${YDL_VID}.mp4"
	trap EXIT
	unset YDL_PID
	unset YDL_VID
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
   if [ "$YOUTUBE_FUNC" = "YDL" ]; then
    [ -e "$HOME/Videos/$vid.temp" ] && return 0
    [ -e "$HOME/Videos2/$vid.temp" ] && return 0
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
 mp3="$(basename "$1")"
 if [ -n "$mp3" ]; then
  if [ -e "$HOME/Podcasts/$mp3" ]; then
   run_xdg_open "$HOME/Podcasts/$mp3"
  else
   [ -e "$HOME/Podcasts/$mp3.temp" ] && return 0
   run_wget "$1" "$HOME/Podcasts/$mp3"
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
