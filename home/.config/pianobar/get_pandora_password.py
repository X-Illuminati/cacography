#!/usr/bin/python3

import secretstorage
import sys

def eprint(*args, **kwargs):
	print(*args, file=sys.stderr, **kwargs)

dbus = secretstorage.dbus_init()
logins = secretstorage.get_default_collection(dbus)

if (logins.is_locked()):
	eprint("Keyring locked, requesting unlock");
	if (logins.unlock()):
		eprint("Unlock operation failed, aborting")
		sys.exit(1)

eprint("Searching %s keyring for Pandora password" % logins.get_label());
for i in logins.get_all_items():
	if i.get_label().lower() == "pandora":
		eprint("Found Pandora")
		print(i.get_secret().decode())
		sys.exit(0);
	else:
		eprint("Found something else")

sys.exit(1)
