#!/bin/bash
# (C) 2017 GPLv3+ (GNU gpl version 3 or later)
# Derived from Linux From Scratch
# For use with jettison PODROOT_HOME_OVERRIDE compile-time option

# the only thing we need is system-pkgs in home directory shared with pod

set +h
set -e
umask 022

# XXX build environment may need to have
# /podhome/newsystem/podhome/toolchain symlinked to /podhome/toolchain
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

JOBS='-j2'

TOPDIR="$(pwd)"
PKGDIR="$(pwd)/system-pkgs"
SRCDIR="$(pwd)/toolchain-src"
PREFIX="/podhome/toolchain"
FAKEROOT="/podhome/newsystem"

export PATH="$PREFIX/bin:$PREFIX/usr/bin:/bin:/usr/bin"
export LC_ALL=C

mkdir -p $PREFIX
mkdir -p $SRCDIR

BINUTILS=binutils-2.28
GMP=gmp-6.1.2
MPFR=mpfr-3.1.5
MPC=mpc-1.0.3
GCC_VERSION=7.1.0
GCC=gcc-$GCC_VERSION
LINUX=linux-4.9.29
GLIBC=glibc-2.25
BASH=bash-4.4
COREUTILS=coreutils-8.27
DIFFUTILS=diffutils-3.6
SED=sed-4.4
GAWK=gawk-4.1.4
GREP=grep-3.0
M4=m4-1.4.18
FINDUTILS=findutils-4.6.0
GZIP=gzip-1.8
PATCH=patch-2.7.5
MAKE=make-4.2.1
TAR=tar-1.29
UTIL_LINUX=util-linux-2.29.2
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
#BUILD_START=$(date)
echo "###############################################################"
echo "BINUTILS - PASS 1"
echo "###############################################################"
decompress $BINUTILS $SRCDIR
mkdir $SRCDIR/$BINUTILS-build
cd $SRCDIR/$BINUTILS-build

../$BINUTILS/configure          \
    --target=$TARGET            \
    --prefix=$PREFIX            \
    --with-lib-path=$PREFIX/lib \
    --with-sysroot=$FAKEROOT    \
    --disable-nls               \
    --disable-werror
make $JOBS
make install

cd $TOPDIR
rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build





echo "###############################################################"
echo "LINUX API HEADER"
echo "###############################################################"
echo "installing linux headers"
decompress $LINUX $SRCDIR
cd $SRCDIR/$LINUX
make mrproper
make INSTALL_HDR_PATH=dest headers_install
mkdir -pv $PREFIX/include
cp -rfv dest/include/* $PREFIX/include
cd $TOPDIR
rm -rf $SRCDIR/$LINUX



# FIXME this is sloppy, all it really needs i think are the crt0.o, etc files
echo "###############################################################"
echo "GLIBC"
echo "###############################################################"
decompress $GLIBC $SRCDIR
mkdir $SRCDIR/$GLIBC-build

cd $SRCDIR/$GLIBC

#patch -Np1 -i $PKGDIR/glibc-2.23-upstream_fixes-1.patch

cd $SRCDIR/$GLIBC-build


../$GLIBC/configure                             \
    --prefix=$PREFIX                            \
    --host=$TARGET                              \
    --build=$("../$GLIBC/scripts/config.guess") \
    --disable-profile                           \
    --with-headers=$PREFIX/include              \
    --enable-kernel=$GLIBC_KERNELVERSION        \
    libc_cv_forced_unwind=yes                   \
    libc_cv_c_cleanup=yes
#    libc_cv_ctors_header=yes                    \
#these libc_cv flags are to disable tests for features
#that will fail untill second pass binutils is completed


make $JOBS
make install

mkdir -p $FAKEROOT/$PREFIX
rm -rf $FAKEROOT/$PREFIX
ln -sf $PREFIX $FAKEROOT/$PREFIX

cd $TOPDIR
rm -rf $SRCDIR/$GLIBC
rm -rf $SRCDIR/$GLIBC-build




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

../$GCC/configure                                               \
    --target=$TARGET                                            \
    --prefix=$PREFIX                                    	\
    --with-glibc-version=2.11					\
    --with-sysroot=$FAKEROOT                                    \
    --with-newlib                                       	\
    --with-native-system-header-dir=$PREFIX/include		\
    --with-local-prefix=$PREFIX                         	\
    --without-headers                                   	\
    --disable-nls                                       	\
    --disable-shared                                    	\
    --disable-multilib                                  	\
    --disable-decimal-float                             	\
    --disable-threads                                   	\
    --disable-libatomic                                 	\
    --disable-libgomp                                   	\
    --disable-libquadmath                               	\
    --disable-libssp						\
    --disable-libvtv                                    	\
    --disable-libstdcxx                                 	\
    --disable-lto						\
    --enable-languages=c,c++

   # --disable-libcilkrts                                	\
   # --disable-libsanitizer                              	\
   #--disable-libitm                                    	\
make $JOBS
make install

cd $TOPDIR

rm -rf $SRCDIR/$GCC
rm -rf $SRCDIR/$GCC-build






decompress $GCC $SRCDIR
echo "building libstdc++-v3"
echo "###############################################################"
echo "LIBSTDC++"
echo "###############################################################"
mkdir $SRCDIR/libstdc++-build
cd $SRCDIR/libstdc++-build

#CCP=$TARGET-ccp                 \
#CC=$TARGET-gcc			\
#AR=$TARGET-ar			\
#AS=$TARGET-as			\
#RANLIB=$TARGET-ranlib		\
../$GCC/libstdc++-v3/configure  \
    --host=$TARGET              \
    --prefix=$PREFIX            \
    --disable-multilib          \
    --disable-nls               \
    --disable-libstdcxx-threads \
    --disable-libstdcxx-pch     \
    --with-gxx-include-dir=$PREFIX/$TARGET/include/c++/$GCC_VERSION
#    --disable-shared            \
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

CC=$TARGET-gcc			\
AR=$TARGET-ar			\
RANLIB=$TARGET-ranlib		\
../$BINUTILS/configure		\
    --prefix=$PREFIX            \
    --with-sysroot		\
    --with-lib-path=$PREFIX/lib \
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
cp -vf ld/ld-new $PREFIX/bin

cd $TOPDIR

rm -rf $SRCDIR/$BINUTILS
rm -rf $SRCDIR/$BINUTILS-build

echo "###############################################################"
echo "GLIBC"
echo "###############################################################"
decompress $GLIBC $SRCDIR
mkdir $SRCDIR/$GLIBC-build

cd $SRCDIR/$GLIBC

#patch -Np1 -i $PKGDIR/glibc-2.23-upstream_fixes-1.patch

cd $SRCDIR/$GLIBC-build


../$GLIBC/configure                             \
    --prefix=$PREFIX                            \
    --host=$TARGET                              \
    --build=$("../$GLIBC/scripts/config.guess") \
    --disable-profile                           \
    --with-headers=$PREFIX/include              \
    --enable-kernel=$GLIBC_KERNELVERSION        \
    libc_cv_forced_unwind=yes                   \
    libc_cv_c_cleanup=yes
#    libc_cv_ctors_header=yes                    \
#these libc_cv flags are to disable tests for features
#that will fail untill second pass binutils is completed


make $JOBS
make install


# hacks on top of hacks!
mkdir -p $FAKEROOT/$PREFIX
rm -rf $FAKEROOT/$PREFIX
ln -sf $PREFIX $FAKEROOT/$PREFIX


cd $SRCDIR/$GLIBC-build

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



rm -rf $SRCDIR/$GLIBC
rm -rf $SRCDIR/$GLIBC-build



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
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
RANLIB="$TARGET-ranlib"                                 \
../$GCC/configure                                       \
    --prefix=$PREFIX                                    \
    --with-local-prefix=$PREFIX                         \
    --with-native-system-header-dir=$PREFIX/include     \
    --disable-libstdcxx-pch                             \
    --disable-multilib                                  \
    --disable-bootstrap                                 \
    --disable-libgomp                                   \
    --enable-languages=c,c++
#    --disable-lto					\
# note: c++ is required to boot strap gcc >= 4.8

make $JOBS
#make $JOBS -k check

#echo "press the any key"
#read -n 1 -s anykey

make install

##symlink for any packages that use cc
ln -sv gcc $PREFIX/bin/cc


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

CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure                                             \
    --prefix=$PREFIX                                    \
    --without-bash-malloc

make $JOBS
make install

#symlink bash to sh!!
ln -sv bash $PREFIX/bin/sh
cd $TOPDIR

rm -rf $SRCDIR/$BASH
rm -rf $SRCDIR/$BASH-build


echo "###############################################################"
echo "BZIP2"
echo "###############################################################"
decompress $BZIP2 $SRCDIR

cd $SRCDIR/$BZIP2
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
make $JOBS
make PREFIX=$PREFIX install

cd $TOPDIR
rm -rf $SRCDIR/$BZIP2
rm -rf $SRCDIR/$BZIP2-build



echo "###############################################################"
echo "COREUTILS"
echo "###############################################################"
decompress $COREUTILS $SRCDIR

cd $SRCDIR/$COREUTILS

CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure                                             \
    --prefix=$PREFIX                                    \
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX

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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure             \
    --prefix=$PREFIX    \
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
CCP=$TARGET-ccp	                                        \
CC="$TARGET-gcc"                                        \
CXX="$TARGET-g++"                                       \
AR="$TARGET-ar"                                         \
AS="$TARGET-as"                                         \
RANLIB="$TARGET-ranlib"                                 \
./configure --prefix=$PREFIX
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
" > "$PREFIX/phase2.pod"
set +e
echo "removing cross compiler"
find . -iname "*$TARGET*" -exec rm -rfv {} \;
set -e

echo "strip debug info from binaries? (faster compression time)  y / n ]"
ack="y"
#read -n 1 -s ack
if [ "$ack" == "y" ] || [ "$ack" == "Y" ]; then
	cd $PREFIX
	find -type f -exec $PREFIX/bin/strip --strip-debug {} \;
	cd $PREFIX/bin
	find -type f -exec $PREFIX/bin/strip --strip-unneeded {} \;
	cd $PREFIX/sbin
	find -type f -exec $PREFIX/bin/strip --strip-unneeded {} \;

	cd $TOPDIR
fi


echo "strip extras (documentation, share data) y / n ]"
ack="y"
#read -n 1 -s ack
if [ "$ack" == "y" ] || [ "$ack" == "Y" ]; then
	cd $PREFIX
	rm -rfv $PREFIX/share/{info,man,doc}
	cd $TOPDIR
fi

cd $TOPDIR
echo "compressing toolchain (very slow if not stripped)"
$PREFIX/bin/tar -cJf toolchain.tar.xz toolchain

echo "-------------------------------------------------------"
echo "---------------- checksum generation ------------------"
echo "-------------------------------------------------------"
echo ""
echo "                          MD5"
$PREFIX/bin/md5sum toolchain.tar.xz
echo ""
echo "                          SHA1"
$PREFIX/bin/sha1sum toolchain.tar.xz
echo ""
echo "                         SHA256"
$PREFIX/bin/sha256sum toolchain.tar.xz
echo ""
echo "                         SHA384"
$PREFIX/bin/sha384sum toolchain.tar.xz
echo ""
echo "                         SHA512"
$PREFIX/bin/sha512sum toolchain.tar.xz
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

echo "set up home directory for pod root override"
echo "extract toolchain to home directory"
echo "run prepare_newroot.sh"
echo "copy toolchain/phase2.pod to home"
echo "and override dirs whould be rwx as well."
echo "run specially compiled jettison with PODROOT_HOME_OVERRIDE"

echo "export PATH=/bin:/usr/bin:/podhome/toolchain/bin"

