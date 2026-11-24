#!/bin/bash

. DATA

while read -r name ; do
	cat <<EOC
console $name {
	master $CLUSTER_NAME 
	include ganeti;
	host $CLUSTER_NAME;
}
EOC
done < <(ssh "$CLUSTER_NAME" gnt-instance list --no-headers -o name -F "'status == \"running\"'")
