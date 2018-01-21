#!/bin/sh
#
# FIXME default fstab asumes ext4
#
set -e

export MNT_MEDIA="/mnt/install-media"
export FLOCK_USR="$MNT_MEDIA/packages/flock-usr"
export FLOCK_ROOT="$MNT_MEDIA/packages/flock-root"
export MNT_NEWROOT="/mnt/newroot"

export PATH="$PATH:$MNT_MEDIA/packages"
export PKGTMP="$MNT_NEWROOT/tmp/pkgdist"
export PKGINSTALL="$MNT_NEWROOT/"

OVERRIDE_CONTENTS=""

usage ()
{
	echo ""
	echo "usage: dist_install.sh <install-media> <newroot> [package-dir]"
	echo "e.g: dist_install.sh /dev/sr0 /dev/sda1"
	echo "package-dir is optional, for overriding stock iso package configuration"
	echo ""
	exit -1
}

if [[ "$1" != /dev/* ]]; then
	usage
fi
if [[ "$2" != /dev/* ]]; then
	usage
fi

DEV_MEDIA="$1"
DEV_NEWROOT="$2"
if [ "$3" != "" ]; then
	OVERRIDE_CONTENTS="$3"
	if [ ! -d "$OVERRIDE_CONTENTS" ]; then
		echo "package-dir does not exist: $OVERRIDE_CONTENTS"
		exit -1
	fi
fi

mkdir -p "$MNT_MEDIA"
mkdir -p "$MNT_NEWROOT"
mkdir -p "$PKGINSTALL"
mkdir -p "$PKGINSTALL/usr"
mount $DEV_MEDIA $MNT_MEDIA
mount $DEV_NEWROOT $MNT_NEWROOT

mkdir -p "$PKGTMP"
cd "$PKGTMP"

echo "installing root packages"
sleep 1
if [ "$OVERRIDE_CONTENTS" != "" ]; then
	PKGOVERWRITE=1 pkg-deliver.sh $FLOCK_ROOT "$OVERRIDE_CONTENTS/flock-root"
else
	PKGOVERWRITE=1 pkg-deliver.sh $FLOCK_ROOT
fi

echo "installing usr packages"
sleep 1
if [ "$OVERRIDE_CONTENTS" != "" ]; then
	PKGOVERWRITE=1 pkg-deliver.sh $FLOCK_USR "$OVERRIDE_CONTENTS/flock-usr"
else
	PKGOVERWRITE=1 pkg-deliver.sh $FLOCK_USR
fi

echo "removing temporary files"
rm -fr "$MNT_NEWROOT/tmp/*"
chown 0:0 -R $MNT_NEWROOT
sync
echo "unmounting $MNT_MEDIA"
umount $MNT_MEDIA

echo "packages installed."
sleep 1
echo "creating file structure"
sleep 1

set +e

# expected file structure
mkdir -vp $MNT_NEWROOT/{dev,sys,proc,bin,boot,opt,etc,include,lib,libexec,sbin,var,usr}
chmod -v 0750 $MNT_NEWROOT/boot
mkdir -vp $MNT_NEWROOT/var/log
chmod -v 0750 $MNT_NEWROOT/var/log
mkdir -vp $MNT_NEWROOT/tmp
mkdir -vp $MNT_NEWROOT/var/tmp
chmod -v 01777 $MNT_NEWROOT/tmp
chmod -v 01777 $MNT_NEWROOT/var/tmp
mkdir -vp $MNT_NEWROOT/usr/{bin,sbin,lib,include,share,local}
mkdir -vp $MNT_NEWROOT/usr/local/{bin,sbin,lib,include,share}
chmod -v 0750 $MNT_NEWROOT/sbin
chmod -v 0750 $MNT_NEWROOT/usr/sbin
chmod -v 0750 $MNT_NEWROOT/usr/local/sbin

#expected symlinks
ln -s /bin/bash $MNT_NEWROOT/bin/sh
ln -s /proc/mounts $MNT_NEWROOT/etc/mtab

#default users
mkdir -vp $MNT_NEWROOT/root
chmod -v 0700  $MNT_NEWROOT/root
mkdir -vp $MNT_NEWROOT/home/user
chmod -v 0700  $MNT_NEWROOT/home/user

echo "creating /etc/passwd"
echo "root:x:0:0:root:/root:/bin/bash
nobody:x:99:9:Unprivileged User:/dev/null:/bin/false
user:x:1000:100:Default User:/home/user:/bin/bash"> $MNT_NEWROOT/etc/passwd

echo "creating /etc/group"
echo "root:x:0:
tty:x:5:
audio:x:11:
video:x:12:
usb:x:14:
cdrom:x:15:
adm:x:16:
mail:x:34
nogroup:x:9:
users:x:100:"> $MNT_NEWROOT/etc/group


#TODO root filesystem as an input parameter
echo "creating /etc/fstab"
echo "# default fstab
$DEV_NEWROOT / ext4 defaults  1 1
proc /proc proc defaults 0 0" > $MNT_NEWROOT/etc/fstab


# this is qemu's default,
DNSSERV=10.0.2.3
echo "creating default DNS server entry: $DNSSERV"
echo "nameserver $DNSSERV" > $MNT_NEWROOT/etc/resolv.conf

echo "creating nsswitch.conf:"
echo "passwd:		files
group:		files
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
aliases:	files"> $MNT_NEWROOT/etc/nsswitch.conf

set -e

sleep 1
echo ""
echo "almost finished, now configure as needed and install boot loader."
echo "see the configure dist section of INSTALL file"
echo ""
echo ""

cat /INSTALL

