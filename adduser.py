#!/usr/bin/python

import pexpect
import shlex
import subprocess
import sys

if __name__ == "__main__":
	username = sys.argv[1]
	print subprocess.check_output(shlex.split("useradd -G devs -m -s /usr/bin/git-shell %s" % username))
	child = pexpect.spawn('passwd %s' % username)
	child.expect('Enter new UNIX password:', 10)
	child.sendline(username)
	child.expect('Retype new UNIX password:', 10)
	child.sendline(username)
