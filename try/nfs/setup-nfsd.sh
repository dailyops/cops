#!/usr/bin/env bash
set -e

LINE="/Users -alldirs -mapall=$(id -u):$(id -g) localhost"
FILE=/etc/exports
grep -qF -- "$LINE" "$FILE" || sudo echo "$LINE" | sudo tee -a $FILE

LINE="nfs.server.mount.require_resv_port = 0"
FILE=/etc/nfs.conf
grep -qF -- "$LINE" "$FILE" || sudo echo "$LINE" | sudo tee -a $FILE > /dev/null

sudo nfsd restart