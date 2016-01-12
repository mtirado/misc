#!/bin/bash
#
# usage: nuke-file <path> -n5
# nuke file at path, 5 iterations (optional)
#

set -e

if [ "$1" = "" ]; then
	echo "no target file specified"
	exit -1
fi

ITER=1
if [ "$2" = "-n" ]; then
	if [ "$3" = "" ]; then
		echo "-n specified without a value"
		exit -1
	fi
	if [ $3 -lt 1 ] || [ $3 -gt 1000 ]; then
		echo "-n specified with bad value"
		exit -1
	fi
	ITER=$3
fi


function nuke_file {
	LEN=$(wc -c <"$1")
	BS=4096
	COUNT=$((($LEN / $BS) + 1))
	echo "file($LEN): $1"
	echo "cmd: dd bs=$BS count=$COUNT"
	chmod +w $1
	CNT=0
	while [ $CNT -lt $ITER ]; do
		dd if=/dev/urandom of=$1 bs=$BS count=$COUNT
		CNT=$(($CNT + 1))
	done

	echo "zeroing..."
	dd if=/dev/zero of=$1 bs=$BS count=$COUNT
	rm $1
}

if [ -d "$1" ]; then
	echo "nuking all files in directory: $1"
	echo "press any key to continue"
	read -n 1 -s KEY
	find $1 -type f | while read ln; do
		nuke_file $ln
	done
elif [ -f "$1" ]; then
	echo "nuking single file: $1"
	echo "press any key to continue"
	read -n 1 -s KEY
	nuke_file $1
else
	echo "not a file or directory"
	exit -1
fi

rm -rf $1

