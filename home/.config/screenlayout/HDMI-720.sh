#!/bin/sh

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
flock -n "$XDG_CONFIG_HOME/screenlayout" -c '
echo "Setting display mode to HDMI-1 1280x720" ;
xrandr --output HDMI-1 --mode 1280x720 --output LVDS-1 --off  && {
	ln -sf LVDS.sh "$XDG_CONFIG_HOME/screenlayout/rotate.sh"
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode -s true
} || {
	echo "HDMI-1 failed, falling back to LVDS-1 1280x800"
	xrandr --output HDMI-1 --off --output LVDS-1 --mode 1280x800
	ln -sf Dual-1080.sh "$XDG_CONFIG_HOME/screenlayout/rotate.sh"
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/presentation-mode -s false
} ;
sleep 1'
