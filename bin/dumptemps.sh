#!/bin/dash

echo "Timestamp,Sensor Name,Overflow,radeon,k10temp,/dev/sda,/dev/sdb,/dev/sdc,/dev/sdd,/dev/sde,/dev/sdf,/dev/sdg,/dev/sdh,/dev/sdi,/dev/sdj,/dev/sdk,/dev/sdl,/dev/sdm,/dev/sdn,/dev/sdo,/dev/sdp,/dev/sdq,/dev/sdr,/dev/sds,/dev/sdt,/dev/sdu,/dev/sdv,/dev/sdw,/dev/sdx,/dev/sdy,/dev/sdz"
journalctl --since=today -o short-iso -t hddtemp -t sensord $@ | sed -rne "
/radeon-pci/{
  n
  n
  s/(^.{19}).{5}/\1,/
  s/[[:space:]]*:[[:space:]]*/,/g
  s/(^.*),(.*),(.*),/\1,\3,/
  s/ C$//
  s/(^.*),temp1,/\1,radeon (C),,/
  p
}
/k10temp-pci/{
  n
  n
  s/(^.{19}).{5}/\1,/
  s/[[:space:]]*:[[:space:]]*/,/g
  s/(^.*),(.*),(.*),/\1,\3,/
  s/ C$//
  s/(^.*),temp1,/\1,k10temp (C),,,/
  p
}
/SanDisk/d
\_/dev/sd._{
  s/(^.{19}).{5}/\1,/
  s/[[:space:]]*:[[:space:]]*/,/g
  s/(^.*),(.*),(.*),(.*),/\1,\3,\4,/
  s/ C$//
  s_(^.*),(/dev/)(sd.),(.*),_\1,\2\3 \4 (C),!\3!_
  s/!sda!/,,,/
  s/!sdb!/,,,,/
  s/!sdc!/,,,,,/
  s/!sdd!/,,,,,,/
  s/!sde!/,,,,,,,/
  s/!sdf!/,,,,,,,,/
  s/!sdg!/,,,,,,,,,/
  s/!sdh!/,,,,,,,,,,/
  s/!sdi!/,,,,,,,,,,,/
  s/!sdj!/,,,,,,,,,,,,/
  s/!sdk!/,,,,,,,,,,,,,/
  s/!sdl!/,,,,,,,,,,,,,,/
  s/!sdm!/,,,,,,,,,,,,,,,/
  s/!sdn!/,,,,,,,,,,,,,,,,/
  s/!sdo!/,,,,,,,,,,,,,,,,,/
  s/!sdp!/,,,,,,,,,,,,,,,,,,/
  s/!sdq!/,,,,,,,,,,,,,,,,,,,/
  s/!sdr!/,,,,,,,,,,,,,,,,,,,,/
  s/!sds!/,,,,,,,,,,,,,,,,,,,,,/
  s/!sdt!/,,,,,,,,,,,,,,,,,,,,,,/
  s/!sdu!/,,,,,,,,,,,,,,,,,,,,,,,/
  s/!sdv!/,,,,,,,,,,,,,,,,,,,,,,,,/
  s/!sdw!/,,,,,,,,,,,,,,,,,,,,,,,,,/
  s/!sdx!/,,,,,,,,,,,,,,,,,,,,,,,,,,/
  s/!sdy!/,,,,,,,,,,,,,,,,,,,,,,,,,,,/
  s/!sdz!/,,,,,,,,,,,,,,,,,,,,,,,,,,,,/
  p
}
"
