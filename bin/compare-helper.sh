#!/bin/sh

#global variables
SCRIPT_NAME="$(basename $0)"
[ -z "$TMPDIR" ] && TMPDIR="/tmp"
[ -z "$SELFILE" ] && SELFILE="${TMPDIR}/compare-helper-selection"
[ -z "$DIFFTOOL" ] && DIFFTOOL="bcompare"

usage ()
{
	echo "Usage: ${SCRIPT_NAME} [options] [FILE]

Select a file for comparison or execute the comparison with the selected file.
When invoked with no options, the selected file will be printed (same as -g).
When invoked with a single filename, that file will be compared with the file
that was previously selected using the -s option.

Options:
  -h       Display this help text.
  -g       Get (print) the selected file.
  -t       Test whether a file has been selected - prints \"true\" or \"false\".
  -c       Clear the file selection.
  -s FILE  Save FILE as the current selection.
"
}

test_selection ()
{
	local selection

	if [ -f "${SELFILE}" ]; then
		selection="$(cat "${SELFILE}")"
		if [ $? -eq 0 -a -e "${selection}" ]; then
			return 0
		fi
	fi
	return 1
}

get_selection ()
{
	test_selection && cat "${SELFILE}"
}

set_selection ()
{
	if [ -e "$1" ]; then
		echo "$1" > "${SELFILE}"
	else
		echo "File does not exist: $1" 1>&2
		false
	fi
}

compare_invoke ()
{
	local selection
	if [ ! -e "$1" ]; then
		echo "File does not exist: $1" 1>&2
	fi

	if test_selection; then
		[ -e "$1" ] && {
			selection="$(cat "${SELFILE}")"
			${DIFFTOOL} "${selection}" "$1"
		}
	else
		echo "Selection for comparison is invalid" 1>&2
		false
	fi
}

script_main ()
{
	#only takes single command line parameter
	#none have arguments except -s which only has 1
	if [ $# -gt 2 ]; then
		usage
		return 1
	fi
	if [ $# -gt 1 -a "$1" != "-s" ]; then
		usage
		return 1
	fi

	if [ $# -eq 0 ]; then
		get_selection
	else
		case $1 in
			-h)
				usage
			;;
			-g)
				get_selection
			;;
			-t)
				if test_selection; then
					echo true
				else
					echo false
					false
				fi
			;;
			-c)
				rm -f "${SELFILE}"
			;;
			-s)
				if [ $# -eq 2 ]; then
					set_selection "$2"
				else
					usage
					false
				fi
			;;
			*)
				compare_invoke "$1"
			;;
		esac
	fi
}

script_main "$@"
