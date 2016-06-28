#!/bin/bash
NEWROOT="newroot"
rm -rf $NEWROOT

echo "creating core GNU/Linux system"
set -e

#TODO scrub system strings
#TODO archive / checksums

mkdir $NEWROOT
mkdir $NEWROOT/{proc,sys,tmp,dev}
cp -rfv /{bin,boot,opt,etc,include,lib,libexec,man,sbin,share,var,usr} $NEWROOT

mknod -m 0666 $NEWROOT/dev/tty  	c 5 0
mknod -m 0600 $NEWROOT/dev/console 	c 5 1
mknod -m 0666 $NEWROOT/dev/ptmx 	c 5 2
#chown root:tty $NEWROOT/dev/{console,ptmx,tty}

mknod -m 0666 $NEWROOT/dev/null 	c 1 3
mknod -m 0666 $NEWROOT/dev/zero 	c 1 5
mknod -m 0444 $NEWROOT/dev/random 	c 1 8
mknod -m 0444 $NEWROOT/dev/urandom 	c 1 9

echo "/dev/sda1 / auto defaults 1 1" > $NEWROOT/etc/fstab


