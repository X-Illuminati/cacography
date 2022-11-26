#!/bin/bash

DEVICE="/dev/dvd"
TEMPDIR="$HOME/Desktop/"
BASEPATH="$HOME/boxy/"
ISOPATH="ISO/"
CSUMPATH="SCRATCH/checksums.txt"
SSHHOST="boxy"
SSHBASEPATH="/srv/current/"

ISOTARGET="$BASEPATH/$ISOPATH/"
FDPATH="$ISOPATH/FullDisc/"
FDTARGET="$BASEPATH/$FDPATH/"
CSUMFILE="$BASEPATH/$CSUMPATH"
SSHISOPATH="$SSHBASEPATH/$ISOPATH/"
SSHFDPATH="$SSHBASEPATH/$FDPATH/"
SSHCSUMFILE="$SSHBASEPATH/$CSUMPATH"

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

stderror()
{
    echo "$@" >/dev/stderr
}

check_deps()
{
    [ -x "$(type -p cp)" ] || { stderror "cp not found"; return 1; }
    [ -x "$(type -p head)" ] || { stderror "head not found"; return 1; }
    [ -x "$(type -p tail)" ] || { stderror "tail not found"; return 1; }
    [ -x "$(type -p df)" ] || { stderror "df not found"; return 1; }
    [ -x "$(type -p grep)" ] || { stderror "grep not found"; return 1; }
    [ -x "$(type -p find)" ] || { stderror "find not found"; return 1; }
    [ -x "$(type -p sed)" ] || { stderror "sed not found"; return 1; }
    [ -x "$(type -p awk)" ] || { stderror "awk not found"; return 1; }
    [ -x "$(type -p xargs)" ] || { stderror "xargs not found"; return 1; }
    [ -x "$(type -p sha256sum)" ] || { stderror "sha256sum not found"; return 1; }
    [ -x "$(type -p udflabel)" ] || { stderror "udflabel not found"; return 1; }
    [ -x "$(type -p dvdbackup)" ] || { stderror "dvdbackup not found"; return 1; }
    [ -x "$(type -p ssh)" ] || { stderror "ssh not found"; return 1; }
    ssh "$SSHHOST" "[ -x \"\$(type -p tee)\" ]" || {
        stderror "tee not found on remote target $SSHHOST"
        return 2
    }
    ssh "$SSHHOST" "[ -x \"\$(type -p sha256sum)\" ]" || {
        stderror "sha256sum not found on remote target $SSHHOST"
        return 2
    }
    ssh "$SSHHOST" "[ -x \"\$(type -p genisoimage)\" ]" || {
        stderror "genisoimage not found on remote target $SSHHOST"
        return 2
    }
}

get_dvdsize()
{
    dvdbackup -I -i "$DEVICE" 2>/dev/null | grep $'\tV' |
        awk '{ sum += $2 } END { print sum }'
}

get_dvdname()
{
    dvdbackup -I -i "$DEVICE" 2>/dev/null | head -n 1 |
        sed -e "s/^[^\"]*\"//" -e "s/\"$//"
}

get_udflabel()
{
    local label
    label="$(udflabel "$DEVICE" 2>/dev/null)"
    if [ -z "$label" ]; then
        stderror "Warning: unable to parse UDF label for $DEVICE"
        stderror "Please enter the desired label: "
        read $label
    fi
    echo "$label"
}

get_freespace()
{
    {
        df -B 1 --output=avail "$@" 2>/dev/null || {
            echo 0
            return 1
        }
    } | tail -n 1
}

query_continue()
{
    stderror -n "Continue? "
    read
    case "$REPLY" in
        y*|Y*)
            return 0
            ;;
    esac
    return 1
}

main()
{
    local size
    local name
    local label
    local sha_sum
    local power

    # check that we are running on AC power
    power=$(cat /sys/class/power_supply/AC/online)
    if [ ${power:=0} -eq 0 ]; then
        stderror "Notice: Currently running on battery power"
        query_continue || return 130
    fi

    # get size of DVD
    size=$(get_dvdsize)
    # sanity check disc size
    if [ ${size:=0} -eq 0 ]; then
        stderror "Error: Unable to find size for $DEVICE"
        return 3
    fi
    if [ $size -gt 10000000000 ]; then
        stderror "Warning: implausible size for $DEVICE, $size"
        query_continue || return 130
    fi

    # get DVD name
    name="$(get_dvdname)"
    # sanity check the DVD name
    if [ -z "$name" ]; then
        stderror "Error: Unable to read DVD name for $DEVICE"
        return 3
    fi

    # get UDF label of the disc
    label="$(get_udflabel)"
    # sanity check the UDF label
    if [ -z "$label" ]; then
        stderror "Error: Unable to read UDF label for $DEVICE"
        return 3
    fi

    # print summary	
    echo "Summary:"
    echo "  Need ${size:-0} bytes on $TEMPDIR/$name"
    echo "  Need $((2*${size:-0})) bytes on $ISOTARGET for"
    echo "    ${label}.ISO"
    echo "    FullDisc/$name"

    # sanity check local temp dir
    if [ ! -d "$TEMPDIR" ]; then
        stderror "Error: $TEMPDIR does not exist"
        return 4
    fi
    if [ $size -gt $(get_freespace -l "$TEMPDIR") ]; then
        stderror "Error: $TEMPDIR out of space, need $size bytes"
        return 4
    fi

    # sanity check remote ISO dir
    if [ ! -d "$ISOTARGET" ]; then
        echo "Error: $ISOTARGET does not exist" >/dev/stderr
        return 5
    fi
    if [ $((2*$size)) -gt $(get_freespace "$ISOTARGET") ]; then
        echo "Error: $ISOTARGET out of space, need $((2*$size)) bytes" >/dev/stderr
        return 5
    fi
    # sanity check remote FullDisc dir
    if [ ! -d "$FDTARGET" ]; then
        echo "Error: $FDTARGET does not exist" >/dev/stderr
        return 5
    fi

    # sanity check files/directories already exist
    if [ -e "$ISOTARGET/${label}.ISO" ]; then
        stderror "Error: "$ISOTARGET/${label}.ISO" already exists!"
        return 6
    fi
    if [ -e "$FDTARGET/$name" ]; then
        stderror "Error: $FDTARGET/$name already exists!"
        return 6
    fi
    if [ -e "$TEMPDIR/$name" ]; then
        if [ ! -d "$TEMPDIR/$name" ]; then
            stderror "Error: $TEMPDIR/$name already exists!"
            return 6
        else
            stderror "Warning: $TEMPDIR/$name already exists!"
            query_continue || return 130
        fi
    else
        echo "Everything ready for ripping $name"
        query_continue || return 130
    fi

    # begin ripping
    time dvdbackup -M -p -r b -i "$DEVICE" -o "$TEMPDIR" || return 20
    eject "$DEVICE" &

    # calculate checksums
    echo "Calculating checksums for $TEMPDIR/$name"
    cd "$TEMPDIR/$name" || return 31
    time find . -type f ! -name SHA256SUM -print0 |
        xargs -0 sha256sum > SHA256SUM || return 32
    sha_sum="$(sha256sum SHA256SUM)" || return 33
    cd - >/dev/null || return 34
    echo -e "\n${name}\n${sha_sum}" >> "$CSUMFILE"

    # copy to FullDisc target
    echo "Copying $TEMPDIR/$name to $FDTARGET/"
    time cp -R "$TEMPDIR/$name" "$FDTARGET/" || return 40

    # check copy result
    ssh "$SSHHOST" "cd \"$SSHFDPATH/$name\" && sha256sum --check" <<< "$sha_sum" || return 50
    time ssh "$SSHHOST" "cd \"$SSHFDPATH/$name\" && sha256sum --check SHA256SUM" || return 51

    # generate ISO image
    time ssh "$SSHHOST" "genisoimage -dvd-video -V \"$label\" -o \"$SSHISOPATH/${label}.ISO\" \"$SSHFDPATH/$name\"" || return 60
    echo "Calculating checksums on remote $SSHHOST"
    time ssh "$SSHHOST" "cd \"$SSHISOPATH/\" && sha256sum \"${label}.ISO\" | tee -a \"$SSHCSUMFILE\"" || return 61
    echo "$sha_sum"
}

check_deps &&
main "$@"
