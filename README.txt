Config and helpers for using conserver for console access in a ganeti cluster.

This is to get multiple users access to the consoles in a ganeti cluster,
and give them a standardized way of accessing them and start/stop/reset
etc vms.

All these are made to work on Debian but may be adapted for other distros.

On all masters:
apt-get install conserver-client conserver-server

Files goes in /etc/conserver on masters.

Create ssh key for conservr to access ganeti:
mkdir ~conservr/.ssh
ssh-keygen -f ~conservr/.ssh/id_ed25519
chown -Rh conservr ~conservr/.ssh

Create ~conservr/.ssh/known_hosts with master ssh fingerprint:
cp /var/lib/ganeti/known_hosts ~conservr/.ssh/


gnt-instance-force.pl
Install at all masters in /usr/local/libexec, and use it as a forced command
for a ssh key from the conserver user to the master(s).

ex:
from="cluster-name,<master-ip>",restrict,pty,command="/usr/local/libexec/gnt-instance-force.pl" ssh-...


Generate your instance list:
make -C /etc/conserver/


Connect to instance console:
console instance1
