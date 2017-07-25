# Cacography
Various scripts, .bash_alias, etc. Probably only useful to me.

## Contents

### root-level
Project-related files

file      | description
----------|------------
README.md | This file.
LICENSE   | GPLv3 - not suitable for everything, but seemed like a reasonable default
update.sh | Script to compare files in the filesystem and update the repository if they differ
orig      | Directory with copies of the original files (.rpmnew).

### home
Various config files that belong somewhere in ~/.

file              | description
------------------|------------
.bash_alias       | Some aliases that I find handy.

### notes
Random notes/documentation

file                  | description
----------------------|------------
linux_array_setup.txt | Some old notes from when mdadm was less forgiving. Also has some newer notes mixed in, so it might still be useful.

### bin
Various scripts that need to be in the $PATH.

file                | description
--------------------|------------
dumptemps.sh        | Script to extract temperature information from hddtemp journalctl logs.
folder-compare.sh   | Script to compare a folder to its backup using Beyond Compare and generate a report. I don't think this works very well since I haven't used it recently.
uri-open.sh         | An extensible bash script that looks at the URI passed in $1 and chooses a sensible browser/application to open it.
raid-check          | Modified version of Fedora's mdadm-raid-check that better supports only checking one raid array at a time.
mdadm-syslog-events | Modified syslog script for mdadm that sends out notifications using kdialog when array status changes (goes in /usr/sbin).
notify-all.sh       | Script to (attempt) discover all dbus-session busses and notify-send to each of them.

### cron.d
Various cron jobs.

file        | description
------------|------------
md-compare  | Uses rsync dry-run to create a diff report between my active and backup raid array.
raid-check  | Uses raid-check to check the raid array integrity. Each array is checked on alternating months.
temp-report | Uses dumptemps.sh to create a daily temperature report.

### etc
Various config files that belong somewhere in /etc.

file        | description
------------|------------
raid-check  | Modified configuration for the raid-check script to better support only checking one raid array at a time.
mdadm.conf  | Configuration for mdadm to specify array setup and notification script.
smb.conf    | Configuration for Samba.
ssh_config  | Configuration for ssh clients.
sshd_config | Configuration for sshd server.

## TODO
Need to add some sort of install.sh to copy all of these to sensible locations.
Probably need an easy way to compare them during that process.
