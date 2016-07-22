#!/bin/sh
# sync newroot installations with home podroot directories
# to maintain read-only access during non-core system build
set -e
NEWROOT=$HOME/newroot
echo "NEWROOT -- $NEWROOT"
rsync -av --delete-after $NEWROOT/* "$HOME"
