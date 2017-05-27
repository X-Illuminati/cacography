# Cacography
Various scripts, .bash_alias, etc. Probably only useful to me.

## Contents
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

file              | description
------------------|------------
dumptemps.sh      | Script to extract temperature information from hddtemp journalctl logs.
folder-compare.sh | Script to compare a folder to its backup using Beyond Compare and generate a report. I don't think this works very well since I haven't used it recently.
uri-open.sh       | An extensible bash script that looks at the URI passed in $1 and chooses a sensible browser/application to open it.
raid-check        | Modified version of Fedora's mdadm-raid-check that better supports only checking one raid array at a time.

### cron.d
Various cron jobs.

file        | description
------------|------------
md-compare  | Uses rsync dry-run to create a diff report between my active and backup raid array.
raid-check  | Uses raid-check to check the raid array integrity. Each array is checked on alternating months.
temp-report | Uses dumptemps.sh to create a daily temperature report.

### etc
Various config files that belong somewhere in /etc.

file       | description
-----------|------------
raid-check | Modified configuration for the raid-check script to better support only checking one raid array at a time.

## TODO
Need to add some sort of install.sh to copy all of these to sensible locations.
Probably need an easy way to compare them during that process.
