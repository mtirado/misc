#!/bin/bash
# create fake root filesystem in home directory
# each directory marked with `home rwxR` gets mounted as that
# directory in pod's root. use with -DPODROOT_HOME_OVERRIDE jettison hack

NEWROOT="$HOME/newroot"
rm -rfv $HOME/{bin,boot,opt,etc,include,lib,libexec,sbin,var,usr}
mkdir -vp $NEWROOT/{dev,sys,proc,bin,boot,opt,etc,include,lib,libexec,sbin,var,usr}
chmod -v 0750 $NEWROOT/boot
mkdir -vp $NEWROOT/var/log
chmod -v 0750 $NEWROOT/var/log
mkdir -vp $NEWROOT/tmp
mkdir -vp $NEWROOT/var/tmp
chmod -v 01777 $NEWROOT/tmp
chmod -v 01777 $NEWROOT/var/tmp
mkdir -vp $NEWROOT/usr/{bin,sbin,lib,include,share,local}
mkdir -vp $NEWROOT/usr/local/{bin,sbin,lib,include,share}
chmod -v 0750 $NEWROOT/sbin
chmod -v 0750 $NEWROOT/usr/sbin
chmod -v 0750 $NEWROOT/usr/local/sbin
# setup PODROOT_HOME directories
ln -sv $NEWROOT/bin     $HOME/bin
ln -sv $NEWROOT/boot    $HOME/boot
ln -sv $NEWROOT/etc     $HOME/etc
ln -sv $NEWROOT/include $HOME/include
ln -sv $NEWROOT/lib     $HOME/lib
ln -sv $NEWROOT/libexec $HOME/libexec
ln -sv $NEWROOT/sbin    $HOME/sbin
ln -sv $NEWROOT/var     $HOME/var
ln -sv $NEWROOT/usr     $HOME/usr


#create 64bit /lib64 /usr/lib64 /usr/local/lib64 here if you need
echo ""
echo "creating expected symlinks."
echo "if they already exist, toolchain has been built"
ln -sv /bin/bash $NEWROOT/bin/sh
ln -sv /podhome/toolchain/bin/{bash,cat,echo,pwd} $NEWROOT/bin/
#ln -sv $TOOLCHAIN/bin/perl /usr/bin
ln -sv /podhome/toolchain/lib/libgcc_s.so{,.1} $NEWROOT/usr/lib/
ln -sv /podhome/toolchain/lib/libstdc++.so{,.6} $NEWROOT/usr/lib/

# stdc++ static
# sed "s|/podhome/toolchain|/usr|" $HOME/toolchain/lib/libstdc++.la > $NEWROOT/toolchain/lib/libstdc++.la

# /etc/mtab
ln -svf /proc/self/mounts $NEWROOT/etc/mtab
# this linker doesn't exist if we haven't build core system yet
ln -sv /podhome/toolchain/lib/ld-linux.so.2 $NEWROOT/lib

#default users
mkdir -vp $NEWROOT/root
chmod -v 0700  $NEWROOT/root
mkdir -vp $NEWROOT/home/user
chmod -v 0700  $NEWROOT/home/user
echo 'exec fluxbox' > $NEWROOT/home/user/.xinitrc

echo "creating /etc/passwd"
echo "root:x:0:0:root:/root:/bin/bash
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
user:x:1000:1000:Default User:/home/user:/bin/bash"> $NEWROOT/etc/passwd

echo "creating /etc/group"
echo "root:x:0:
tty:x:5:
audio:x:11:
video:x:12:
usb:x:14:
cdrom:x:15:
adm:x:16:
mail:x:34
nogroup:x:99:
users:x:100:"> $NEWROOT/etc/group

echo "creating /etc/fstab"
echo "# default fstab
/dev/sda1     /          ext4   defaults  1 1
proc          /proc      proc   defaults  0 0" > $NEWROOT/etc/fstab

# this is qemu's default
DNSSERV=10.0.2.3
echo "creating default DNS server entry: $DNSSERV"
echo "nameserver $DNSSERV" > $NEWROOT/etc/resolv.conf

echo "creating nsswitch.conf:"
echo "passwd:		compat
group:		compat
hosts:		files dns
networks:	files
services:	files
protocols:	files
rpc:		files
ethers:		files
netmasks:	files
netgroup:	files
bootparams:	files
automount:	files
aliases:	files"> $NEWROOT/etc/nsswitch.conf
