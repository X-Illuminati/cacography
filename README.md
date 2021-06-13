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

file                      | description
--------------------------|------------
.bash_alias               | Some aliases that I find handy.
.bashrc                   | Update PS1 to include prev command's return code
.XCompose                 | Custom compose keys
bigclive.sh               | Play a random BigCliveDotCom video
happy-trees.sh            | Play a random Bob Ross Joy of Painting episode
randi-scandi.sh           | Play a random QI episode
good-news.sh              | Play a random Futurama episode
that-pudgy-tummy.sh       | Play a random Aria episode
swedish_murder_machine.sh | Play a random Venture Bros episode

#### .config
Various config files that belong in XDG_CONFIG_DIR

file              | description
------------------|------------
screenlayout      | Scripts for configuring the screen layout using xrandr
OpenSCAD          | Configuration for OpenSCAD with all of the SpacePilot button settings
pianobar          | Configuration files for pianobar

#### .local
Various config files that belong in XDG_DATA_HOME

file                 | description
---------------------|------------
file-manager-actions | File-manager right-click actions following DES-EMA spec
kde-service-menus    | File-manager right-click actions following KDE Desktop Action format
gmail.desktop        | Desktop file to launch separate firefox profile for gmail

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
compare-helper.sh   | Script to handle right-click actions select-for-compare and compare-to
uri-open.sh         | An extensible bash script that looks at the URI passed in $1 and chooses a sensible browser/application to open it.
raid-check          | Modified version of Fedora's mdadm-raid-check that better supports only checking one raid array at a time.
mdadm-syslog-events | Modified syslog script for mdadm that sends out notifications using kdialog when array status changes (goes in /usr/sbin).
notify-all.sh       | Script to (attempt) discover all dbus-session busses and notify-send to each of them.
hardlink-dedup.sh   | Scan directory for identical files and replace them with hardlinks.
repeat.sh           | Repeat a command within specified limits.
spstart.sh          | Script to properly start spacenavd with the quirks of my SpacePilot HP
ripscript.sh        | Script to automate DVD ripping
binary_merge.py     | Script to compare multiple binary files and create a merged output based on consensus

### cron.d
Various cron jobs.

file        | description
------------|------------
md-compare  | Uses rsync dry-run to create a diff report between my active and backup raid array.
raid-check  | Uses raid-check to check the raid array integrity. Each array is checked on alternating months.
temp-report | Uses dumptemps.sh to create a daily temperature report.

### etc
Various config files that belong somewhere in /etc.

file           | description
---------------|------------
raid-check     | Modified configuration for the raid-check script to better support only checking one raid array at a time.
mdadm.conf     | Configuration for mdadm to specify array setup and notification script.
smb.conf       | Configuration for Samba.
ssh_config     | Configuration for ssh clients.
sshd_config    | Configuration for sshd server.
NetworkManager | Helper scripts for NetworkManager (primarily to fixup routing tables for wireguard)

## TODO
Need to add some sort of install.sh to copy all of these to sensible locations.
Probably need an easy way to compare them during that process.
