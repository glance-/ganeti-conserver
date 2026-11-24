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

# {"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": "alt"}, {"type": "qcode", "data": "sysrq"}, {"type": "qcode", "data": "b"}]}}
# {"execute": "inject-nmi"}
#echo '{"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": "alt"}, {"type": "qcode", "data": "sysrq"}]}}' >& "${MONITOR[1]}"
#echo '{"execute": "inject-nmi"}' >& "${MONITOR[1]}"

# How to dynamically figure out what the name of the serial console is:
# (but it's always serial0 due to how ganeti runs it.
if true ; then
	echo '{"execute": "query-chardev"}' >& "${MONITOR[1]}"
	read -t 5 -r resp <& "${MONITOR[0]}"

	if [ -z "$resp" ] || ! jq <<< "$resp" > /dev/null ; then
		echo "resp=$resp"
		echo command failed! >&2
		exit 5
	fi
	 
	SERIAL=$(jq -r '.return[] | select( .filename | endswith("serial,server=on")) | .label' <<< "$resp")

    if [ -z "$SERIAL" ] ; then
        echo "resp=$resp"
        echo "didn't find serial id" >&2
        exit 6
    fi
else
	SERIAL=serial0
fi

echo '{"execute": "chardev-send-break", "arguments": {"id": "'"$SERIAL"'"}}' >& "${MONITOR[1]}"

read -t 5 -r resp <& "${MONITOR[0]}"
if [ "$resp" != '{"return": {}}'$'\r' ] ; then
	echo "resp=$resp"
	echo execute chardev-send-break failed !>&2
	exit 7
fi

echo "Magic sysRq sent"

exec {MONITOR[1]}>&-
