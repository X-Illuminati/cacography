#!/bin/sh

#global variables
SCRIPT_NAME="$0"
SLEEP="0"
COUNT=-1
END_TIME=""
IGNORE_ERRORS=0
PAUSE=0

#some programs trap SIGINT and don't re-raise it
#also, they sometimes exit(0)
#also, we have an option to ignore the exit status
#so, we need to trap SIGINT ourselves and force an exit of the script
trap 'echo "${SCRIPT_NAME}: interrupted"; exit 130' INT

#just to be safe...
trap 'stty icanon' EXIT

usage ()
{
	echo "Usage: ${SCRIPT_NAME} [options] [--] command [args]

Repeat command until it fails or is interrupted.

Options:
  -h, --help          Display this help text.
  -c, --count NUM     Repeat the command NUM times and then stop.
  -i, --ignore-errors Ignore failure status codes from command.
  -p, --pause         Pause between each execution until a key is pressed.
  -s, --sleep WORD    Sleep between each execution of command.
  -t, --time STRING   Repeat the command until the specified time is
                      reached and then stop.
  -v, --verbose       Display details about the parsed options.

Time specification:
  The STRING provided to -t will be passed to the GNU date utility in
  order to leverage its parse_datetime function.
  Examples:
    ${SCRIPT_NAME} -t '2 hours'
    ${SCRIPT_NAME} -t '2PM next Thursday'
  For details on the format run:
    info date 'Date input formats'
"
}

do_repeat ()
{
	local now
	local result

	[ -n "${END_TIME}" ] && now="$(date +"%s%N")"

	while [ ${COUNT} -ne 0 ]; do
		[ -n "${END_TIME}" ] &&
			[ ${now} -gt ${END_TIME} ] &&
				break

		#run the command and check the result
		eval "$@"
		result=$?
		if [ ${IGNORE_ERRORS} -eq 0 -a ${result} -ne 0 ]; then
			echo "${SCRIPT_NAME}: error detected: ${result}"
			return ${result}
		fi

		#short-circuit the final sleep/pause
		[ -n "${END_TIME}" ] && {
			now="$(date +"%s%N")"
			[ ${now} -gt ${END_TIME} ] &&
				break
		}
		[ ${COUNT} -ne 1 ] && {
			sleep "${SLEEP}"
			[ ${PAUSE} -eq 1 ] && {
				echo "Press any key to continue"
				stty -icanon
				dd bs=1 count=1 >/dev/null 2>&1
				stty icanon
			}
		}

		#update loop condition variables
		[ ${COUNT} -ne -1 ] && COUNT=$((${COUNT}-1))
		[ -n "${END_TIME}" ] && now="$(date +"%s%N")"
	done
	return 0
}

script_main ()
{
	local datestring
	local verbose
	datestring=""
	verbose=0

	while [ $# -gt 0 ]; do
		case $1 in
			-h|--help)
				usage
				return 0
			;;
			-c|--count)
				COUNT=$2
				shift 2
			;;
			-i|--ignore-errors)
				IGNORE_ERRORS=1
				shift
			;;
			-p|--pause)
				PAUSE=1
				shift
			;;
			-s|--sleep)
				SLEEP="$2"
				shift 2
			;;
			-t|--time)
				datestring="$2"
				shift 2
			;;
			-v|--verbose)
				verbose=1
				shift
			;;
			--)
				shift
				break
			;;
			*)
				break
			;;
		esac
	done

	if [ $# -eq 0 ]; then
		# no command specified
		usage
		return 1
	fi

	[ -n "${datestring}" ] &&
		END_TIME="$(date --date="${datestring}" +"%s%N")"

	[ ${verbose} -eq 1 ] && {
		[ ${COUNT} -ne -1 ] &&
			echo "Count=${COUNT}"
		[ ${COUNT} -eq -1 ] &&
			echo "Count=infinite"
		[ ${PAUSE} -eq 1 ] &&
			echo "Pause enabled"
		[ ${PAUSE} -eq 0 ] &&
			echo "Pause disabled"
		echo "Sleep=${SLEEP}"
		[ -n "${datestring}" ] &&
			echo "Time=$(date --date="${datestring}")"
		[ ${IGNORE_ERRORS} -eq 1 ] &&
			echo "Errors=ignored"
		[ ${IGNORE_ERRORS} -eq 0 ] &&
			echo "Errors=halt"
		echo "Command=$@"
	}

	do_repeat "$@"
}

script_main "$@"
