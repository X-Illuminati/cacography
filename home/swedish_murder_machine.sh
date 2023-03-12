#!/bin/bash

[ -z "$PLAYER" ] && PLAYER="/usr/bin/vlc"
[ -z "$PLAYEROPT" ] && PLAYEROPT="-q -f --play-and-exit --no-spu --sub-language=en"
[ -z "$VIDDIR" ] && VIDDIR="$HOME/viddir-venture-bros"
[ -z "$FILTER" ] && FILTER="*.m4v"

vidstring()
{
{
sort -R << EOF
Swedish Murder Machine
Half Swedish, Quarter Polish, Quarter Winnebago
Brock-a-saurus
Wham! Brock Ness Monster
Brock Fucking Samson
Dibs on his cigarette but
Franken-Mullet
Brock Lobster
Brocodile
Easy, there, Babe Ruthless
Boom! Yummy!
Mess with the cat, and you get the clops!
Move like an animal to feel the kill
I like the cut of his hair...
One time I saw him kill a guy with a sock full of party snaps
Blonde-haired, butter-cream-frosted murder cake
Brock of Ages
Feel the Sting of the Monarch!
A deadly game of cat and also cat
You got it, Chew-brock-a
Don't go fishing for trouble, Brock Cousteau
Interests: Hand-to-hand combat, murder, Zeppelin
The car, the clothes, the music, the Tennessee top hat
EOF
} | tail -n 1
}
REPLAYSTRING="Replay"

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
	echo "Usage: $0 [-h|-l|FILE [FILE...]]\

Play a random video from \$VIDDIR or play FILE if specified.

FILE can be an exact or partial filename or a number as
returned by the -l option. As a number it can also be negative
to count backwards from the end.

Options:
  -h, --help  Display this help text
  -l, --list  List files in \$VIDDIR

Environment Variables:
  VIDDIR     The directory containing the videos
             ($VIDDIR)
  FILTER     The glob filter used to find videos in VIDDIR
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
			else empty end,
			if .album_artist then
				"Directed by "+.album_artist
			 else empty end,
			 if .date then
				"Original Airdate: " + .date
			else empty end')"

	if [ -n "$description" ]; then
		echo "$description"
		echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
		if [ -n "$DESCOPT" ]; then
			"$PLAYER" $PLAYEROPT $DESCOPT "$description" "$1" 2>/dev/null
		else
			"$PLAYER" $PLAYEROPT "$1" 2>/dev/null
		fi
	fi
}

random_vid() {
	local filename
	filename=$(ls -1 $FILTER | sort -R | head -1)
	echo "${BOLD}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo "$(vidstring):"
	echo "${filename}"
	echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${OFFBOLD}"
	play "$filename"
}

named_vid() {
	local filenames
	local filelist
	local filenum
	local numfiles
	local result
	result=0

	if [ -f "$1" ]; then
		filenames="$1"
	else
		filelist="$(ls -1 $FILTER | nl -s ":")"
		if [ "$1" -lt 0 ] 2>/dev/null; then
			numfiles=$(echo "$filelist" | tail -n1 | cut -d ":" -f 1)
			# $1 should be a sanely formatted negative number here
			filenum=$(($numfiles + 1 + $1))
		else
			# $1 is possibly not a number here
			filenum="$1"
		fi

		filenames="$(echo "$filelist" | grep -s -E "^ *$filenum:" | cut -d ":" -f 2-)"
		if [ -z "$filenames" ]; then
			filenames="$(echo "$filelist" | grep -s -i "$1" | cut -d ":" -f 2-)"
		fi
		echo "filenames=" "$filenames"
	fi
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
			play "$i"
			result=$?
		done
		unset IFS
	fi
	return $result
}

script_main() {
	if [ $# -eq 0 ]; then
		random_vid
	else
		case $1 in
			-h|--help)
				usage
				return 0
			;;
			-l|--list)
				ls -1 $FILTER | nl -s ": "
				return 0
			;;
		esac

		for i in "$@"; do
			named_vid "$i" || echo "Playback failed ($?) for $i"
		done
	fi
}

cd "$VIDDIR" &&
script_main "$@"
