#!/bin/bash
# create fake root filesystem in home directory
# each directory marked with `home rwxR` gets mounted as that
# directory in pod's root. use with -DPODROOT_HOME_OVERRIDE jettison hack
rm -rfv $HOME/{bin,boot,opt,etc,include,lib,libexec,man,sbin,share,var,usr}
mkdir -v $HOME/{bin,boot,opt,etc,include,lib,libexec,man,sbin,share,var,usr}
mkdir -v $HOME/var/log
mkdir -v $HOME/var/tmp
chmod 01777 $HOME/var/tmp
mkdir -v $HOME/usr/{bin,sbin,lib,include,share,local}
mkdir -v $HOME/usr/local/{bin,sbin,lib,include,share}

echo "creating directories, and symlinks"

#create 64bit /lib64 /usr/lib64 /usr/local/lib64 here if you need

echo "creating expected symlinks"
ln -sv /bin/bash $HOME/bin/sh
ln -sv /podhome/toolchain/bin/{bash,cat,echo,pwd} $HOME/bin
#ln -sv $TOOLCHAIN/bin/perl /usr/bin
ln -sv /podhome/toolchain/lib/libgcc_s.so{,.1} $HOME/usr/lib
ln -sv /podhome/toolchain/lib/libstdc++.so{,.6} $HOME/usr/lib

# stdc++ static
# sed "s|/podhome/toolchain|/usr|" $HOME/toolchain/lib/libstdc++.la > $HOME/toolchain/lib/libstdc++.la

# some programs expect /etc/mtab
ln -sv /podhome/toolchain/proc/self/mounts $HOME/etc/mtab
# this linker doesn't exist yet
ln -sv /podhome/toolchain/lib/ld-linux.so.2 $HOME/lib



#passwd and group files
echo "creating /etc/passwd"
#create some users
echo "root:x:0:0:root:/root:/bin/bash
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false"> $HOME/etc/passwd

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
users:x:999:"> $HOME/etc/group







