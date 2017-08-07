#!/bin/sh

SCRIPT_VER="0.1"
RECURSEDEF=1
RECURSE=$RECURSEDEF
FORCE=0
VERBOSE=0

show_help ()
{
	local recursedefault
	local norecursedefault
	if [ 1 -eq $RECURSEDEF ]; then
		recursedefault=" [default]"
		norecursedefault=""
	else
		recursedefault=""
		norecursedefault=" [default]"
	fi

	echo "\
Usage:
 $scriptname [options] [sourcedir [targetdir [md5file]]]

Use md5sum comparison of files in the sourcedir to find duplicates and replace
them with hardlinks in the targetdir.
The md5file can be specified if the sums were already collected previously, but
this is generally discoraged as the contents won't be verified.

Options:
 -h, --help     display this help and exit
 -f, --force    be more forceful about operations
 -v, --verbose  be more verbose
 -V, --version  output version information and exit

File Options:
 -s, --source-dir=<dir>  set the sourcedir
 -t, --target-dir=<dir>  set the targetdir
 -m, --md5-file=<file>   provide file with md5sum output
If a file option is specified, that value will be assumed when evaluating the
remaining command line parameters.
For example, \"-t targetdir sourcedir md5file\" is valid.

Recursion Options:
 -r,-R,--recurse  work on the sourcedir recursively$recursedefault
 -n,--no-recurse  only work on the direct contents of sourcedir and not its
                  subdirectories$norecursedefault
The recursion options have no effect if an md5sum file is specified.
"
}

show_version ()
{
	echo "hardlink-dedup.sh version $SCRIPT_VER"
}

get_md5sums ()
{
	local md5dir
	local md5file
	md5dir="$1"
	md5file="$2"

	{
		if [ -z "$md5file" ]; then
			if [ 1 -eq $RECURSE ]; then
				find "$md5dir" -type f \
					-exec md5sum -b {} \; | sort
			else
				find "$md5dir" -maxdepth 1 -type f \
					-exec md5sum -b {} \; | sort
			fi
		else
			sort "$md5file"
		fi
	} | sed -n -e \
	"s_^\([[:xdigit:]]\{1,\}\)\([[:space:]\*]\{1,\}\)\(.\{1,\}\)\$_\1 '\3'_p"
}

canonicalize_path ()
{
	local pathname
	pathname="$1"
	pathname="$(echo "$pathname" | sed -e "s_/\(\./\|/\)*_/_g" \
		-e "s_^\(\./\)__" -e "s_/\$__")"
	[ -z "$pathname" ] && pathname="."
	echo "$pathname"
}

remove_prefix ()
{
	local dirname
	local filename
	dirname=$(canonicalize_path "$1")
	filename=$(canonicalize_path "$2")
	echo "${filename#${dirname}/}"
}

fileop ()
{
	local operation
	local srcfile
	local tgtfile
	local copyflags
	local checktgt
	operation="$1"
	srcfile="$2"
	tgtfile="$3"
	if [ 1 -eq $FORCE ]; then
		copyflags="-f"
		checktgt=0
	else
		copyflags=""
		checktgt=1
	fi

	case "$operation" in
		copy)
		;;

		link)
			operation="    $operation"
			copyflags="-l $copyflags"
		;;

		replace)
			operation="    $operation"
			copyflags="-lf"
			checktgt=0
		;;
	esac

	[ 1 -eq $VERBOSE ] &&
		echo "$operation($copyflags) \"$srcfile\" to \"$tgtfile\""

	[ 1 -eq $checktgt -a -e "$tgtfile" ] && {
		echo "Error: \"$tgtfile\" already exists"
		return 1
	}

	mkdir -p "$(dirname "$tgtfile")"
	if [ "copy" = "$operation" ]; then
		# try to hardlink the copy, but fallback on normal copy
		cp -l $copyflags "$srcfile" "$tgtfile" 2>/dev/null ||
			cp $copyflags "$srcfile" "$tgtfile"
	else
		cp $copyflags "$srcfile" "$tgtfile"
	fi
}

do_processing ()
{
	local srcdir
	local tgtdir
	local md5file
	local md5sums
	local matchsum
	local matchfile
	local curfile
	local sepdir
	srcdir=$(canonicalize_path "$1")
	tgtdir=$(canonicalize_path "$2")
	md5file="$3"

	if [ "$srcdir" -ef "$tgtdir" ]; then
		sepdir=0
		[ 1 -eq $VERBOSE ] && echo "Running deduplication process entirely within \"$srcdir\""
	else
		sepdir=1
		[ 1 -eq $VERBOSE ] && echo "Deduplicating by copying \"$srcdir\" to \"$tgtdir\""
	fi

	md5sums=$(get_md5sums "$srcdir" "$3")

	eval set -- $md5sums
	while [ $# -gt 0 ]; do
		curfile=$(remove_prefix "$srcdir" "$2")
		if [ "$matchsum" != "$1" ]; then
			matchsum="$1"
			matchfile="$curfile"
			if [ 1 -eq $sepdir ]; then
				fileop "copy" "$srcdir/$matchfile" \
					"$tgtdir/$curfile" || return $?
			fi
			[ 1 -eq $VERBOSE ] &&
				echo "Checking for matches with $curfile"
		else
			[ 1 -eq $VERBOSE ] && echo "  Found match $curfile"
			if [ 1 -eq $sepdir ]; then
				fileop "link" "$tgtdir/$matchfile" \
					"$tgtdir/$curfile" || return $?
			else
				fileop "replace" "$tgtdir/$matchfile" \
					"$tgtdir/$curfile" || return $?
			fi
		fi
		shift 2
	done

}

script_main ()
{
	local srcdir
	local tgtdir
	local md5file
	local scriptname
	scriptname=$(basename "$0")

	options=$(getopt -o "hfvVs:t:m:rRn" \
		-l "help,force,verbose,version" \
		-l "source-dir:,target-dir:,md5-file:" \
		-l "recurse,no-recurse" \
		-- "$@")
	[ $? -eq 0 ] || {
		show_help "$scriptname"
		return 1
	}

	eval set -- "$options"
	while [ $# -gt 0 ]; do
		case "$1" in
			-h|--help)
				show_help "$scriptname"
				return 0
			;;

			-f|--force)
				FORCE=1
			;;

			-v|--verbose)
				VERBOSE=1
			;;

			-V|--version)
				show_version
				return 0
			;;

			-s|--source-dir)
				shift
				srcdir="$1"
			;;

			-t|--target-dir)
				shift
				tgtdir="$1"
			;;

			-m|--md5-file)
				shift
				md5file="$1"
			;;

			-r|-R|--recurse)
				RECURSE=1
			;;

			-n|--no-recurse)
				RECURSE=0
			;;

			--)
				shift
				break
			;;
		esac
		shift
	done

	[ -z "$srcdir" ] && { srcdir="$1"; shift; }
	[ -z "$tgtdir" ] && { tgtdir="$1"; shift; }
	[ -z "$md5file" ] && { md5file="$1"; shift; }

	[ -z "$srcdir" ] && { srcdir="."; }
	[ -z "$tgtdir" ] && { tgtdir="$srcdir"; }

	[ -d "$srcdir" ] || {
		echo "Source directory \"$srcdir\" is invalid"
		return 1
	}
	[ -d "$tgtdir" ] || {
		if [ 1 -eq $FORCE -a ! -e "$tgtdir" ]; then
			mkdir -p "$tgtdir" || return $?
		else
			echo "Target directory \"$tgtdir\" is invalid"
			return 1
		fi
	}
	[ -n "$md5file" ] &&
		[ ! -f "$md5file" -a ! -p "$md5file" ] && {
			echo "md5sum output file \"$md5file\" is invalid"
			return 1
		}

	do_processing "$srcdir" "$tgtdir" "$md5file"
}

script_main "$@"
