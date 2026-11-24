#!/bin/bash

INSTANCE=$1

if [ -z "$INSTANCE" ] ; then
	echo "Usage: $0 <instance>"
	exit 1
fi

PNODE=$(gnt-instance list --no-headers -o pnode "$INSTANCE")

if [ -z "$PNODE" ] ; then
	echo "Can't find PNODE"
	exit 2
fi

coproc MONITOR ( ssh -T "$PNODE" socat UNIX-CONNECT:/var/run/ganeti/kvm-hypervisor/ctrl/"$INSTANCE".qmp STDIO )

# Read hello string.
# {"QMP": {"version": {"qemu": {"micro": 13, "minor": 0, "major": 10}, "package": "Debian 1:10.0.13+ds-0+deb13u1"}, "capabilities": ["oob"]}}
read -t 5 -r resp <& "${MONITOR[0]}"

# Simple parser check, we got some json.
if [ -z "$resp" ] || ! jq <<< "$resp" > /dev/null ; then
	echo "resp=$resp"
	echo hello string failed >&2
	exit 3
fi

echo '{"execute": "qmp_capabilities"}' >& "${MONITOR[1]}"
read -t 5 -r resp <& "${MONITOR[0]}"
if [ "$resp" != '{"return": {}}'$'\r' ] ; then
	echo "resp=$resp"
	echo qmp_capabilities failed! >&2
	exit 4
fi

echo '{ "execute": "system_reset" }' >& "${MONITOR[1]}"

# resp={"timestamp": {"seconds": 1792672862, "microseconds": 849196}, "event": "RESET", "data": {"guest": false, "reason": "host-qmp-system-reset"}}

read -t 5 -r resp <& "${MONITOR[0]}"
#if [ "$resp" != '{"return": {}}'$'\r' ] ; then
if [ -z "$resp" ] || ! jq <<< "$resp" > /dev/null ; then
	echo "resp=$resp"
	echo execute system_reset failed !>&2
	exit 7
fi

echo "system_reset done"

exec {MONITOR[1]}>&-
