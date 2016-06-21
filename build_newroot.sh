#!/bin/bash
echo "creating core GNU/Linux system"

rm -rf newroot
set -e
mkdir newroot
cp -rfv /{bin,boot,opt,etc,include,lib,libexec,man,sbin,share,var,usr} newroot

#TODO scrub system strings
#TODO archive / checksums


