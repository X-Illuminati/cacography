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

function run_ydl ()
{
	local viddir
	local ydl_bin
	local ydl_out
	local i
	i=0
	ydl_bin="yt-dlp"
	ydl_out="[%(channel)s] %(title)s [%(id)s].%(ext)s"

	[ -d "$HOME/Videos2" ] &&
		findmnt --target="$HOME/Videos2/" -O rw > /dev/null && {
			viddir="$HOME/Videos2"
		}
	[ -d "$HOME/Videos" ] &&
		findmnt --target="$HOME/Videos/" -O rw > /dev/null && {
			viddir="$HOME/Videos"
		}

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
  if [ -e "$HOME/Videos/"*"[$vid]."* ]; then
   run_vlc "$HOME/Videos/"*"[$vid]."*
  elif [ -e "$HOME/Videos2/"*"[$vid]."* ]; then
   run_vlc "$HOME/Videos2/"*"[$vid]."*
  elif [ -e "$HOME/Videos/$vid.mp4" ]; then
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
    run_ydl "$1" "$vid"
   elif [ "$YOUTUBE_FUNC" = "YTDLP" ]; then
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
	kill ${WGET_PID}
	rm -f "$WGET_TEMP"
}

function run_wget ()
{
	WGET_TEMP="$(mktemp --tmpdir="$TMPDIR")"
	chmod a+r "$WGET_TEMP"
	trap wget_cleanup EXIT
	wget "$1" -O "$WGET_TEMP" &
	WGET_PID=$!
	wait $WGET_PID
	trap EXIT
	sleep 1
	[ -f "$WGET_TEMP" ] && mv "$WGET_TEMP" "$2"
	unset WGET_PID
	unset WGET_TEMP
}

function run_podcast ()
{
 local mp3
 local hash
 local longname
 mp3="$(basename "${1%\?*}")"

 if [ -n "$mp3" ]; then
  shopt -s extglob
  hash="$(echo -n "${1/#http:/https:}" | sum | cut -f1 -d ' ')"
  hash="$(printf "[%4.4X]" ${hash##+(0)})"

  if [ -e "$HOME/Podcasts/$hash"*".mp3" ]; then
   echo "Opening $HOME/Podcasts/$hash"*".mp3"
   run_xdg_open "$HOME/Podcasts/$hash"*".mp3"
  else
   [ -e "$HOME/Podcasts/${hash}.temp" ] && return 0
   touch "$HOME/Podcasts/${hash}.temp"
   echo "Downloading $1 to $HOME/Podcasts/${hash}${mp3}"
   run_wget "$1" "$HOME/Podcasts/${hash}${mp3}"
   longname="$(ffprobe -of json -show_format "$HOME/Podcasts/${hash}${mp3}" 2>/dev/null | jq -r ".format.tags | (if .artist then .artist else if .album then .album else \"\" end end)+(if .title then \"-\"+.title else \"\" end)")"
   longname="${longname//\?/}"
   longname="${longname//\:/-}"
   longname="${longname#-}"
   if [ -n "$longname" ]; then
    echo "Renaming download to ${hash}${longname}.mp3"
    mv "$HOME/Podcasts/${hash}${mp3}" "$HOME/Podcasts/${hash}${longname}.mp3"
   fi
   rm "$HOME/Podcasts/${hash}.temp"
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

#for some reason, plasmashell has its stdout redirected to /dev/null
#so applications launched from the menu also have no stdout
#use first parameter -d to duplicate stderr
if [ "$1" = "-d" ]; then
	shift
	main "$@" 1>&2
else
	main "$@"
fi

