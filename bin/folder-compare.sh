#!/bin/bash
# Compares $FOLDER1 to $FOLDER2 and generates a report in
# $REPORTDIR/YYYY-MM-DD$REPORTNAME.html

# Set default values for variables
FOLDER1=${FOLDER1:-/srv/md5}
FOLDER2=${FOLDER2:-/srv/md6}
REPORTDIR=${REPORTDIR:-/srv}
REPORTNAME=${REPORTNAME:-""}

# Don't use the bcompare helper script
if [ -d "/usr/lib64/beyondcompare/" ]; then
	export LD_LIBRARY_PATH="/usr/lib64/beyondcompare/"
	BC_EXEC="/usr/lib64/beyondcompare/BCompare"
elif [ -d "/usr/lib/beyondcompare/" ]; then
	export LD_LIBRARY_PATH="/usr/lib/beyondcompare/"
	BC_EXEC="/usr/lib/beyondcompare/BCompare"
else
	return 255
fi
# Change to the report dir
cd $REPORTDIR
umask 027

# Pass a script to bcompare by process substitution
# with cat echoing here-document
$BC_EXEC -silent @<(cat << EOF
log verbose append:"compare-report.log"
criteria timestamp size
load "$FOLDER1" "$FOLDER2"
expand all
folder-report layout:summary options:display-mismatches output-to:"%date%$REPORTNAME.html" output-options:html-color
folder-report layout:summary options:display-mismatches output-to:"%date%$REPORTNAME.txt"
EOF
)
