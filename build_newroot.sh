#!/bin/bash
NEWROOT="newroot"
rm -rf $NEWROOT

echo "creating core GNU/Linux system"
set -e

mkdir $NEWROOT
mkdir $NEWROOT/{proc,sys,tmp}
cp -rfv /{bin,boot,opt,etc,include,lib,libexec,man,sbin,share,var,usr} $NEWROOT
#TODO scrub system strings
#TODO archive / checksums


