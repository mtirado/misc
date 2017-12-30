#!/bin/bash
# (C) 2017 GPLv3+ (GNU gpl version 3 or later)
# Derived from Linux From Scratch
# For use with jettison PODROOT_HOME_OVERRIDE compile-time option

# the only thing needed is system-pkgs in home directory shared with pod
# this will create a self contained toolchain dir, to be used until
# pod root is populated with cross compiled binaries.
set +h
set -e
umask 022

# XXX note: build environment symlinks glibc linker in sysroot, and
# later on in phase2 toolchain linker gets modified, if rebuilding
# make sure everything is in a clean default state!

TOOLCHAIN_ARCH="x86"
case "$TOOLCHAIN_ARCH" in
	x86)
		export TARGET=i686-xbuild-linux-gnu
	;;
	x86_64)
		export TARGET=x86_64-xbuild-linux-gnu
		echo "todo"
		exit -1
		# multilib?
		#mkdir -vp /podhome/toolchain/lib && ln -sv lib /podhome/toolchain/lib64
		#mkdir -vp /podhome/toolchain/lib && ln -sv lib /tools/lib64
	;;
	x32)
		# i'm not sure on that gnux32 at the end
		export TARGET=x86_64-xbuild-linux-gnux32
		echo "todo"
		exit -1
		#mkdir -vp /podhome/toolchain/lib && ln -sv lib /tools/lib64
	;;
	armv7)
		export TARGET=arm-xbuild-linux-gnueabihf
		echo "todo"
		# also check for hardfloat option
		exit -1
	;;
	*)
		exit -1
	;;
esac

GLIBC_KERNELVERSION=3.10

JOBS="-j2"

TOPDIR="$(pwd)"
PKGDIR="$(pwd)/system-pkgs"
SRCDIR="$(pwd)/toolchain-src"
TOOLS="/podhome/toolchain"
SYSROOT="/podhome/sysroot"

export PATH="$TOOLS/bin:$TOOLS/usr/bin:/bin:/usr/bin"
export LC_ALL=C

mkdir -p $TOOLS
mkdir -p $SRCDIR

BINUTILS=binutils-2.29
GMP=gmp-6.1.2
MPFR=mpfr-3.1.6
MPC=mpc-1.0.3
GCC_VERSION=7.2.0
GCC=gcc-$GCC_VERSION
LINUX=linux-4.14.8
GLIBC=glibc-2.26
BASH=bash-4.4
COREUTILS=coreutils-8.28
DIFFUTILS=diffutils-3.6
SED=sed-4.4
GAWK=gawk-4.1.4
GREP=grep-3.0
M4=m4-1.4.18
FINDUTILS=findutils-4.6.0
GZIP=gzip-1.8
PATCH=patch-2.7.5
MAKE=make-4.2.1
TAR=tar-1.30
UTIL_LINUX=util-linux-2.31
ZLIB=zlib-1.2.11
XZ=xz-5.2.3
BZIP2=bzip2-1.0.6
FILE=file-5.30


#TEXINFO=texinfo-6.1
#PERL_VERSION=5.24.0
#PERL=perl-$PERL_VERSION
#GETTEXT=gettext-0.19.7
# tests
#TCL=tcl-8.6.2
#EXPECT=expect.5.45
#DEJAGNU=dejagnu-1.5.1
#CHECK=check-0.9.14

# arg 1: filepath, arg 2: destination directory, arg 3: additional arguments
decompress()
{
	if [ -z "$1" ]; then
		echo "decompress missing file parameter"
		exit -1
	fi
	if [ -z "$2" ]; then
		echo "decompress missing destination directory"
		exit -1
	fi
	DEST=$2
	OPTS=""
	if [ -n "$3" ]; then
		OPTS="$3"
	fi

	if [ -e $PKGDIR/$1.tar.xz ]; then
		PKG="$1.tar.xz"
	elif [ -e $PKGDIR/$1.tar.gz ]; then
		PKG="$1.tar.gz"
	elif [ -e $PKGDIR/$1.tar.bz2 ]; then
		PKG="$1.tar.bz2"
	else
		echo "archive not found or not recognized: $PKG"
		exit -1
	fi
	echo "decompressing $PKG"
	tar $OPTS -xf $PKGDIR/$PKG -C $DEST
}


BUILD_START=$(date)
echo "Build started at $BUILD_START"


#disable stuff?
#if [ 5 -eq 7 ]; then
#fi

echo "###############################################################"
echo "BINUTILS - PASS 1"
echo "###############################################################"
decompress $BINUTILS $SRCDIR
mkdir $SRCDIR/$BINUTILS-build
cd $SRCDIR/$BINUTILS-build

../$BINUTILS/configure			\
	--target=$TARGET		\
	--prefix=$TOOLS			\
	--with-lib-path=$TOOLS/lib	\
	--with-sysroot=$SYSROOT		\
	--disable-nls			\
	--disable-werror
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build



echo "###############################################################"
echo "GCC - PASS 1"
echo "###############################################################"
decompress $GCC $SRCDIR
#move math code into expected locations
mkdir -v $SRCDIR/$GCC/mpfr
decompress $MPFR $SRCDIR/$GCC/mpfr --strip-components=1
mkdir -v $SRCDIR/$GCC/gmp
decompress $GMP $SRCDIR/$GCC/gmp --strip-components=1
mkdir -v $SRCDIR/$GCC/mpc
decompress $MPC $SRCDIR/$GCC/mpc --strip-components=1

cd $SRCDIR/$GCC
echo "adjusting paths."
for file in \
    $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/podhome/toolchain&@g' \
        -e 's@/usr@/podhome/toolchain@g' $file.orig > $file
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/podhome/toolchain/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
    echo $file
done



mkdir $SRCDIR/$GCC-build
cd $SRCDIR/$GCC-build

../$GCC/configure					\
    --target=$TARGET					\
    --prefix=$TOOLS					\
    --with-sysroot=$SYSROOT                     	\
    --with-newlib					\
    --without-headers					\
    --with-local-prefix=$TOOLS				\
    --with-native-system-header-dir=$TOOLS/include	\
    --disable-nls					\
    --disable-shared					\
    --disable-multilib					\
    --disable-decimal-float				\
    --disable-threads					\
    --disable-libatomic					\
    --disable-libgomp					\
    --disable-libmpx					\
    --disable-libquadmath				\
    --disable-libssp					\
    --disable-libvtv					\
    --disable-libstdcxx					\
    --disable-lto					\
    --enable-languages=c,c++

# --disable-libcilkrts                                	\
# --disable-libsanitizer                              	\
# --disable-libitm                                    	\
# --with-glibc-version=2.11				\
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/$GCC-build


echo "###############################################################"
echo "LINUX API HEADER"
echo "###############################################################"
echo "installing linux headers"
decompress $LINUX $SRCDIR
cd $SRCDIR/$LINUX
make mrproper
make INSTALL_HDR_PATH=dest headers_install
mkdir -pv $TOOLS/include
cp -rfv dest/include/* $TOOLS/include

cd $TOPDIR
rm -rf $SRCDIR/$LINUX



echo "###############################################################"
echo "GLIBC"
echo "###############################################################"
decompress $GLIBC $SRCDIR
mkdir $SRCDIR/$GLIBC-build

cd $SRCDIR/$GLIBC

cd $SRCDIR/$GLIBC-build

../$GLIBC/configure					\
	--prefix=$TOOLS					\
	--host=$TARGET					\
	--target=$TARGET				\
	--build=$("../$GLIBC/scripts/config.guess")	\
	--disable-profile				\
	--with-headers=$TOOLS/include			\
	--enable-kernel=$GLIBC_KERNELVERSION
# if configure fails older versions might need these options
#	libc_cv_ctors_header=yes			\
#	libc_cv_forced_unwind=yes			\
#	libc_cv_c_cleanup=yes


make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GLIBC
rm -rf $SRCDIR/$GLIBC-build


# hacks on top of hacks!
# is this the right way to actually do this? seems to work out ok.
mkdir -p $SYSROOT/$TOOLS
rm -rf $SYSROOT/$TOOLS
ln -sf $TOOLS $SYSROOT/$TOOLS



echo "###############################################################"
echo "LIBSTDC++"
echo "###############################################################"
decompress $GCC $SRCDIR
mkdir $SRCDIR/libstdc++-build
cd $SRCDIR/libstdc++-build

../$GCC/libstdc++-v3/configure	\
    --host=$TARGET		\
    --prefix=$TOOLS		\
    --disable-multilib		\
    --disable-nls		\
    --disable-libstdcxx-threads	\
    --disable-libstdcxx-pch	\
    --disable-shared            \
    --with-gxx-include-dir=$TOOLS/$TARGET/include/c++/$GCC_VERSION
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/libstdc++-build



echo "###############################################################"
echo "BINUTILS - PASS 2"
echo "###############################################################"

echo "binutils pass 2"
decompress $BINUTILS $SRCDIR
mkdir $SRCDIR/$BINUTILS-build
cd $SRCDIR/$BINUTILS-build


CCP="$TARGET-cpp"               \
CC="$TARGET-gcc"                \
CXX="$TARGET-g++"               \
AR="$TARGET-ar"                 \
AS="$TARGET-as"                 \
RANLIB="$TARGET-ranlib"         \
../$BINUTILS/configure		\
    --prefix=$TOOLS        	\
    --with-sysroot		\
    --disable-nls               \
    --disable-werror

make $JOBS
#make $JOBS -k check
#echo "press the any key"
#read -n 1 -s anykey

make install

# prepare a new linker for re-adjusting phase later on.
make -C ld clean
make -C ld LIB_PATH=/lib:/usr/lib
cp -vf ld/ld-new $TOOLS/bin

cd $TOPDIR

rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build



# if this fails you might want to compeltely restart.
# the environment may not have been fully clean
mkdir "./interp-test"
cd "./interp-test"

echo -e "\n\n\n**************************************************\n\
    running readelf binary test\nconfirm that this is the toolchain dynamic linker\n\
    eg /podhome/toolchain/lib/ld-linux.so.2\n\
    **************************************************"
echo 'int main(int argc, char *argv[]){return 0;}' > dummy.c
echo "CALLING GCC"
echo "PATH($PATH)"
$TARGET-gcc  -v dummy.c
echo "BUILT"
readelf -l a.out
echo "press the any key"
#read -n 1 -s anykey
rm -rf a.out
rm -rf dummy.c

cd $TOPDIR


echo "###############################################################"
echo "GCC - PASS 2"
echo "###############################################################"
decompress $GCC $SRCDIR
#move math code into expected locations
mkdir -v $SRCDIR/$GCC/mpfr
decompress $MPFR $SRCDIR/$GCC/mpfr --strip-components=1
mkdir -v $SRCDIR/$GCC/gmp
decompress $GMP $SRCDIR/$GCC/gmp --strip-components=1
mkdir -v $SRCDIR/$GCC/mpc
decompress $MPC $SRCDIR/$GCC/mpc --strip-components=1

echo "fixing limits"
cd $SRCDIR/$GCC
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($TARGET-gcc -print-libgcc-file-name)`/include-fixed/limits.h

#do some voodoo to change hardcoded linker to new tools linker
echo "modifying paths."
for file in \
    $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/podhome/toolchain&@g' \
        -e 's@/usr@/podhome/toolchain@g' $file.orig > $file
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/podhome/toolchain/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
    #echo $file
done
#uncomment to make sure paths were modified
#echo "done.  press the any key"
#read -n 1 -s anykey

cd $SRCDIR/$GCC
mkdir $SRCDIR/$GCC-build
cd $SRCDIR/$GCC-build

#set cross compiler
#build it normally with the toolchain we just built
CCP="$TARGET-cpp"                                       \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
../$GCC/configure                                       \
    --prefix=$TOOLS                                     \
    --with-local-prefix=$TOOLS				\
    --with-native-system-header-dir=$TOOLS/include      \
    --disable-libstdcxx-pch                             \
    --disable-multilib                                  \
    --disable-bootstrap                                 \
    --disable-libgomp                                   \
    --disable-lto					\
    --enable-languages=c,c++
# note: c++ is required to boot strap gcc >= 4.8

make $JOBS
#make $JOBS -k check

#echo "press the any key"
#read -n 1 -s anykey

make install

#symlink for cc
ln -sv gcc $TOOLS/bin/cc


#read the elf and verify correctness.
echo -e "\n\n\n**************************************************\n\
    running readelf binary test\nconfirm that this is the toolchain dynamic linker\n\
    eg /podhome/toolchain/lib/ld-linux.so.2\n\
**************************************************"
echo 'int main(int argc, char *argv[]){return 0;}' > dummy.c
cc dummy.c
readelf -l a.out
echo "press the any key"
#read -n 1 -s anykey

rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/$GCC-build



echo "###############################################################"
echo "BASH"
echo "###############################################################"
decompress $BASH $SRCDIR

cd $SRCDIR/$BASH
./configure			\
    --prefix=$TOOLS		\
    --without-bash-malloc

make $JOBS
make install
ln -sv bash $TOOLS/bin/sh

cd $TOPDIR
rm -rf $SRCDIR/$BASH
rm -rf $SRCDIR/$BASH-build


echo "###############################################################"
echo "BZIP2"
echo "###############################################################"
decompress $BZIP2 $SRCDIR

cd $SRCDIR/$BZIP2
make $JOBS
make PREFIX=$TOOLS install

cd $TOPDIR
rm -rf $SRCDIR/$BZIP2
rm -rf $SRCDIR/$BZIP2-build



echo "###############################################################"
echo "COREUTILS"
echo "###############################################################"
decompress $COREUTILS $SRCDIR

cd $SRCDIR/$COREUTILS

./configure                                             \
    --prefix=$TOOLS                                     \
    --enable-install-program=hostname

make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$COREUTILS
rm -rf $SRCDIR/$COREUTILS-build


echo "###############################################################"
echo "DIFFUTILS"
echo "###############################################################"
decompress $DIFFUTILS $SRCDIR

cd $SRCDIR/$DIFFUTILS
./configure --prefix=$TOOLS

make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$DIFFUTILS
rm -rf $SRCDIR/$DIFFUTILS-build

echo "###############################################################"
echo "FILE"
echo "###############################################################"
decompress $FILE $SRCDIR

cd $SRCDIR/$FILE
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$FILE
rm -rf $SRCDIR/$FILE-build

echo "###############################################################"
echo "FINDUTILS"
echo "###############################################################"
decompress $FINDUTILS $SRCDIR

cd $SRCDIR/$FINDUTILS
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$FINDUTILS
rm -rf $SRCDIR/$FINDUTILS-build


echo "###############################################################"
echo "GAWK"
echo "###############################################################"
decompress $GAWK $SRCDIR

cd $SRCDIR/$GAWK
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GAWK
rm -rf $SRCDIR/$GAWK-build


echo "###############################################################"
echo "GREP"
echo "###############################################################"
decompress $GREP $SRCDIR

cd $SRCDIR/$GREP
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GREP
rm -rf $SRCDIR/$GREP-build



echo "###############################################################"
echo "GZIP"
echo "###############################################################"
decompress $GZIP $SRCDIR

cd $SRCDIR/$GZIP
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$GZIP
rm -rf $SRCDIR/$GZIP-build



echo "###############################################################"
echo "M4"
echo "###############################################################"
decompress $M4 $SRCDIR

cd $SRCDIR/$M4
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$M4
rm -rf $SRCDIR/$M4-build



echo "###############################################################"
echo "MAKE"
echo "###############################################################"
decompress $MAKE $SRCDIR

cd $SRCDIR/$MAKE
./configure             \
    --prefix=$TOOLS    \
    --without-guile
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$MAKE
rm -rf $SRCDIR/$MAKE-build


echo "###############################################################"
echo "PATCH"
echo "###############################################################"
decompress $PATCH $SRCDIR

cd $SRCDIR/$PATCH
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$PATCH
rm -rf $SRCDIR/$PATCH-build



echo "###############################################################"
echo "TAR"
echo "###############################################################"
decompress $TAR $SRCDIR

cd $SRCDIR/$TAR
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$TAR
rm -rf $SRCDIR/$TAR-build


echo "###############################################################"
echo "XZ"
echo "###############################################################"
decompress $XZ $SRCDIR

cd $SRCDIR/$XZ
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$XZ
rm -rf $SRCDIR/$XZ-build


echo "###############################################################"
echo "SED"
echo "###############################################################"
decompress $SED $SRCDIR

cd $SRCDIR/$SED
./configure --prefix=$TOOLS
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$SED
rm -rf $SRCDIR/$SED-build

echo "###############################################################"
echo "writing PODROOT_HOME_OVERRIDE phase2.pod config"
echo "###############################################################"
echo "
newnet none
home_exec
tmp_exec

file rwd /dev/null
file rwd /dev/zero

home r   /system-pkgs
home rwx /toolchain

# links home directory as a pod root directory
home rwxR /bin
home rwxR /etc
home rwxR /include
home rwxR /lib
home rwxR /libexec
home rwxR /man
home rwxR /sbin
home rwxR /share
home rwxR /var
home rwxR /usr
" > "$TOOLS/phase2.pod"

# FIXME this could probably be removed sooner.
set +e
echo "removing cross compiler"
find . -iname "*$TARGET*" -exec rm -rfv ./{} \;
set -e

echo "strip debug info from binaries? (faster compression time)  y / n ]"
ack="y"
#read -n 1 -s ack
if [ "$ack" == "y" ] || [ "$ack" == "Y" ]; then
	cd $TOOLS
	find -type f -exec $TOOLS/bin/strip --strip-debug {} \;
	cd $TOOLS/bin
	find -type f -exec $TOOLS/bin/strip --strip-unneeded {} \;
	cd $TOOLS/sbin
	find -type f -exec $TOOLS/bin/strip --strip-unneeded {} \;

	cd $TOPDIR
fi


echo "strip extras (documentation, share data) y / n ]"
ack="y"
#read -n 1 -s ack
if [ "$ack" == "y" ] || [ "$ack" == "Y" ]; then
	cd $TOOLS
	rm -rfv $TOOLS/share/{info,man,doc}
	cd $TOPDIR
fi

cd $TOPDIR
echo "compressing toolchain (very slow if not stripped)"
$TOOLS/bin/tar -cJf toolchain.tar.xz toolchain

echo "-------------------------------------------------------"
echo "---------------- checksum generation ------------------"
echo "-------------------------------------------------------"
echo ""
echo "                          MD5"
$TOOLS/bin/md5sum toolchain.tar.xz
echo ""
echo "                          SHA1"
$TOOLS/bin/sha1sum toolchain.tar.xz
echo ""
echo "                         SHA256"
$TOOLS/bin/sha256sum toolchain.tar.xz
echo ""
echo "                         SHA384"
$TOOLS/bin/sha384sum toolchain.tar.xz
echo ""
echo "                         SHA512"
$TOOLS/bin/sha512sum toolchain.tar.xz
echo ""
echo "-------------------------------------------------------"
echo "  write these down and store somewhere non-digital :S "
echo "-------------------------------------------------------"

BUILD_END=$(date)
echo ""
echo ""
echo "Build was started at $BUILD_START"
echo "Completed at $BUILD_END"
echo ""
echo "Toolchain is ready for use"

echo "cd /home/user"
echo "tar -xf toolchain.tar.xz"
echo "./prepare_newroot.sh"
echo "jettison_autopod /bin/bash /home/user/toolchain/phase2.pod"
echo "export PATH=/bin:/usr/bin:/podhome/toolchain/bin"
echo "./build_system.sh"
