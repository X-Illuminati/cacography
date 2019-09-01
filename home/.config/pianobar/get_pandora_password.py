#!/usr/bin/python3

import secretstorage
import sys

def eprint(*args, **kwargs):
	print(*args, file=sys.stderr, **kwargs)

dbus = secretstorage.dbus_init()
logins = secretstorage.get_default_collection(dbus)

eprint("Searching %s keyring for Pandora password" % logins.get_label());
for i in logins.get_all_items():
	if i.get_label().lower() == "pandora":
		eprint("Found Pandora")
		print(i.get_secret().decode())
		break
	else:
		eprint("Found something else")
